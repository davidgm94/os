pub const ACPI = @import("drivers/ACPI.zig");
pub const AHCI = @import("drivers/AHCI.zig");
pub const PCI = @import("drivers/PCI.zig");
pub const serial = @import("drivers/serial.zig");
pub const SVGA = @import("drivers/SVGA.zig");

pub fn init() void
{
    PCI.Driver.init();
    serial.write("PCI driver initialized\n");
    AHCI.Driver.init();
    serial.write("AHCI driver initialized\n");
    SVGA.Driver.init();
    serial.write("SVGA driver initialized\n");
    SVGA.driver.debug_clear_screen(0x18, 0x7e, 0xcf);
}

