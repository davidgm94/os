const std = @import("std");
const Kernel = @import("kernel.zig");
pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace) noreturn
{
    _ = stack_trace;
    // @TODO: this is a workaround to get message debug information
    Kernel.panic_raw(message);
}
