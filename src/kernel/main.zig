const x86 = @import("x86.zig");
pub export fn interrupt_handler() callconv(.C) noreturn
{
    while (true) { }
}

pub export fn syscall() callconv(.C) noreturn
{
    while (true) { }
}

export fn kernel_main() noreturn
{
    while (true) { }
}
