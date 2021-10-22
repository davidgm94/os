const x86 = @import("x86.zig");
// @INFO: we need this for the symbols to be exported
comptime { _ = x86.interrupt_handler; _ = x86.syscall; }

export fn kernel_main() callconv(.C) noreturn
{
    while (true) { }
}
