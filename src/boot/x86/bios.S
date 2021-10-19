[org 0x7c00]
[bits 16]

start: 
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov sp, 0x9c00

    sti
    xor ax, ax
    int 0x10
    mov ax, 3
    int 0x10
    cli

    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 0x01
    mov cr0, eax

    jmp CODE_SEG:protected_mode

gdt_start:
    dq 0x0 ; null descriptor
gdt_code:
    dw 0xffff
    dw 0x0 ; segment(0-15)
    db 0x0 ; segment(16-23)
    db 10011010b ; flags
    db 11001111b ; flags(4) + segment(16-19)
    db 0x0 ; segment(24-31)
gdt_data:
    dw 0xffff
    dw 0x0
    db 0x0
    db 10010010b
    db 11001111b
    db 0x0
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

[bits 32]
protected_mode:
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov esp, 0x90000

    sti
    mov ebx, PROTECTED_MODE_MESSAGE
    call print_string

    cli
    .hlt:
    hlt
    jmp .hlt

VIDEO_MEMORY equ 0xb8000
WHITE_ON_BLACK equ 0x0f

[bits 32]
print_string:
    pusha
    mov edx, VIDEO_MEMORY

    .loop:
    mov al, [ebx]
    mov ah, WHITE_ON_BLACK

    cmp al, 0
    je .done

    mov [edx], ax
    inc ebx
    add edx, 2

    jmp .loop

    .done:
    popa
    ret

PROTECTED_MODE_MESSAGE db "We are in protected mode", 0

times 510-($-$$) db 0
dw 0xaa55
