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

[section .text]

[global _start]
_start:
    cli
    hlt
