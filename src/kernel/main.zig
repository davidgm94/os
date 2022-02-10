const std = @import("std");
const kernel = @import("kernel.zig");

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn
{
    kernel.KernelPanicF("{s}.\nStack trace: {}\n", .{message, stack_trace});
}
