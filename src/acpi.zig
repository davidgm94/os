const kernel = @import("kernel.zig");

const TODO = kernel.TODO;
const panic_raw = kernel.panic_raw;
const sum_bytes = kernel.sum_bytes;

const Region = kernel.memory.Region;
const find_RSDP = kernel.Arch.find_RSDP;
const CPU = kernel.Arch.CPU;

processor_count: u64,
IO_APIC_count: u64,
interrupt_override_count: u64,
LAPIC_NMI_count: u64,

processors: [256]CPU,
IO_APICs: [16]IO_APIC,
interrupt_overrides: [256]InterruptOverride,
LAPIC_NMIs: [32]LAPIC_NMI,

rsdp: *RootSystemDescriptorPointer,
madt: *align(1) DescriptorTable,

LAPIC_address: [*]volatile u32,
LAPIC_ticks_per_ms: u64,

PS2_controller_unavailable: bool,
VGA_controller_unavailable: bool,
century_register_index: u8,

HPET_base_address: ?[*]volatile u64,
HPET_period: u64,

const RSDP_signature = 0x2052545020445352;
const RSDT_signature = 0x54445352;
const XSDT_signature = 0x54445358;
const MADT_signature = 0x43495041;
const FADT_signature = 0x50434146;
const HPET_signature = 0x54455048;

pub const RootSystemDescriptorPointer = extern struct
{
    signature: u64,
    checksum: u8,
    OEM_ID: [6]u8,
    revision: u8,
    RSDT_address: u32,
    length: u32,
    XSDT_address: u64,
    extended_checksum: u8,
    reserved: [3]u8,

    pub const signature = 0x2052545020445352;
};

pub const IO_APIC = struct
{
    id: u8,
    address: [*]volatile u32,
    GSI_base: u32,

    pub fn read(self: *@This(), register: u32) u32
    {
        self.address[0] = register;
        return self.address[4];
    }
};

pub const InterruptOverride = struct
{
    source_IRQ: u8,
    GSI_number: u32,
    active_low: bool,
    level_triggered: bool,
};

pub const LAPIC_NMI = struct
{
    processor: u8,
    lint_index: u8,
    active_low: bool,
    level_triggered: bool,
};

pub const DescriptorTable = extern struct
{
    signature: u32,
    length: u32,
    id: u64,
    table_ID: u64,
    OEM_revision: u32,
    creator_ID: u32,
    creator_revision: u32,

    pub const header_length = 36;

    pub fn check(self: *align(1) @This()) void
    {
        if (sum_bytes(@ptrCast([*]u8, self)[0..self.length]) != 0)
        {
            panic_raw("ACPI table checksum failed!");
        }
    }
};

pub const MultipleAPICDescriptionTable = extern struct
{
    LAPIC_address: u32,
    flags: u32,
};

pub fn parse_tables(self: *@This()) void
{
    var is_XSDT = false;
    const sdt = blk:
    {
        if (@intToPtr(?*RootSystemDescriptorPointer, kernel.process.address_space.map_physical(find_RSDP(), 16384, Region.Flags.empty()))) |rsdp|
        {
            self.rsdp = rsdp;

            is_XSDT = self.rsdp.revision == 2 and self.rsdp.XSDT_address != 0;
            const sdt_physical_address =
                if (is_XSDT) self.rsdp.XSDT_address
                else self.rsdp.RSDT_address;

            break :blk @intToPtr(*align(1) DescriptorTable, kernel.process.address_space.map_physical(sdt_physical_address, 16384, Region.Flags.empty()));
        }
        else
        {
            panic_raw("unable to get RSDP");
        }
    };

    const is_valid = ((sdt.signature == XSDT_signature and is_XSDT) or (sdt.signature == RSDT_signature and !is_XSDT)) and sdt.length < 16384 and sum_bytes(@ptrCast([*]u8, sdt)[0..sdt.length]) == 0;

    if (!is_valid) panic_raw("system descriptor pointer is invalid");

    const table_count = (sdt.length - @sizeOf(DescriptorTable)) >> (@as(u2, 2) + @boolToInt(is_XSDT));

    if (table_count == 0) panic_raw("no tables found");

    const table_list_address = @ptrToInt(sdt) + DescriptorTable.header_length;

    var found_madt = false;
    var i: u64 = 0;

    while (i < table_count) : (i += 1)
    {
        const address =
            if (is_XSDT) @intToPtr([*]align(1) u64, table_list_address)[i]
            else @intToPtr([*]align(1) u32, table_list_address)[i];

        const header = @intToPtr(*align(1) DescriptorTable, kernel.process.address_space.map_physical(address, @sizeOf(DescriptorTable), Region.Flags.empty()));

        switch (header.signature)
        {
            MADT_signature =>
            {
                const madt_header = @intToPtr(*align(1) DescriptorTable, kernel.process.address_space.map_physical(address, header.length, Region.Flags.empty()));
                madt_header.check();

                if (@intToPtr(?*align(1) MultipleAPICDescriptionTable, @ptrToInt(madt_header) + DescriptorTable.header_length)) |madt|
                {
                    found_madt = true;

                    const start_length = madt_header.length - DescriptorTable.header_length - @sizeOf(MultipleAPICDescriptionTable);
                    var length = start_length;
                    var madt_bytes = @intToPtr([*]u8, @ptrToInt(madt) + @sizeOf(MultipleAPICDescriptionTable));
                    self.LAPIC_address = @intToPtr([*]volatile u32, map_physical_memory(madt.LAPIC_address, 0x10000));
                    _ = length;
                    _ = madt_bytes;

                    var entry_length: u8 = undefined;

                    while (length != 0 and length <= start_length) :
                        ({
                            length -= entry_length;
                            madt_bytes = @intToPtr([*]u8, @ptrToInt(madt_bytes) + entry_length);
                        })
                    {
                        const entry_type = madt_bytes[0];
                        entry_length = madt_bytes[1];

                        switch (entry_type)
                        {
                            0 =>
                            {
                                if (madt_bytes[4] & 1 == 0) continue;
                                const cpu = &self.processors[self.processor_count];
                                cpu.processor_ID = madt_bytes[2];
                                cpu.APIC_ID = madt_bytes[3];
                                self.processor_count += 1;
                            },
                            1 =>
                            {
                                const madt_u32 = @ptrCast([*]align(1)u32, madt_bytes);
                                var io_apic = &self.IO_APICs[self.IO_APIC_count];
                                io_apic.id = madt_bytes[2];
                                io_apic.address = @intToPtr([*]volatile u32, map_physical_memory(madt_u32[1], 0x10000));
                                // make sure it's mapped
                                _ = io_apic.read(0);
                                io_apic.GSI_base = madt_u32[2];
                                self.IO_APIC_count += 1;
                            },
                            2 =>
                            {
                                const madt_u32 = @ptrCast([*]align(1)u32, madt_bytes);
                                const interrupt_override = &self.interrupt_overrides[self.interrupt_override_count];
                                interrupt_override.source_IRQ = madt_bytes[3];
                                interrupt_override.GSI_number = madt_u32[1];
                                interrupt_override.active_low = madt_bytes[8] & 2 != 0;
                                interrupt_override.level_triggered = madt_bytes[8] & 8 != 0;
                                self.interrupt_override_count += 1;
                            },
                            4 =>
                            {
                                const nmi = &self.LAPIC_NMIs[self.LAPIC_NMI_count];
                                nmi.processor = madt_bytes[2];
                                nmi.lint_index = madt_bytes[5];
                                nmi.active_low = madt_bytes[3] & 2 != 0;
                                nmi.level_triggered = madt_bytes[3] & 8 != 0;
                                self.LAPIC_NMI_count += 1;
                            },
                            else => {},
                        }
                    }

                    if (self.processor_count > 256 or self.IO_APIC_count > 16 or self.interrupt_override_count > 256 or self.LAPIC_NMI_count > 32)
                    {
                        panic_raw("wrong numbers");
                    }
                }
                else
                {
                    panic_raw("ACPI initialization - couldn't find the MADT table");
                }
            },
            FADT_signature =>
            {
                const fadt = @intToPtr(*align(1) DescriptorTable, kernel.process.address_space.map_physical(address, header.length, Region.Flags.empty()));
                fadt.check();

                if (header.length > 109)
                {
                    const fadt_bytes = @ptrCast([*]u8, fadt);
                    self.century_register_index = fadt_bytes[108];
                    const boot_architecture_flags = fadt_bytes[109];
                    self.PS2_controller_unavailable = (~boot_architecture_flags & (1 << 1)) != 0;
                    self.VGA_controller_unavailable = (boot_architecture_flags & (1 << 2)) != 0;
                }

                _ = kernel.process.address_space.free(@ptrToInt(fadt));
            },
            HPET_signature =>
            {
                const hpet = @intToPtr(*align(1) DescriptorTable, kernel.process.address_space.map_physical(address, header.length, Region.Flags.empty()));
                hpet.check();

                const header_bytes = @ptrCast([*]u8, header);
                if (header.length > 52 and header_bytes[52] == 0)
                {
                    if (@intToPtr(?[*]volatile u64, kernel.process.address_space.map_physical(@ptrCast(*align(1) u64, &header_bytes[44]).*, 1024, Region.Flags.empty()))) |HPET_base_address|
                    {
                        self.HPET_base_address = HPET_base_address;
                        self.HPET_base_address.?[2] |= 1; // start the main counter

                        self.HPET_period = self.HPET_base_address.?[0] >> 32;
                        // @INFO: Just for logging
                        //const revision_ID = @truncate(u8, self.HPET_base_address[0]);
                        //const initial_count = self.HPET_base_address[30];
                    }
                    else
                    {
                        panic_raw("failed to map HPET base address\n");
                    }
                }

                _ = kernel.process.address_space.free(@ptrToInt(hpet));
            },
            else => {},
        }


        _ = kernel.process.address_space.free(@ptrToInt(header));
    }

    if (!found_madt) panic_raw("MADT not found");
}

fn map_physical_memory(physical_address: u64, length: u64) u64
{
    return kernel.process.address_space.map_physical(physical_address, length, Region.Flags.from_flag(.not_cacheable));
}
