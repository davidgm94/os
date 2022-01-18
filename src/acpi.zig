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

HPET_base_address: [*]volatile u64,
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
                TODO();
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
                        self.HPET_base_address[2] |= 1; // start the main counter

                        self.HPET_period = self.HPET_base_address[0] >> 32;
                        // @INFO: Just for logging
                        //const revision_ID = @truncate(u8, self.HPET_base_address[0]);
                        //const initial_count = self.HPET_base_address[30];
                    }
                    else
                    {
                        panic_raw("failed to map HPET base addres\n");
                    }
                }

                _ = kernel.process.address_space.free(@ptrToInt(hpet));
            },
            else => {},
        }

        _ = kernel.process.address_space.free(@ptrToInt(header));
    }

    TODO();
}
