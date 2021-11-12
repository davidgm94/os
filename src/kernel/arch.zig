const Kernel = @import("kernel.zig");
pub usingnamespace @import("x86.zig");

pub const CPU = extern struct
{
    processor_ID: u8,
    kernel_processor_ID: u8,
    APIC_ID: u8,
    boot_processor: bool,
    local_storage: *Kernel.CPULocalStorage,

    // @TODO: add more components
    //
};
