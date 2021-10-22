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

[global physical_memory_regions]
physical_memory_regions: dq 0xFFFFFE0000060000

[global physical_memory_region_count]
physical_memory_region_count: dq 0

[global physical_memory_region_page_count]
physical_memory_region_page_count: dq 0

[global physical_memory_original_page_count]
physical_memory_original_page_count: dq 0

[global physical_memory_region_index]
physical_memory_region_index: dq 0

[global physical_memory_highest]
physical_memory_highest: dq 0

[global paging_NXE_support]
paging_NXE_support: dd 1

[global paging_PCID_support]
paging_PCID_support: dd 1

[global paging_SMEP_support]
paging_SMEP_support: dd 1

[global paging_TCE_support]
paging_TCE_support: dd 1

[global SIMD_SSE3_support]
SIMD_SSE3_support: dd 1

[global SIMD_SSSE3_support]
SIMD_SSSE3_support: dd 1

[global bootloader_ID]
bootloader_ID: dd 0

[global bootloader_information_offset]
bootloader_information_offset: dq 0

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

COM_1_setup:

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
    mov rax, bootloader_information_offset
    mov rax, [rax]
    mov rbx, physical_memory_regions
    add [rbx], rax
    mov rdi, 0xFFFFFE0000060000 - 0x10
    add rdi, rax
    mov rsi, 0xFFFFFE0000060000
    add rsi, rax
    xor rax, rax
    xor r8, r8

    .loop:
    add rdi, 0x10
    mov r9, [rdi + 8]
    shl r9, 12
    add r9, [rdi]
    cmp r9, r8
    jb .lower
    mov r8, r9

    .lower:
    add rax, [rdi + 8]
    cmp qword [rdi], 0
    jne .loop
    mov rbx, [rdi + 8]
    sub rax, rbx
    sub rdi, rsi
    shr rdi, 4
    mov rsi, physical_memory_region_count
    mov [rsi], rdi
    mov rsi, physical_memory_region_page_count
    mov [rsi], rax
    mov rsi, physical_memory_original_page_count
    mov [rsi], rbx
    mov rsi, physical_memory_highest
    mov [rsi], r8

PIC_disable:
    mov al, 0xff
    out 0xa1, al
    out 0x21, al

kernel_start:
    call CPU0_setup

    and rsp, ~0xf
    extern kernel_main
    call kernel_main

CPU0_setup:
    .enable_cpu_features:
    ; no execute support if available
    mov eax, 0x80000001 
    cpuid
    and edx, 1 << 20
    shr edx, 20
    mov rax, paging_NXE_support
    and [rax], edx
    cmp edx, 0
    je .no_paging_NXE_support
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 11
    wrmsr

    .no_paging_NXE_support:

    .initialize_x87_fpu:
    fninit
    mov rax, .cw
    fldcw [rax]
    jmp .cwa
    .cw: dw 0x037a
    .cwa:

    .smep_support:
    xor eax, eax
    cpuid
    cmp eax, 7
    jb .no_smep_support
    mov eax, 7
    xor ecx, ecx
    cpuid
    and ebx, 1 << 7
    shr ebx, 7
    mov rax, paging_SMEP_support
    mov [rax], ebx
    cmp ebx, 0
    je .no_smep_support
    mov word [rax], 2
    mov rax, cr4
    or rax, 1 << 20
    mov cr4, rax

    .no_smep_support:

    .PCID_support:
    mov eax, 1
    xor ecx, ecx
    cpuid
    and ecx, 1 << 17
    shr ecx, 17
    mov rax, paging_PCID_support
    and [rax], ecx
    cmp ecx, 0
    je .no_pcid_support
    mov rax, cr4
    or rax, 1 << 17
    mov cr4, rax

    .no_pcid_support:

    .enable_global_pages:
    mov rax, cr4
    or rax, 1 << 7
    mov cr4, rax

    ; @TODO: is this right?
    .TCE_support:
    mov eax, 0x80000001
    xor ecx, ecx
    cpuid
    and ecx, 1 << 17
    shr ecx, 17
    mov rax, paging_TCE_support
    and [rax], ecx
    cmp ecx, 0
    je .no_tce_support
    mov eax, 0xC0000080
    rdmsr
    or eax, 1 << 15
    wrmsr
    
    .no_tce_support:

    .enable_write_protect:
    mov rax, cr0
    or rax, 1 << 16
    mov cr0, rax

    .enable_mmx_sse_sse2:
    mov rax, cr0
    mov rbx, cr4
    and rax, ~4
    or rax, 2
    or rbx, 512 + 1024
    mov cr0, rax
    mov cr4, rbx

    .detect_sse3_ssse3:
    mov eax, 1
    cpuid
    test ecx, 1 << 0
    jnz .has_sse3
    mov rax, SIMD_SSE3_support
    and byte [rax], 0

    .has_sse3:
    test ecx, 1 << 9
    jnz .has_ssse3
    mov rax, SIMD_SSSE3_support
    and byte [rax], 0
    
    .has_ssse3:

    .enable_syscall_extensions:
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1
    wrmsr
    add ecx, 1
    rdmsr
    mov edx, 0x005B0048
    wrmsr
    add ecx, 1
    mov rdx, syscall_entry
    mov rax, rdx
    shr rdx, 32
    wrmsr
    add ecx, 2
    rdmsr
    mov eax, (1 << 10) | (1 << 9) ; clear direction and interrupt flag when entering ring 0
    wrmsr

    ; assign PAT2 to WC
    mov ecx, 0x277
    xor rax, rax
    xor rdx, rdx
    rdmsr
    and eax, 0xFFF8FFFF
    or eax, 0x00010000
    wrmsr

    .setup_cpu_local_storage:
    cli
    hlt

syscall_entry:
    mov rsp, [gs:8]
    sti

    mov ax, 0x50
    mov ds, ax
    mov es, ax

    ; preserve RCX, R11, R12 and RBX
    push rcx
    push r11
    push r12
    mov rax, rsp
    push rbx
    push rax

    ; arguments in rdi, rsi, rdx, r8, r9 (RCX return address, RAX return value)
    [extern syscall]
    mov rbx, rsp
    and rsp, ~0xf
    call syscall
    mov rsp, rbx

    ; disable maskable interrupts
    cli

    ; return to long mode
    add rsp, 8
    push rax
    mov ax, 0x63
    mov ds, ax
    mov es, ax
    pop rax
    pop rbx
    pop r12
    pop r11
    pop rcx
    db 0x48
    sysret

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

