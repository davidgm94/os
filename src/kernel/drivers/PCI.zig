const kernel = @import("../kernel.zig");

const round_up = kernel.round_up;
const TODO = kernel.TODO;
const Bitflag = kernel.Bitflag;

const arch = kernel.arch;
const page_size = arch.page_size;
const MSI = arch.MSI;

const Region = kernel.memory.Region;

const std = @import("std");
const assert = std.debug.assert;

pub const Driver = struct
{
    devices: []Device,
    bus_scan_states: [256]u8,

    pub fn init() void
    {
        const devices_offset = round_up(u64, @sizeOf(Driver), @alignOf(Device));
        const allocation_size = devices_offset + (@sizeOf(Device) * Device.max_count);
        const address = kernel.address_space.allocate_standard(allocation_size, Region.Flags.from_flag(.fixed), arch.module_ptr, true);
        if (address == 0) kernel.panic("Could not allocate memory for PCI driver");
        arch.module_ptr += round_up(u64, allocation_size, page_size);

        driver = @intToPtr(*Driver, address);
        driver.devices.ptr = @intToPtr([*]Device, address + devices_offset);
        driver.devices.len = 0;
        driver.setup();
    }

    fn setup(self: *@This()) void
    {
        const base_header_type = arch.pci_read_config32(0, 0, 0, 0x0c);
        const base_bus_count: u8 = if (base_header_type & 0x80 != 0) 8 else 1;
        var bus_to_scan_count: u8 = 0;

        var base_bus: u8 = 0;
        while (base_bus < base_bus_count) : (base_bus += 1)
        {
            const device_id = arch.pci_read_config32(0, 0, base_bus, 0);
            if (device_id & 0xffff != 0xffff)
            {
                self.bus_scan_states[base_bus] = @enumToInt(Bus.scan_next);
                bus_to_scan_count += 1;
            }
        }

        if (bus_to_scan_count == 0) kernel.panic("No bus found");

        var found_usb = false;

        while (bus_to_scan_count > 0)
        {
            for (self.bus_scan_states) |*bus_scan_state, _bus|
            {
                const bus = @intCast(u8, _bus);
                if (bus_scan_state.* == @enumToInt(Bus.scan_next))
                {
                    bus_scan_state.* = @enumToInt(Bus.scanned);
                    bus_to_scan_count -= 1;

                    var device: u8 = 0;
                    while (device < 32) : (device += 1)
                    {
                        const _device_id = arch.pci_read_config32(bus, device, 0, 0);
                        if (_device_id & 0xffff != 0xffff)
                        {
                            const header_type = @truncate(u8, arch.pci_read_config32(bus, device, 0, 0x0c) >> 16);
                            const function_count: u8 = if (header_type & 0x80 != 0) 8 else 1;

                            var function: u8 = 0;
                            while (function < function_count) : (function += 1)
                            {
                                const device_id = arch.pci_read_config32(bus, device, function, 0);
                                if (device_id & 0xffff != 0xffff)
                                {
                                    const device_class = arch.pci_read_config32(bus, device, function, 0x08);
                                    const interrupt_information = arch.pci_read_config32(bus, device, function, 0x3c);
                                    const index = self.devices.len;
                                    self.devices.len += 1;

                                    const pci_device = &self.devices[index];
                                    pci_device.class_code = @truncate(u8, device_class >> 24);
                                    pci_device.subclass_code = @truncate(u8, device_class >> 16);
                                    pci_device.prog_IF = @truncate(u8, device_class >> 8);
                                    pci_device.bus = bus;
                                    pci_device.slot = device;
                                    pci_device.function = function;
                                    pci_device.interrupt_pin = @truncate(u8, interrupt_information >> 8);
                                    pci_device.interrupt_line = @truncate(u8, interrupt_information >> 0);
                                    pci_device.device_ID = arch.pci_read_config32(bus, device, function, 0);
                                    pci_device.subsystem_ID = arch.pci_read_config32(bus, device, function, 0x2c);

                                    for (pci_device.base_addresses) |*base_address, i|
                                    {
                                        base_address.* = pci_device.read_config_32(@intCast(u8, 0x10 + 4 * i));
                                    }

                                    const is_pci_bridge = pci_device.class_code == 0x06 and pci_device.subclass_code == 0x04;
                                    if (is_pci_bridge)
                                    {
                                        const secondary_bus = @truncate(u8, arch.pci_read_config32(bus, device, function, 0x18) >> 8);
                                        if (self.bus_scan_states[secondary_bus] == @enumToInt(Bus.do_not_scan))
                                        {
                                            bus_to_scan_count += 1;
                                            self.bus_scan_states[secondary_bus] = @enumToInt(Bus.scan_next);
                                        }
                                    }

                                    const is_usb = pci_device.class_code == 12 and pci_device.subclass_code == 3;
                                    if (is_usb) found_usb = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
};

pub const Device = extern struct
{
    device_ID: u32,
    subsystem_ID: u32,
    domain: u32,
    class_code: u8,
    subclass_code: u8,
    prog_IF: u8,
    bus: u8,
    slot: u8,
    function: u8,
    interrupt_pin: u8,
    interrupt_line: u8,
    base_addresses_virtual: [6]u64,
    base_addresses_physical: [6]u64,
    base_addresses_sizes: [6]u64,

    base_addresses: [6]u32,

    const max_count = 64;

    pub fn read_config_8(self: @This(), offset: u8) u8
    {
        return @truncate(u8, arch.pci_read_config(self.bus, self.slot, self.function, offset, 8));
    }

    pub fn read_config_16(self: @This(), offset: u8) u16
    {
        return @truncate(u16, arch.pci_read_config(self.bus, self.slot, self.function, offset, 16));
    }

    pub fn write_config_16(self: @This(), offset: u8, value: u16) void
    {
        arch.pci_write_config(self.bus, self.slot, self.function, offset, value, 16);
    }

    pub fn read_config_32(self: @This(), offset: u8) u32
    {
        return arch.pci_read_config(self.bus, self.slot, self.function, offset, 32);
    }

    pub fn write_config_32(self: @This(), offset: u8, value: u32) void
    {
        arch.pci_write_config(self.bus, self.slot, self.function, offset, value, 32);
    }

    pub fn enable_features(self: *@This(), features: Features) bool
    {
        var config = self.read_config_32(4);
        if (features.contains(.interrupts)) config &= ~(@as(u32, 1) << 10);
        if (features.contains(.busmastering_DMA)) config |= 1 << 2;
        if (features.contains(.memory_space_access)) config |= 1 << 1;
        if (features.contains(.io_port_access)) config |= 1 << 0;
        self.write_config_32(4, config);

        assert(self.read_config_32(4) == config);
        if (self.read_config_32(4) != config) return false;

        var i: u8 = 0;
        while (i < 6) : (i += 1)
        {
            if (~features.bits & (@as(u32, 1) << @intCast(u5, i)) != 0) continue;
            const bar_is_io_port = self.base_addresses[i] & 1 != 0;
            if (bar_is_io_port) continue;
            const size_is_64 = self.base_addresses[i] & 4 != 0;
            if (self.base_addresses[i] & 8 == 0) 
            {
                // TODO
            }

            var address: u64 = undefined;
            var size: u64 = undefined;

            if (size_is_64)
            {
                self.write_config_32(0x10 + 4 * i, 0xffffffff);
                self.write_config_32(0x10 + 4 * (i + 1), 0xffffffff);
                size = self.read_config_32(0x10 + 4 * i);
                size |= @intCast(u64, self.read_config_32(0x10 + 4 * (i + 1))) << 32;
                self.write_config_32(0x10 + 4 * i, self.base_addresses[i]);
                self.write_config_32(0x10 + 4 * (i + 1), self.base_addresses[i + 1]);
                address = self.base_addresses[i];
                address |= @intCast(u64, self.base_addresses[i + 1]) << 32;
            }
            else
            {
                self.write_config_32(0x10 + 4 * i, 0xffffffff);
                size = self.read_config_32(0x10 + 4 * i);
                size |= @intCast(u64, 0xffffffff) << 32;
                self.write_config_32(0x10 + 4 * i, self.base_addresses[i]);
                address = self.base_addresses[i];
            }

            if (size == 0) return false;
            if (address == 0) return false;

            size &= ~@as(@TypeOf(size), 0xf);
            size = ~size + 1;
            address &= ~@as(@TypeOf(address), 0xf);

            self.base_addresses_virtual[i] = kernel.address_space.map_physical(address, size, Region.Flags.from_flag(.not_cacheable));
            assert(address != 0);
            assert(self.base_addresses_virtual[i] != 0);
            self.base_addresses_physical[i] = address;
            self.base_addresses_sizes[i] = size;
            kernel.memory.check_unusable(address, size);
        }

        return true;
    }

    pub fn read_bar_8(self: @This(), index: u32, offset: u32) u8
    {
        const base_address = self.base_addresses[index];
        if (base_address & 1 != 0) return arch.in8(@intCast(u16, (base_address & ~@as(u32, 3)) + offset))
        else return @intToPtr(*volatile u8, self.base_addresses_virtual[index] + offset).*;
    }

    pub fn read_bar32(self: @This(), index: u32, offset: u32) u32
    {
        const base_address = self.base_addresses[index];
        return
            if (base_address & 1 != 0)
                arch.in32(@intCast(u16, (base_address & ~@as(u32, 3)) + offset))
            else
                @intToPtr(*volatile u32, self.base_addresses_virtual[index] + offset).*;
    }

    pub fn write_bar32(self: @This(), index: u32, offset: u32, value: u32) void
    {
        const base_address = self.base_addresses[index];
        if (base_address & 1 != 0)
        {
            arch.out32(@intCast(u16, (base_address & ~@as(u32, 3)) + offset), value);
        }
        else
        {
            @intToPtr(*volatile u32, self.base_addresses_virtual[index] + offset).* = value;
        }
    }

    pub fn enable_single_interrupt(self: *@This(), handler: arch.KIRQHandler, context: u64, owner_name: []const u8) bool
    {
        assert(@ptrToInt(handler) != 0);

        if (self.enable_MSI(handler, context, owner_name)) return true;
        if (self.interrupt_pin == 0) return false;
        if (self.interrupt_pin > 4) return false;

        const result = self.enable_features(Features.from_flag(.interrupts));
        assert(result);

        var line = @intCast(i64, self.interrupt_line);
        if (arch.bootloader_ID == 2) line = -1;

        TODO(@src());
    }

    pub fn enable_MSI(self: *@This(), handler: arch.KIRQHandler, context: u64, owner_name: []const u8) bool
    {
        assert(@ptrToInt(handler) != 0);

        const status = @truncate(u16, self.read_config_32(0x04) >> 16);
        if (~status & (1 << 4) != 0) return false;

        var pointer = self.read_config_8(0x34);
        var index: u64 = 0;

        while (true)
        {
            if (pointer == 0) break;
            const _index = index;
            index += 1;
            if (_index >= 0xff) break;

            var dw = self.read_config_32(pointer);
            const next_pointer = @truncate(u8, dw >> 8);
            const id = @truncate(u8, dw);

            if (id != 5)
            {
                pointer = next_pointer;
                continue;
            }

            const msi = arch.MSI.register(handler, context, owner_name);

            if (msi.address == 0) return false;
            var control = @truncate(u16, dw >> 16);

            if (msi.data & ~@as(u64, 0xffff) != 0)
            {
                MSI.unregister(msi.tag);
                return false;
            }

            if (msi.address & 0b11 != 0)
            {
                MSI.unregister(msi.tag);
                return false;
            }
            if (msi.address & 0xFFFFFFFF00000000 != 0 and ~control & (1 << 7) != 0)
            {
                MSI.unregister(msi.tag);
                return false;
            }

            control = (control & ~@as(u16, 7 << 4)) | (1 << 0);
            dw = @truncate(u16, dw) | (@as(u32, control) << 16);

            self.write_config_32(pointer + 0, dw);
            self.write_config_32(pointer + 4, @truncate(u32, msi.address));

            if (control & (1 << 7) != 0)
            {
                self.write_config_32(pointer + 8, @truncate(u32, msi.address >> 32));
                self.write_config_16(pointer + 12, @intCast(u16, (self.read_config_16(pointer + 12) & 0x3800) | msi.data));
                if (control & (1 << 8) != 0) self.write_config_32(pointer + 16, 0);
            }
            else
            {
                self.write_config_16(pointer + 8, @intCast(u16, msi.data));
                if (control & (1 << 8) != 0) self.write_config_32(pointer + 12, 0);
            }

            return true;
        }

        return false;
    }
};

pub const Bus = enum(u8)
{
    do_not_scan = 0,
    scan_next = 1,
    scanned = 2,
};

pub const Features = Bitflag(enum(u64)
    {
        bar_0 = 0,
        bar_1 = 1,
        bar_2 = 2,
        bar_3 = 3,
        bar_4 = 4,
        bar_5 = 5,
        interrupts = 8,
        busmastering_DMA = 9,
        memory_space_access = 10,
        io_port_access = 11,
    });

pub var driver: *Driver = undefined;
