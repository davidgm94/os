const std = @import("std");

pub fn stop_cpu() callconv(.Inline) noreturn
{
    asm volatile("sti");

    while (true)
    {
        asm volatile("hlt");
    }
}

const CR0 = struct
{
    const Offset = enum(u8)
    {
        protection_enabled = 0,
        // used along the task_switched bit to control whether execution of wait/fwait instruction
        // causes a device-not-available exception (#NM) to ocurr.
        // Read more at AMD64 Architecture Programmer's Manual, Volume 2: System Programming, page 100
        monitor_coprocessor = 1, 
        emulation = 2,
        task_switched = 3,
        extension_type = 4,
        numeric_error = 5,
        write_protect = 16,
        alignment_mask = 18,
        not_writethrough = 29,
        cache_disable = 30,
        paging = 31,
        // In long mode, bits 32:63 should be written to zero, otherwise a #GP occurs
    };
};
