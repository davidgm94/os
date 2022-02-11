const lib = @import("shared");
export fn _start() callconv(.C) void
{
    lib.exit_current_process(0);
}
