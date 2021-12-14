const std = @import("std");

pub const Handle = u64;

pub const Syscall = enum(u64)
{
    process_exit = 0,
};

pub const current_process: Handle = 0x11;

pub fn syscall(arg0: Syscall, arg1: u64, arg2: u64, arg3: u64, arg4: u64) callconv(.Inline) u64
{
    return _syscall(@enumToInt(arg0), arg1, arg2, 0, arg3, arg4);
}

pub fn exit_process(process_handle: Handle, status: i32) void
{
    _ = syscall(.process_exit, process_handle, @intCast(u64, status), 0, 0);
}

pub fn exit_current_process(status: i32) void
{
    exit_process(current_process, status);
}

extern fn _syscall(arg0: u64, arg1: u64, arg2: u64, unused: u64, arg3: u64, arg4: u64) callconv(.C) u64;

comptime
{
    asm(
\\.intel_syntax noprefix
\\.global _syscall
\\_syscall:
\\    push rbp
\\    push rbx
\\    push r15
\\    push r14
\\    push r13
\\    push r12
\\    push r11
\\    push rcx
\\    mov r12,rsp
\\    syscall
\\    mov rsp,r12
\\    pop rcx
\\    pop r11
\\    pop r12
\\    pop r13
\\    pop r14
\\    pop r15
\\    pop rbx
\\    pop rbp
\\    ret
    );
}
