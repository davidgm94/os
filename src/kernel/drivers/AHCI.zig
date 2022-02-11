const kernel = @import("../kernel.zig");

const Bitflag = kernel.Bitflag;
const align_u64 = kernel.align_u64;
const TODO = kernel.TODO;
const zeroes = kernel.zeroes;
const ES_SUCCESS = kernel.ES_SUCCESS;
const Error = kernel.Error;
const Errors = kernel.Errors;
const Volatile = kernel.Volatile;
const Filesystem = kernel.Filesystem;
const Workgroup = kernel.Workgroup;
const round_up = kernel.round_up;
const Timeout = kernel.Timeout;
const EsMemoryZero = kernel.EsMemoryZero;

const arch = kernel.arch;
const page_size = arch.page_size;

const PCI = kernel.drivers.PCI;

const files = kernel.files;

const Region = kernel.memory.Region;

const Timer = kernel.scheduling.Timer;
const AsyncTask = kernel.scheduling.AsyncTask;

const Mutex = kernel.sync.Mutex;
const Spinlock = kernel.sync.Spinlock;
const Event = kernel.sync.Event;

const std = @import("std");
const assert = std.debug.assert;

export var recent_interrupt_events_pointer: Volatile(u64) = undefined;
export var recent_interrupt_events: [64]Volatile(InterruptEvent) = undefined;

fn GlobalRegister(comptime offset: u32) type
{
    return struct
    {
        fn write(d: *Driver, value: u32) void
        {
            d.pci.write_bar32(5, offset, value);
        }

        fn read(d: *Driver) u32
        {
            return d.pci.read_bar32(5, offset);
        }
    };
}

fn PortRegister(comptime offset: u32) type
{
    return struct
    {
        fn write(d: *Driver, port: u32, value: u32) void
        {
            d.pci.write_bar32(5, offset + port * 0x80, value);
        }

        fn read(d: *Driver, port: u32) u32
        {
            return d.pci.read_bar32(5, offset + port * 0x80);
        }
    };
}

const CAP = GlobalRegister(0);
const GHC = GlobalRegister(4);
const IS = GlobalRegister(8);
const PI = GlobalRegister(0xc);
const CAP2 = GlobalRegister(0x24);
const BOHC = GlobalRegister(0x28);

const PCLB = PortRegister(0x100);
const PCLBU = PortRegister(0x104);
const PFB = PortRegister(0x108);
const PFBU = PortRegister(0x10c);
const PIS = PortRegister(0x110);
const PIE = PortRegister(0x114);
const PCMD = PortRegister(0x118);
const PTFD = PortRegister(0x120);
const PSIG = PortRegister(0x124);
const PSSTS = PortRegister(0x128);
const PSCTL = PortRegister(0x12c);
const PSERR = PortRegister(0x130);
const PCI_register = PortRegister(0x138);

const general_timeout = 5000;
const command_list_size = 0x400;
const received_FIS_size = 0x100;
const PRDT_entry_count = 0x48;
const command_table_size = 0x80 + PRDT_entry_count * 0x10;

pub const Driver = struct
{
    pci: *PCI.Device,
    drives: []Drive,
    mbr_partitions: [4]MBR.Partition,
    mbr_partition_count: u64,
    partition_devices: []PartitionDevice,
    capabilities: u32,
    capabilities2: u32,
    command_slot_count: u64,
    timeout_timer: Timer,
    dma64_supported: bool,
    ports: [max_port_count]Port,

    const Port = extern struct
    {
        connected: bool,
        atapi: bool,
        ssd: bool,

        command_list: [*]u32,
        command_tables: [*]u8,
        sector_byte_count: u64,
        sector_count: u64,

        command_contexts: [32]?*Workgroup,
        command_start_timestamps: [32]u64,
        running_commands: u32,

        command_spinlock: Spinlock,
        command_slots_available_event: Event,

        model: [41]u8,
    };

    const max_port_count = 32;
    const class_code = 1;
    const subclass_code = 6;
    const prog_IF = 1;

    pub fn init() void
    {
        const drives_offset = round_up(u64, @sizeOf(Driver), @alignOf(Drive));
        const partition_devices_offset = round_up(u64, drives_offset + (@sizeOf(Drive) * Drive.max_count), @alignOf(PartitionDevice));
        const allocation_size = partition_devices_offset + (@sizeOf(PartitionDevice) * PartitionDevice.max_count);
        const address = kernel.address_space.allocate_standard(allocation_size, Region.Flags.from_flag(.fixed), arch.module_ptr, true);
        if (address == 0) kernel.panicf("Could not allocate memory for PCI driver", .{});
        arch.module_ptr += round_up(u64, allocation_size, page_size);
        driver = @intToPtr(*Driver, address);
        driver.drives.ptr = @intToPtr([*]Drive, address + drives_offset);
        driver.drives.len = 0;
        driver.partition_devices.ptr = @intToPtr([*]PartitionDevice, address + partition_devices_offset);
        driver.partition_devices.len = 0;
        driver.setup();

        // @TODO: delete in the future
        assert(driver.drives.len > 0);
        assert(driver.drives.len == 1);
        assert(driver.mbr_partition_count > 0);
        assert(driver.mbr_partition_count == 1);
    }

    pub fn setup(self: *@This()) void
    {
        self.pci = &PCI.driver.devices[3];

        const is_ahci_pci_device = self.pci.class_code == class_code and self.pci.subclass_code == subclass_code and self.pci.prog_IF == prog_IF;

        if (!is_ahci_pci_device) kernel.panicf("AHCI PCI device not found", .{});

        _ = self.pci.enable_features(PCI.Features.from_flags(.{ .interrupts, .busmastering_DMA, .memory_space_access, .bar_5 }));

        if (CAP2.read(self) & (1 << 0) != 0)
        {
            BOHC.write(self, BOHC.read(self) | (1 << 1));
            const timeout = Timeout.new(25);
            var status: u32 = undefined;

            while (true)
            {
                status = BOHC.read(self);
                if (status & (1 << 0) != 0) break;
                if (timeout.hit()) break;
            }

            if (status & (1 << 0) != 0)
            {
                var event = zeroes(Event);
                _ = event.wait_extended(2000);
            }
        }

        {
            const timeout = Timeout.new(general_timeout);
            GHC.write(self, GHC.read(self) | (1 << 0));
            while (GHC.read(self) & (1 << 0) != 0 and !timeout.hit())
            {
            }

            // error
            if (timeout.hit()) kernel.panicf("AHCI timeout hit", .{});
        }

        assert(@ptrToInt(handler) != 0);
        if (!self.pci.enable_single_interrupt(handler, @ptrToInt(self), "AHCI")) kernel.panicf("Unable to initialize AHCI", .{});

        GHC.write(self, GHC.read(self) | (1 << 31) | (1 << 1));
        self.capabilities = CAP.read(self);
        self.capabilities2 = CAP2.read(self);
        self.command_slot_count = ((self.capabilities >> 8) & 31) + 1;
        self.dma64_supported = self.capabilities & (1 << 31) != 0;
        if (!self.dma64_supported) kernel.panicf("DMA is not supported", .{});

        const maximum_number_of_ports = (self.capabilities & 31) + 1;
        var found_port_count: u64 = 0;
        const implemented_ports = PI.read(self);

        for (self.ports) |*port, i|
        {
            if (implemented_ports & (@as(u32, 1) << @intCast(u5, i)) != 0)
            {
                found_port_count += 1;
                if (found_port_count <= maximum_number_of_ports) port.connected = true;
            }
        }

        for (self.ports) |*port, _port_i|
        {
            if (port.connected)
            {
                const port_i = @intCast(u32, _port_i);
                const needed_byte_count = command_list_size + received_FIS_size + command_table_size * self.command_slot_count;

                var virtual_address: u64 = 0;
                var physical_address: u64 = 0;

                if (!kernel.memory.physical_allocate_and_map(needed_byte_count, page_size, if (self.dma64_supported) 64 else 32, true, Region.Flags.from_flag(.not_cacheable), &virtual_address, &physical_address))
                {
                    kernel.panicf("AHCI allocation failure", .{});
                }

                port.command_list = @intToPtr([*]u32, virtual_address);
                port.command_tables = @intToPtr([*]u8, virtual_address + command_list_size + received_FIS_size);

                PCLB.write(self, port_i, @truncate(u32, physical_address));
                PFB.write(self, port_i, @truncate(u32, physical_address + 0x400));
                if (self.dma64_supported)
                {
                    PCLBU.write(self, port_i, @truncate(u32, physical_address >> 32));
                    PFBU.write(self, port_i, @truncate(u32, (physical_address + 0x400) >> 32));
                }

                var command_slot: u64 = 0;
                while (command_slot < self.command_slot_count) : (command_slot += 1)
                {
                    const address = physical_address + command_list_size + received_FIS_size + command_table_size * command_slot;
                    port.command_list[command_slot * 8 + 2] = @truncate(u32, address);
                    port.command_list[command_slot * 8 + 3] = @truncate(u32, address >> 32);
                }

                const timeout = Timeout.new(general_timeout);
                const running_bits = (1 << 0) | (1 << 4) | (1 << 15) | (1 << 14);

                while (true)
                {
                    const status = PCMD.read(self, port_i);
                    if (status & running_bits == 0 or timeout.hit()) break;
                    PCMD.write(self, port_i, status & ~@as(u32, (1 << 0) | (1 << 4)));
                }

                const reset_port_timeout = PCMD.read(self, port_i) & running_bits != 0;
                if (reset_port_timeout)
                {
                    port.connected = false;
                    continue;
                }

                PIE.write(self, port_i, PIE.read(self, port_i) & 0x0e3fff0);
                PIS.write(self, port_i, PIS.read(self, port_i));

                PSCTL.write(self, port_i, PSCTL.read(self, port_i) | (3 << 8));
                PCMD.write(self, port_i,
                    (PCMD.read(self, port_i) & 0x0FFFFFFF) |
                    (1 << 1) |
                    (1 << 2) |
                    (1 << 4) |
                    (1 << 28));

                var link_timeout = Timeout.new(10);

                while (PSSTS.read(self, port_i) & 0xf != 3 and !link_timeout.hit()) { }
                const activate_port_timeout = PSSTS.read(self, port_i) & 0xf != 3;
                if (activate_port_timeout)
                {
                    port.connected = false;
                    continue;
                }

                PSERR.write(self, port_i, PSERR.read(self, port_i));

                while (PTFD.read(self, port_i) & 0x88 != 0 and !timeout.hit()) { }
                const port_ready_timeout = PTFD.read(self, port_i) & 0x88 != 0;
                if (port_ready_timeout)
                {
                    port.connected = false;
                    continue;
                }

                PCMD.write(self, port_i, PCMD.read(self, port_i) | (1 << 0));
                PIE.write(self, port_i,
                    PIE.read(self, port_i) |
                    (1 << 5) |
                    (1 << 0) |
                    (1 << 30) |
                    (1 << 29) |
                    (1 << 28) |
                    (1 << 27) |
                    (1 << 26) |
                    (1 << 24) |
                    (1 << 23));
            }
        }

        for (self.ports) |*port, _port_i|
        {
            if (port.connected)
            {
                const port_i = @intCast(u32, _port_i);

                const status = PSSTS.read(self, port_i);

                if (status & 0xf != 0x3 or status & 0xf0 == 0 or status & 0xf00 != 0x100)
                {
                    port.connected = false;
                    continue;
                }

                const signature = PSIG.read(self, port_i);

                if (signature == 0x00000101)
                {
                    // SATA drive
                }
                else if (signature == 0xEB140101)
                {
                    // SATAPI drive
                    port.atapi = true;
                }
                else if (signature == 0)
                {
                    // no drive connected
                    port.connected = false;
                }
                else
                {
                    // unrecognized drive signature
                    port.connected = false;
                }
            }
        }

        var identify_data: u64 = 0;
        var identify_data_physical: u64 = 0;
        if (!kernel.memory.physical_allocate_and_map(0x200, page_size, if (self.dma64_supported) 64 else 32, true, Region.Flags.from_flag(.not_cacheable), &identify_data, &identify_data_physical))
        {
            kernel.panicf("Allocation failure", .{});
        }

        for (self.ports) |*port, _port_i|
        {
            if (port.connected)
            {
                const port_i = @intCast(u32, _port_i);
                EsMemoryZero(identify_data, 0x200);

                port.command_list[0] = 5 | (1 << 16);
                port.command_list[1] = 0;

                const opcode: u32 = if (port.atapi) 0xa1 else 0xec;
                const command_FIS = @ptrCast([*]u32, @alignCast(4, port.command_tables));
                command_FIS[0] = 0x27 | (1 << 15) | (opcode << 16);
                command_FIS[1] = 0;
                command_FIS[2] = 0;
                command_FIS[3] = 0;
                command_FIS[4] = 0;

                const prdt = @intToPtr([*]u32, @ptrToInt(port.command_tables) + 0x80);
                prdt[0] = @truncate(u32, identify_data_physical);
                prdt[1] = @truncate(u32, identify_data_physical >> 32);
                prdt[2] = 0;
                prdt[3] = 0x200 - 1;

                if (!self.send_single_command(port_i))
                {
                    PCMD.write(self, port_i, PCMD.read(self, port_i) & ~@as(u32, 1 << 0));
                    port.connected = false;
                    continue;
                }

                port.sector_byte_count = 0x200;

                const identify_ptr = @intToPtr([*]u16, identify_data);
                if (identify_ptr[106] & (1 << 14) != 0 and ~identify_ptr[106] & (1 << 15) != 0 and identify_ptr[106] & (1 << 12) != 0)
                {
                    port.sector_byte_count = identify_ptr[117] | (@intCast(u32, identify_ptr[118]) << 16);
                }

                port.sector_count = identify_ptr[100] + (@intCast(u64, identify_ptr[101]) << 16) + (@intCast(u64, identify_ptr[102]) << 32) + (@intCast(u64, identify_ptr[103]) << 48);

                if (!(identify_ptr[49] & (1 << 9) != 0 and identify_ptr[49] & (1 << 8) != 0))
                {
                    port.connected = false;
                    continue;
                }

                if (port.atapi)
                {
                    port.command_list[0] = 5 | (1 << 16) | (1 << 5);
                    command_FIS[0] = 0x27 | (1 << 15) | (0xa0 << 16);
                    command_FIS[1] = 8 << 8;
                    prdt[3] = 8 - 1;

                    const scsi_command = @ptrCast([*]u8, command_FIS);
                    EsMemoryZero(@ptrToInt(scsi_command), 10);
                    scsi_command[0] = 0x25;

                    if (!self.send_single_command(port_i))
                    {
                        PCMD.write(self, port_i, PCMD.read(self, port_i) & ~@as(u32, 1 << 0));
                        port.connected = false;
                        continue;
                    }

                    const capacity = @intToPtr([*]u8, identify_data);
                    port.sector_count = capacity[3] + (@intCast(u64, capacity[2]) << 8) + (@intCast(u64, capacity[1]) << 16) + (@intCast(u64, capacity[0]) << 24) + 1;
                    port.sector_byte_count = capacity[7] + (@intCast(u64, capacity[6]) << 8) + (@intCast(u64, capacity[5]) << 16) + (@intCast(u64, capacity[4]) << 24);
                }

                if (port.sector_count <= 128 or port.sector_byte_count & 0x1ff != 0 or port.sector_byte_count == 0 or port.sector_byte_count > 0x1000)
                {
                    port.connected = false;
                    continue;
                }

                var model: u64 = 0;
                while (model < 20) : (model += 1)
                {
                    port.model[model * 2 + 0] = @truncate(u8, identify_ptr[27 + model] >> 8);
                    port.model[model * 2 + 1] = @truncate(u8, identify_ptr[27 + model]);
                }

                port.model[40] = 0;

                model = 39;

                while (model > 0) : (model -= 1)
                {
                    if (port.model[model] == ' ') port.model[model] = 0
                    else break;
                }

                port.ssd = identify_ptr[217] == 1;

                var i: u64 = 10;
                while (i < 20) : (i += 1)
                {
                    identify_ptr[i] = (identify_ptr[i] >> 8) | (identify_ptr[i] << 8);
                }

                i = 23;
                while (i < 27) : (i += 1)
                {
                    identify_ptr[i] = (identify_ptr[i] >> 8) | (identify_ptr[i] << 8);
                }

                i = 27;
                while (i < 47) : (i += 1)
                {
                    identify_ptr[i] = (identify_ptr[i] >> 8) | (identify_ptr[i] << 8);
                }
            }
        }


        _ = kernel.address_space.free(identify_data, 0, false);
        kernel.memory.physical_free(identify_data_physical, false, 1);

        self.timeout_timer.set_extended(general_timeout, TimeoutTimerHit, @ptrToInt(self));

        for (self.ports) |*port, _port_i|
        {
            if (port.connected)
            {
                const port_i = @intCast(u32, _port_i);
                const drive_index = self.drives.len;
                self.drives.len += 1;
                const drive = &self.drives[drive_index];
                drive.port = port_i;
                drive.block_device.sector_size = port.sector_byte_count;
                drive.block_device.sector_count = port.sector_count;
                drive.block_device.max_access_sector_count = if (port.atapi) (65535 / drive.block_device.sector_size) else (PRDT_entry_count - 1) * page_size / drive.block_device.sector_size;
                drive.block_device.read_only = port.atapi;
                comptime assert(port.model.len <= drive.block_device.model.len);
                std.mem.copy(u8, drive.block_device.model[0..port.model.len], port.model[0..]);
                drive.block_device.model_bytes = port.model.len;
                drive.block_device.drive_type = if (port.atapi) DriveType.cdrom else if (port.ssd) DriveType.ssd else DriveType.hdd;

                drive.block_device.access = @ptrToInt(access_callback);
                drive.block_device.register_filesystem();
            }
        }
    }

    pub fn access_callback(request: BlockDevice.AccessRequest) Error
    {
        const drive = @ptrCast(*Drive, request.device);
        request.dispatch_group.?.start();

        if (!driver.access(drive.port, request.offset, request.count, request.operation, request.buffer, request.flags, request.dispatch_group))
        {
            request.dispatch_group.?.end(false);
        }

        return ES_SUCCESS;
    }

    pub fn handle_IRQ(self: *@This()) bool
    {
        const global_interrupt_status = IS.read(self);
        if (global_interrupt_status == 0) return false;
        IS.write(self, global_interrupt_status);

        const event = &recent_interrupt_events[recent_interrupt_events_pointer.read_volatile()];
        event.access_volatile().timestamp = kernel.scheduler.time_ms;
        event.access_volatile().global_interrupt_status = global_interrupt_status;
        event.access_volatile().complete = false;
        recent_interrupt_events_pointer.write_volatile((recent_interrupt_events_pointer.read_volatile() + 1) % recent_interrupt_events.len);

        var command_completed = false;

        for (self.ports) |*port, _port_i|
        {
            const port_i = @intCast(u32, _port_i);
            if (~global_interrupt_status & (@as(u32, 1) << @intCast(u5, port_i)) != 0) continue;

            const interrupt_status = PIS.read(self, port_i);
            if (interrupt_status == 0) continue;

            PIS.write(self, port_i, interrupt_status);

            if (interrupt_status & ((1 << 30 | (1 << 29) | (1 << 28) | (1 << 27) | (1 << 26) | (1 << 24) | (1 << 23))) != 0)
            {
                TODO(@src());
            }
            port.command_spinlock.acquire();
            const commands_issued = PCI_register.read(self, port_i);

            if (port_i == 0)
            {
                event.access_volatile().port_0_commands_issued = commands_issued;
                event.access_volatile().port_0_commands_running = port.running_commands;
            }

            var i: u32 = 0;
            while (i < self.ports.len) : (i += 1)
            {
                const shifter = (@as(u32, 1) << @intCast(u5, i));
                if (~port.running_commands & shifter != 0) continue;
                if (commands_issued & shifter != 0) continue;

                port.command_contexts[i].?.end(true);
                port.command_contexts[i] = null;
                _ = port.command_slots_available_event.set(true);
                port.running_commands &= ~shifter;

                command_completed = true;
            }

            port.command_spinlock.release();
        }

        if (command_completed)
        {
            arch.get_local_storage().?.IRQ_switch_thread = true;
        }

        event.access_volatile().complete = true;
        return true;
    }

    pub fn send_single_command(self: *@This(), port: u32) bool
    {
        const timeout = Timeout.new(general_timeout);

        while (PTFD.read(self, port) & ((1 << 7) | (1 << 3)) != 0 and !timeout.hit()) { }
        if (timeout.hit()) return false;
        @fence(.SeqCst);
        PCI_register.write(self, port, 1 << 0);
        var complete = false;

        while (!timeout.hit())
        {
            complete = ~PCI_register.read(self, port) & (1 << 0) != 0;
            if (complete)
            {
                break;
            }
        }

        return complete;
    }

    pub fn access(self: *@This(), _port_index: u64, offset: u64, byte_count: u64, operation: i32, buffer: *DMABuffer, flags: BlockDevice.AccessRequest.Flags, dispatch_group: ?*Workgroup) bool
    {
        _ = flags;
        const port_index = @intCast(u32, _port_index);
        const port = &self.ports[port_index];

        var command_index: u64 = 0;

        while (true)
        {
            port.command_spinlock.acquire();

            const commands_available = ~PCI_register.read(self, port_index);

            var found = false;
            var slot: u64 = 0;
            while (slot < self.command_slot_count) : (slot += 1)
            {
                if (commands_available & (@as(u32, 1) << @intCast(u5, slot)) != 0 and port.command_contexts[slot] == null)
                {
                    command_index = slot;
                    found = true;
                    break;
                }
            }

            if (!found)
            {
                port.command_slots_available_event.reset();
            }
            else
            {
                port.command_contexts[command_index] = dispatch_group;
            }

            port.command_spinlock.release();

            if (!found)
            {
                _ = port.command_slots_available_event.wait();
            }
            else
            {
                break;
            }
        }

        const sector_count = byte_count / port.sector_byte_count;
        const offset_sectors = offset / port.sector_byte_count;

        const command_FIS = @intToPtr([*]u32, @ptrToInt(port.command_tables) + command_table_size * command_index);
        command_FIS[0] = 0x27 | (1 << 15) | (@as(u32, if (operation == BlockDevice.write) 0x35 else 0x25) << 16);
        command_FIS[1] = (@intCast(u32, offset_sectors) & 0xffffff) | (1 << 30);
        command_FIS[2] = @intCast(u32, offset_sectors >> 24) & 0xffffff;
        command_FIS[3] = @truncate(u16, sector_count);
        command_FIS[4] = 0;

        var m_PRDT_entry_count: u64 = 0;
        const prdt = @intToPtr([*]u32, @ptrToInt(port.command_tables) + command_table_size * command_index + 0x80);

        while (!buffer.is_complete())
        {
            if (m_PRDT_entry_count == PRDT_entry_count) kernel.panicf("Too many PRDT entries", .{});

            const segment = buffer.next_segment(false);

            prdt[0 + 4 * m_PRDT_entry_count] = @truncate(u32, segment.physical_address);
            prdt[1 + 4 * m_PRDT_entry_count] = @truncate(u32, segment.physical_address >> 32);
            prdt[2 + 4 * m_PRDT_entry_count] = 0;
            prdt[3 + 4 * m_PRDT_entry_count] = (@intCast(u32, segment.byte_count) - 1) | @as(u32, if (segment.is_last) (1 << 31) else 0);
            m_PRDT_entry_count += 1;
        }

        port.command_list[command_index * 8 + 0] = 5 | (@intCast(u32, m_PRDT_entry_count) << 16) | @as(u32, if (operation == BlockDevice.write) (1 << 6) else 0);
        port.command_list[command_index * 8 + 1] = 0;

        if (port.atapi)
        {
            port.command_list[command_index * 8 + 0] |= (1 << 5);
            command_FIS[0] = 0x27 | (1 << 15) | (0xa0 << 16);
            command_FIS[1] = @intCast(u32, byte_count) << 8;

            const scsi_command = @intToPtr([*]u8, @ptrToInt(command_FIS) + 0x40);
            std.mem.set(u8, scsi_command[0..10], 0);
            scsi_command[0] = 0xa8;
            scsi_command[2] = @truncate(u8, offset_sectors >> 0x18);
            scsi_command[3] = @truncate(u8, offset_sectors >> 0x10);
            scsi_command[4] = @truncate(u8, offset_sectors >> 0x08);
            scsi_command[5] = @truncate(u8, offset_sectors >> 0x00);
            scsi_command[9] = @intCast(u8, sector_count);
        }

        port.command_spinlock.acquire();
        port.running_commands |= @intCast(u32, 1) << @intCast(u5, command_index);
        @fence(.SeqCst);
        PCI_register.write(self, port_index, @intCast(u32, 1) << @intCast(u5, command_index));
        port.command_start_timestamps[command_index] = kernel.scheduler.time_ms;
        port.command_spinlock.release();

        return true;
    }

    pub fn get_drive(self: *@This()) *Drive
    {
        return &self.drives[0];
    }
};

pub const Drive = extern struct
{
    block_device: BlockDevice,
    port: u64,

    const max_count = 64;

    pub fn read_file(self: *@This(), file_buffer: []u8, file_descriptor: *const Filesystem.File.Descriptor) files.ReadError!void
    {
        if (file_descriptor.offset & (self.block_device.sector_size - 1) != 0) kernel.panicf("Disk offset should be sector-aligned", .{});
        const sector_aligned_size = align_u64(file_descriptor.size, self.block_device.sector_size);
        if (file_buffer.len < sector_aligned_size) kernel.panicf("Buffer too small\n", .{});

        var buffer = zeroes(DMABuffer);
        buffer.virtual_address = @ptrToInt(file_buffer.ptr);

        var request = zeroes(BlockDevice.AccessRequest);
        request.offset = file_descriptor.offset;
        request.count = sector_aligned_size;
        request.operation = BlockDevice.read;
        request.device = &self.block_device;
        request.buffer = &buffer;

        const result = FSBlockDeviceAccess(request);
        if (result != ES_SUCCESS) return files.ReadError.failed;
    }
};

pub var driver: *Driver = undefined;

fn handler(_: u64, context: u64) callconv(.C) bool
{
    return @intToPtr(*Driver, context).handle_IRQ();
}

const DriveType = enum(u8)
{
    other = 0,
    hdd = 1,
    ssd = 2,
    cdrom = 3,
    usb_mass_storage = 4,
};

const BlockDevice = extern struct
{
    access: u64,
    sector_size: u64,
    sector_count: u64,
    read_only: bool,
    nest_level: u8,
    drive_type: DriveType,
    model_bytes: u8,
    model: [64]u8,
    max_access_sector_count: u64,
    signature_block: [*]u8,
    detect_filesystem_mutex: Mutex,

    const AccessRequest = extern struct
    {
        device: *BlockDevice,
        offset: u64,
        count: u64,
        operation: i32,
        buffer: *DMABuffer,
        flags: Flags,
        dispatch_group: ?*Workgroup,

        const Flags = Bitflag(enum(u64)
            {
                cache = 0,
                soft_errors = 1,
            });
        const Callback = fn(self: @This()) i64;
    };

    fn register_filesystem(self: *@This()) void
    {
        self.detect_filesystem();
        // @TODO: notify desktop
    }

    fn detect_filesystem(self: *@This()) void
    {
        _ = self.detect_filesystem_mutex.acquire();
        defer self.detect_filesystem_mutex.release();

        if (self.nest_level > 4) kernel.panicf("Filesystem nest limit", .{});

        const sectors_to_read = (signature_block_size + self.sector_size - 1) / self.sector_size;
        if (sectors_to_read > self.sector_count) kernel.panicf("Drive too small", .{});

        const bytes_to_read = sectors_to_read * self.sector_size;
        self.signature_block = @intToPtr(?[*]u8, kernel.heapFixed.allocate(bytes_to_read, false)) orelse kernel.panicf("unable to allocate memory for fs detection", .{});
        var dma_buffer = zeroes(DMABuffer);
        dma_buffer.virtual_address = @ptrToInt(self.signature_block);
        var request = zeroes(BlockDevice.AccessRequest);
        request.device = self;
        request.count = bytes_to_read;
        request.operation = read;
        request.buffer = &dma_buffer;

        if (FSBlockDeviceAccess(request) != ES_SUCCESS)
        {
            kernel.panicf("Could not read disk", .{});
        }
        assert(self.nest_level == 0);

        if (!self.check_mbr()) kernel.panicf("Only MBR is supported\n", .{});

        kernel.heapFixed.free(@ptrToInt(self.signature_block), bytes_to_read);
    }

    fn check_mbr(self: *@This()) bool
    {
        if (MBR.get_partitions(self.signature_block, self.sector_count))
        {
            for (driver.mbr_partitions) |partition|
            {
                if (partition.present)
                {
                    // @TODO: this should be a recursive call to fs_register
                    const index = driver.partition_devices.len;
                    driver.partition_devices.len += 1;
                    const partition_device = &driver.partition_devices[index];
                    partition_device.register(self, partition.offset, partition.count, 0, "MBR partition");
                    return true;
                }
            }
        }

        return false;
    }

    const read = 0;
    const write = 1;
};

const MBR = extern struct
{
    const Partition = extern struct
    {
        offset: u32,
        count: u32,
        present: bool,
    };
    fn get_partitions(first_block: [*]u8, sector_count: u64) bool
    {
        const is_boot_magic_ok = first_block[510] == 0x55 and first_block[511] == 0xaa;
        if (!is_boot_magic_ok) return false;

        for (driver.mbr_partitions) |*mbr_partition, i|
        {
            if (first_block[4 + 0x1be + i * 0x10] == 0)
            {
                mbr_partition.present = false;
                continue;
            }

            mbr_partition.offset =
                (@intCast(u32, first_block[0x1be + i * 0x10 + 8]) << 0) +
                (@intCast(u32, first_block[0x1be + i * 0x10 + 9]) << 8) +
                (@intCast(u32, first_block[0x1be + i * 0x10 + 10]) << 16) +
                (@intCast(u32, first_block[0x1be + i * 0x10 + 11]) << 24);
            mbr_partition.count =
                (@intCast(u32, first_block[0x1be + i * 0x10 + 12]) << 0) +
                (@intCast(u32, first_block[0x1be + i * 0x10 + 13]) << 8) +
                (@intCast(u32, first_block[0x1be + i * 0x10 + 14]) << 16) +
                (@intCast(u32, first_block[0x1be + i * 0x10 + 15]) << 24);
            mbr_partition.present = true;

            if (mbr_partition.offset > sector_count or mbr_partition.count > sector_count - mbr_partition.offset or mbr_partition.count < 32)
            {
                return false;
            }
            driver.mbr_partition_count += 1;
        }

        return true;
    }
};

const PartitionDevice = extern struct
{
    block: BlockDevice,
    sector_offset: u64,
    parent: *BlockDevice,

    const max_count = 16;

    fn access(_request: BlockDevice.AccessRequest) Error
    {
        var request = _request;
        const device = @ptrCast(*PartitionDevice, request.device);
        request.device = @ptrCast(*BlockDevice, device.parent);
        request.offset += device.sector_offset * device.block.sector_size;
        return FSBlockDeviceAccess(request);
    }

    fn register(self: *@This(), parent: *BlockDevice, offset: u64, sector_count: u64, flags: u32, model: []const u8) void
    {
        _ = flags; // @TODO: refactor
        std.mem.copy(u8, self.block.model[0..model.len], model);

        self.parent = parent;
        self.block.sector_size = parent.sector_size;
        self.block.max_access_sector_count = parent.max_access_sector_count;
        self.sector_offset = offset;
        self.block.sector_count = sector_count;
        self.block.read_only = parent.read_only;
        self.block.access = @ptrToInt(access);
        self.block.model_bytes = @intCast(u8, model.len);
        self.block.nest_level = parent.nest_level + 1;
        self.block.drive_type = parent.drive_type;
    }
};


fn FSBlockDeviceAccess(_request: BlockDevice.AccessRequest) Error
{
    var request = _request;
    const device = request.device;

    if (request.count == 0) return ES_SUCCESS;

    if (device.read_only and request.operation == BlockDevice.write)
    {
        if (request.flags.contains(.soft_errors)) return Errors.ES_ERROR_BLOCK_ACCESS_INVALID;
        kernel.panicf("The device is read-only and the access requests for write permission", .{});
    }

    if (request.offset / device.sector_size > device.sector_count or (request.offset + request.count) / device.sector_size > device.sector_count)
    {
        if (request.flags.contains(.soft_errors)) return Errors.ES_ERROR_BLOCK_ACCESS_INVALID;
        kernel.panicf("Disk access out of bounds", .{});
    }

    if (request.offset % device.sector_size != 0 or request.count % device.sector_size != 0)
    {
        if (request.flags.contains(.soft_errors)) return Errors.ES_ERROR_BLOCK_ACCESS_INVALID;
        kernel.panicf("Unaligned access\n", .{});
    }

    var buffer = request.buffer.*;

    if (buffer.virtual_address & 3 != 0)
    {
        if (request.flags.contains(.soft_errors)) return Errors.ES_ERROR_BLOCK_ACCESS_INVALID;
        kernel.panicf("Buffer must be 4-byte aligned", .{});
    }

    var fake_dispatch_group = zeroes(Workgroup);
    if (request.dispatch_group == null)
    {
        fake_dispatch_group.init();
        request.dispatch_group = &fake_dispatch_group;
    }

    var r = zeroes(BlockDevice.AccessRequest);
    r.device = request.device;
    r.buffer = &buffer;
    r.flags = request.flags;
    r.dispatch_group = request.dispatch_group;
    r.operation = request.operation;
    r.offset = request.offset;

    while (request.count != 0)
    {
        r.count = device.max_access_sector_count * device.sector_size;
        if (r.count > request.count) r.count = request.count;

        buffer.offset = 0;
        buffer.total_byte_count = r.count;
        //r.count = r.count;
        const callback = @intToPtr(BlockDevice.AccessRequest.Callback, device.access);
        _ =callback(r);
        //_ = device.access(r);
        r.offset += r.count;
        buffer.virtual_address += r.count;
        request.count -= r.count;
    }

    if (request.dispatch_group == &fake_dispatch_group)
    {
        return if (fake_dispatch_group.wait()) ES_SUCCESS else Errors.ES_ERROR_DRIVE_CONTROLLER_REPORTED;
    }
    else
    {
        return ES_SUCCESS;
    }
}

const signature_block_size = 65536;

const DMASegment = extern struct
{
    physical_address: u64,
    byte_count: u64,
    is_last: bool,
};

const DMABuffer = extern struct
{
    virtual_address: u64,
    total_byte_count: u64,
    offset: u64,

    fn is_complete(self: *@This()) bool
    {
        return self.offset == self.total_byte_count;
    }

    fn next_segment(self: *@This(), peek: bool) DMASegment
    {
        if (self.offset >= self.total_byte_count or self.virtual_address == 0) kernel.panicf("Invalid state of DMA buffer", .{});

        var transfer_byte_count: u64 = page_size;
        const virtual_address = self.virtual_address + self.offset;
        var physical_address = arch.translate_address(virtual_address, false);
        const offset_into_page = virtual_address & (page_size - 1);

        if (offset_into_page > 0)
        {
            transfer_byte_count = page_size - offset_into_page;
            physical_address += offset_into_page;
        }

        const total_minus_offset = self.total_byte_count - self.offset;
        if (transfer_byte_count > total_minus_offset)
        {
            transfer_byte_count = total_minus_offset;
        }

        const is_last = self.offset + transfer_byte_count == self.total_byte_count;
        if (!peek) self.offset += transfer_byte_count;

        return DMASegment
        {
            .physical_address = physical_address,
            .byte_count = transfer_byte_count,
            .is_last = is_last,
        };
    }
};

const InterruptEvent = extern struct
{
    timestamp: u64,
    global_interrupt_status: u32,
    port_0_commands_running: u32,
    port_0_commands_issued: u32,
    complete: bool,
};

fn TimeoutTimerHit(task: *AsyncTask) void
{
    const _driver = @fieldParentPtr(Driver, "timeout_timer", @fieldParentPtr(Timer, "async_task", task));
    const current_timestamp = kernel.scheduler.time_ms;

    for (_driver.ports) |*port|
    {
        port.command_spinlock.acquire();

        var slot: u64 = 0;
        while (slot < _driver.command_slot_count) : (slot += 1)
        {
            const slot_mask = @intCast(u32, 1) << @intCast(u5, slot);
            if (port.running_commands & slot_mask != 0 and port.command_start_timestamps[slot] + general_timeout < current_timestamp)
            {
                port.command_contexts[slot].?.end(false);
                port.command_contexts[slot] = null;
                port.running_commands &= ~slot_mask;
            }
        }

        port.command_spinlock.release();
    }

    _driver.timeout_timer.set_extended(general_timeout, TimeoutTimerHit, @ptrToInt(_driver));
}
