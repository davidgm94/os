[bits 64]

[section .bss]

%define stack_size 0x4000
%define idt_size 0x1000
%define cpu_local_storage_size 0x2000

stack: resb stack_size
idt_data: resb idt_size
[global cpu_local_storage]
cpu_local_storage: resb cpu_local_storage_size

[section .data]
idt:
    .limit: dw idt_size - 1
    .base:  dq idt_data

cpu_local_storage_index: dq 0

; (...)

align 0x10
[global processor_GDTR]
processor_GDTR:
    dq 0
    dq 0

[section .text]

[global _start]
_start:
    cli
    mov rax, 0x63
    mov fs, ax
    mov gs, ax

    mov [0x7FE8], rdi

    .standard_acpi:
    mov rsp, stack + stack_size
    
    mov rax, bootloader_information_offset
    mov [rax], rdi

    ; installation id

    ;unmap bootloader's identity mapping
    mov rax, 0xFFFFFF7FBFDFE000
    mov qword [rax], 0
    mov rax, cr3
    mov cr3, rax

setup_com_1:

IDT_install:
    .remap_PIC:
    mov al, 0x11
    out 0x20, al
    mov al, 0x11
    out 0xA0, al
    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xA1, al
    mov al, 0x04
    out 0x21, al
    mov al, 0x02
    out 0xA1, al
    mov al, 0x01
    out 0x21, al
    mov al, 0x01
    out 0xA1, al
    mov al, 0x00
    out 0x21, al
    mov al, 0x00
    out 0xA1, al

    .interrupt_handlers:
%macro INSTALL_INTERRUPT_HANDLER 1
    mov rbx, (%1 * 16) + idt_data
    mov rdx, interrupt_handler_%1
    call install_interrupt_handler
%endmacro

%assign i 0
%rep 256
    INSTALL_INTERRUPT_HANDLER i
%assign i i+1
%endrep

    ; save bootstrap GDT
    mov rcx, processor_GDTR
    sgdt [rcx]

memory_calculations:
    cli
    hlt

install_interrupt_handler:
    mov word [rbx + 0], dx
    mov word [rbx + 2], 0x48
    mov word [rbx + 4], 0x8e00
    shr rdx, 16
    mov word [rbx + 6], dx
    shr rdx, 16
    mov qword [rbx + 8], rdx

    ret

%macro INTERRUPT_HANDLER_COMMON 0
    cld
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    mov rax, cr8
    push rax

    mov rax, 0x123456789ABCDEF
    push rax

    mov rbx, rsp
    and rsp, ~0xf
    fxsave [rsp - 512]
    mov rsp, rbx
    sub rsp, 512 + 16
    
    xor rax, rax
    mov ax, ds
    push rax
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov rax, cr2
    push rax

    mov rdi, rsp
    mov rbx, rsp
    and rsp, ~0xf

    extern interrupt_handler
    call interrupt_handler

    mov rsp, rbx
    xor rax, rax

    .return:
    add rsp, 8
    pop rbx
    mov ds, bx
    mov es, bx

    add rsp, 512 + 16
    mov rbx, rsp
    and rbx, ~0xf
    fxrstor [rbx - 512]

    cmp al, 0
    je .old_thread
    fninit ; new thread -> initialize FPU

    .old_thread:
    pop rax
    mov rbx, 0x123456789ABCDEF
    cmp rax, rbx
    jne $

    cli
    pop rax
    mov cr8, rax

    pop	r15
	pop	r14
	pop	r13
	pop	r12
	pop	r11
	pop	r10
	pop	r9
	pop	r8
	pop	rbp
	pop	rdi
	pop	rsi
	pop	rdx
	pop	rcx
	pop	rbx
	pop	rax

    add rsp, 16
    iretq
%endmacro

%macro INTERRUPT_HANDLER 1
interrupt_handler_%1:
    push dword 0 ; fake error code
    push dword %1 ; interrupt_number
    INTERRUPT_HANDLER_COMMON
%endmacro

%macro INTERRUPT_HANDLER_EC 1
interrupt_handler_%1:
    push dword %1 ; interrupt_number
    INTERRUPT_HANDLER_COMMON
%endmacro


INTERRUPT_HANDLER 0
INTERRUPT_HANDLER 1
INTERRUPT_HANDLER 2
INTERRUPT_HANDLER 3
INTERRUPT_HANDLER 4
INTERRUPT_HANDLER 5
INTERRUPT_HANDLER 6
INTERRUPT_HANDLER 7
INTERRUPT_HANDLER_EC 8
INTERRUPT_HANDLER 9
INTERRUPT_HANDLER_EC 10
INTERRUPT_HANDLER_EC 11
INTERRUPT_HANDLER_EC 12
INTERRUPT_HANDLER_EC 13
INTERRUPT_HANDLER_EC 14
INTERRUPT_HANDLER 15
INTERRUPT_HANDLER 16
INTERRUPT_HANDLER_EC 17
INTERRUPT_HANDLER 18
INTERRUPT_HANDLER 19
INTERRUPT_HANDLER 20
INTERRUPT_HANDLER 21
INTERRUPT_HANDLER 22
INTERRUPT_HANDLER 23
INTERRUPT_HANDLER 24
INTERRUPT_HANDLER 25
INTERRUPT_HANDLER 26
INTERRUPT_HANDLER 27
INTERRUPT_HANDLER 28
INTERRUPT_HANDLER 29
INTERRUPT_HANDLER 30
INTERRUPT_HANDLER 31

%assign i 32
%rep 224
INTERRUPT_HANDLER i
%assign i i+1
%endrep

[global bootloader_information_offset]
bootloader_information_offset: dq 0
