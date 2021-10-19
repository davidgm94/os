[bits 64]

[section .bss]

align 16

%define stack_size 16384
stack: resb stack_size

%define idt_size 4096
idt_data: resb idt_size

%define cpu_local_storage_size 8192
[global cpu_local_storage]
cpu_local_storage: resb cpu_local_storage_size

[section .data]
idt:
    .limit: dw idt_size - 1
    .base:  dq idt_data

cpu_local_storage_index:
    dq 0

[global physicalMemoryRegions]
physicalMemoryRegions:
    dq 0xFFFFFE0000060000 
[global physicalMemoryRegionsCount]
physicalMemoryRegionsCount:
    dq 0
[global physicalMemoryRegionsPagesCount]
physicalMemoryRegionsPagesCount:
    dq 0
[global physicalMemoryOriginalPagesCount]
physicalMemoryOriginalPagesCount:
    dq 0
[global physicalMemoryRegionsIndex]
physicalMemoryRegionsIndex:
    dq 0
[global physicalMemoryHighest]
physicalMemoryHighest:
    dq 0

[global pagingNXESupport]
pagingNXESupport:
    dd 1
[global pagingPCIDSupport]
pagingPCIDSupport:
    dd 1
[global pagingSMEPSupport]
pagingSMEPSupport:
    dd 1
[global pagingTCESupport]
pagingTCESupport:
    dd 1
[global simdSSE3Support]
simdSSE3Support:
    dd 1
[global simdSSSE3Support]
simdSSSE3Support:
    dd 1

[global bootloaderID]
bootloaderID:
    dd 0
[global bootloaderInformationOffset]
bootloaderInformationOffset:
    dq 0

align 16
[global processorGDTR]
processorGDTR:
    dq 0
    dq 0

[section .text]

[global _start]
_start:
    cli
    mov rax, 0x63
    mov fs, ax
    mov gs, ax

    cmp rdi, 0
    jne .standard_acpi
    mov [0x7fe8], rdi

    .standard_acpi:
    mov rsp, stack + stack_size

    mov rax, bootloaderInformationOffset
    mov [rax], rdi

    mov rax, 0xFFFFFF7FBFDFE000
    mov qword [rax], 0
    mov rax, cr3
    mov cr3, rax

setup_COM1:

%ifdef COM_OUTPUT
    mov    dx,0x3F8 + 1
    mov    al,0x00
    out    dx,al
    mov    dx,0x3F8 + 3
    mov    al,0x80
    out    dx,al
    mov    dx,0x3F8 + 0
    mov    al,0x03
    out    dx,al
    mov    dx,0x3F8 + 1
    mov    al,0x00
    out    dx,al
    mov    dx,0x3F8 + 3
    mov    al,0x03
    out    dx,al
    mov    dx,0x3F8 + 2
    mov    al,0xC7
    out    dx,al
    mov    dx,0x3F8 + 4
    mov    al,0x0B
    out    dx,al
%endif

install_IDT:
    ; remap PIC
    mov	al,0x11
	out	0x20,al
	mov	al,0x11
	out	0xA0,al
	mov	al,0x20
	out	0x21,al
	mov	al,0x28
	out	0xA1,al
	mov	al,0x04
	out	0x21,al
	mov	al,0x02
	out	0xA1,al
	mov	al,0x01
	out	0x21,al
	mov	al,0x01
	out	0xA1,al
	mov	al,0x00
	out	0x21,al
	mov	al,0x00
	out	0xA1,al

%macro INSTALL_INTERRUPT_HANDLER 1
    mov rbx, (%1 * 16) + idt_data
    mov rdx, interrupt_handler%1
    call install_interrupt_handler
%endmacro

%assign i 0
%rep 256
    INSTALL_INTERRUPT_HANDLER i
%assign i i+1
%endrep

    mov rcx, processorGDTR
    sgdt [rcx]
    
    mov rax, bootloaderInformationOffset
    mov rax, [rax]
    mov rbx, physicalMemoryRegions
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
    mov rsi, physicalMemoryRegionsCount
    mov [rsi], rdi
    mov rsi, physicalMemoryRegionsPagesCount
    mov [rsi], rax
    mov rsi, physicalMemoryOriginalPagesCount
    mov [rsi], rbx
    mov rsi, physicalMemoryHighest
    mov [rsi], r8

disable_PIC:
    mov al, 0xff
    out 0xa1, al
    out 0x21, al

start_kernel:
    call setup_processor_1

    mov rdi, '-'
    mov rcx, 10

    .line:
    call processor_debug_output_byte
    loop .line

    mov rdi, 10
    call processor_debug_output_byte
    mov rdi, 13
    call processor_debug_output_byte

    and rsp, ~0xf
    extern kernel_main
    call kernel_main

install_interrupt_handler:
    mov word [rbx + 0], dx
    mov word [rbx + 2], 0x48
    mov word [rbx + 4], 0x8e00
    shr rdx, 16
    mov word [rbx + 6], dx
    shr rdx, 16
    mov qword [rbx + 8], rdx
    ret

%macro INTERRUPT_HANDLER 1
interrupt_handler%1:
    push dword 0
    push dword %1
    jmp interrupt_handler_common
%endmacro

%macro INTERRUPT_HANDLER_EC 1
interrupt_handler%1:
    push dword %1
    jmp interrupt_handler_common
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

interrupt_handler_common:
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

return_from_interrupt_handler:
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
    fninit

    .old_thread:

    pop rax
    mov rbx, 0x123456789ABCDEF
    cmp rax, rbx
    jne $

    cli
    pop rax
    mov cr8, rax

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    add rsp, 16
    iretq

setup_processor_1:
enable_cpu_features:
    mov eax, 0x80000001
    cpuid
    and edx, 1 << 20
    shr edx, 20
    mov rax, pagingNXESupport
    and [rax], edx
    cmp edx, 0
    je .no_paging_nxe_support
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 11
    wrmsr

    .no_paging_nxe_support:
    fninit
    mov rax, .cw
    fldcw [rax]
    jmp .cwa
    .cw: dw 0x037a
    .cwa:

    xor eax, eax
    cpuid
    cmp eax, 7
    jb .no_smep_support
    mov eax, 7
    xor ecx, ecx
    cpuid
    and ebx, 1 << 7
    shr ebx, 7
    mov rax, pagingSMEPSupport
    and [rax], ebx
    cmp ebx, 0
    je .no_smep_support
    mov word [rax], 2
    mov rax, cr4
    or rax, 1 << 20
    mov cr4, rax

    .no_smep_support:

    mov eax, 1
    xor ecx, ecx
    cpuid
    and ecx, 1 << 17
    shr ecx, 17
    mov rax, pagingPCIDSupport
    and [rax], ecx
    cmp ecx, 0
    je .no_pcid_support
    mov rax, cr4
    or rax, 1 << 17
    mov cr4, rax
    .no_pcid_support:

    mov rax, cr4
    or rax, 1 << 7
    mov cr4, rax

    mov eax, 0x80000001
    xor ecx, ecx
    cpuid
    and ecx, 1 << 17
    shr ecx, 17
    mov rax, pagingTCESupport
    and [rax], ecx
    cmp ecx, 0
    je .no_tce_support
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 15
    wrmsr
    .no_tce_support:

    mov rax, cr0
    or rax, 1 << 16
    mov cr0, rax

    mov rax, cr0
    mov rbx, cr4
    and rax, ~4
    or rax, 2
    or rbx, 512 + 1024
    mov cr0, rax
    mov cr4, rbx

    mov eax, 1
    cpuid
    test ecx, 1 << 0
    jnz .has_sse3
    mov rax, simdSSE3Support
    and byte [rax], 0
    .has_sse3:

    test ecx, 1 << 9
    jnz .has_ssse3
    mov rax, simdSSSE3Support
    and byte [rax], 0
    .has_ssse3:

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
    mov eax, (1 << 10) | (1 << 9)
    wrmsr

    mov ecx, 0x277
    xor rax, rax
    xor rdx, rdx
    rdmsr
    and eax, 0xFFF8FFFF
    or eax, 0x00010000
    wrmsr

setup_cpu_local_storage:
    mov ecx, 0xC0000101
    mov rax, cpu_local_storage
    mov rdx, cpu_local_storage
    shr rdx, 32
    mov rdi, cpu_local_storage_index
    add rax, [rdi]
    add qword [rdi], 32
    wrmsr

load_IDTR:
    mov rax, idt
    lidt [rax]
    sti

enable_APIC:
    mov ecx, 0x1b
    rdmsr
    and eax, ~0xfff
    mov edi, eax
    test eax, 1 << 8
    jne $
    or eax, 0x900
    wrmsr

    mov rax, 0xFFFFFE00000000F0
    add rax, rdi
    mov ebx, [rax]
    or ebx, 0x1ff
    mov [rax], ebx

    mov rax, 0xFFFFFE00000000E0
    add rax, rdi
    mov dword [rax], 0xFFFFFFFF

    xor rax, rax
    mov cr8, rax

    ret

syscall_entry:
    mov rsp, [gs:8]
    sti

    mov ax, 0x50
    mov ds, ax
    mov es, ax

    push rcx
    push r11
    push r12
    mov rax, rsp
    push rbx
    push rax

    [extern syscall]
    mov rbx, rsp
    and rsp, ~0xf
    call syscall
    mov rsp, rbx

    cli

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

[global processor_debug_output_byte]
processor_debug_output_byte:
%ifdef COM_OUTPUT
	mov	dx,0x3F8 + 5
	.WaitRead:
	in	al,dx
	and	al,0x20
	cmp	al,0
	je	.WaitRead
	mov	dx,0x3F8 + 0
	mov	rax,rdi
	out	dx,al
%endif
    ret
    
