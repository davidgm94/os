const std = @import("std");
const builtin = @import("builtin");
const target_cpu = if (builtin.cpu.arch == .x86_64) @import("arch/x86.zig") else @compileError("Architecture not supported");

pub fn stop_cpu() callconv(.Inline) noreturn
{
    target_cpu.stop_cpu();
}
