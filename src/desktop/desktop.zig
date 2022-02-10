const lib = @import("../shared/lib.zig");
export fn _start() callconv(.C) void
{
    lib.exit_current_process(0);
}
