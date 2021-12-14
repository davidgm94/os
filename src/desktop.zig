const lib = @import("lib.zig");
export fn _start() callconv(.C) void
{
    lib.exit_current_process(0);
}
