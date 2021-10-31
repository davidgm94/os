const std = @import("std");
const Kernel = @import("kernel.zig");

export fn kernel_main() callconv(.C) noreturn
{
    Kernel.init();
    Kernel.Arch.CPU_stop();
}

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn
{
    _ = stack_trace;
    // @TODO: this is a workaround to get message debug information
    foo(message);
    while (true) @breakpoint();
}

fn foo(message: []const u8) void
{
    _ = message;
}
