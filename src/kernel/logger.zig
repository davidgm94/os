const std = @import("std");
const Kernel = @import("kernel.zig");

const Self = @This();

var buffer: [0x40000]u8 = undefined;

pub fn log_lockfree(comptime module: @TypeOf(.EnumLiteral), comptime format: []const u8, arguments: anytype) void
{
    _ = module; _ = format; _ = arguments;
}

pub fn panic_lockfree(comptime module: @TypeOf(.EnumLiteral), comptime format: []const u8, arguments: anytype) noreturn
{
    _ = module; _ = format; _ = arguments;
    Kernel.Arch.CPU_stop();
}

pub fn panic(comptime module: @TypeOf(.EnumLiteral), comptime format: []const u8, arguments: anytype) noreturn
{
    _ = module; _ = format; _ = arguments;
    Kernel.Arch.CPU_stop();
}
