.intel_syntax noprefix

.section .bss
.equiv stack_size, 0x4000
.align 0x10
.lcomm stack, stack_size

.section .data
.comm installation_ID, 0x10
.comm bootloader_ID, 8
.comm bootloader_information_offset, 8
.comm kernel_size, 4


.section .text
.global _start


_start:
    mov rax, OFFSET kernel_size
    mov [rax], edx
    xor rdx, rdx

    mov rax, 0x63
    mov fs, ax
    mov gs, ax

    // save bootloader id
    mov rax, OFFSET bootloader_ID
    mov [rax], rsi

    cmp rdi, 0
    jne .standard_acpi
    mov rax, 0x7fe8
    mov [rax], rdi
    .standard_acpi:

    mov rax, OFFSET bootloader_information_offset
    mov [rax], rdi

    mov rsp, OFFSET stack + stack_size

    mov rbx, OFFSET installation_ID
    mov rax, [rdi + 0x7ff0]
    mov [rbx], rax
    mov rax, [rdi + 0x7ff8]
    mov [rbx + 8], rax

    // unmap the identity paging the bootloader used
    mov rax, 0xFFFFFF7FBFDFE000
    mov qword ptr [rax], 0
    mov rax, cr3
    mov cr3, rax

    call PIC_disable

    .loop:
    jmp .loop

.extern PIC_disable
