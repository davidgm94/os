[section .text]

[global _syscall]
_syscall:
    push rbp
    push rbx
    push r15
    push r14
    push r13
    push r12
    push r11
    push rcx
    mov r12,rsp
    syscall
    mov rsp,r12
    pop rcx
    pop r11
    pop r12
    pop r13
    pop r14
    pop r15
    pop rbx
    pop rbp
    ret
