const kernel = @import("kernel.zig");

const TODO = kernel.TODO;
const panic_raw = kernel.panic_raw;

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

pub fn parse_tables(self: *@This()) void
{
    if (@intToPtr(?*RootSystemDescriptorPointer, kernel.process.address_space.map_physical(find_RSDP(), 16384, Region.Flags.empty()))) |rsdp|
    {
        self.rsdp = rsdp;
    }
    else
    {
        panic_raw("unable to get RSDP");
    }
}

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

pub const DescriptorTable = struct
{
};
