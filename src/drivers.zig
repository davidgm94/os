pub const AHCI = @import("drivers/ahci.zig");
pub const PCI = @import("drivers/pci.zig");
pub const SVGA = @import("drivers/svga.zig");

pub fn init() void
{
    const result = PCI.driver.init();
    SVGA.driver.init();
    AHCI.driver.init();
    _ = result;
}
