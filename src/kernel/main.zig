const Kernel = @import("kernel.zig");

export fn kernel_main() callconv(.C) noreturn
{
    Kernel.init();
    Kernel.Arch.CPU_stop();
}
