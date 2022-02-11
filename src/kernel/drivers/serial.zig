const kernel = @import("../kernel.zig");

const arch = kernel.arch;
const Spinlock = kernel.sync.Spinlock;

var lock: Spinlock = undefined;
pub fn write(message: []const u8) void
{
    lock.acquire();
    for (message) |c|
    {
        arch.debug_output_byte(c);
    }
    lock.release();
}
