; @TODO: implement emulator branching
[bits 16]
[org 0x7c00]

%define stage_2_address 0x1000
%define temporary_load_buffer 0x9000

start:
    cli
    mov dword [kernel_size], eax
    xor eax, eax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov sp, 0x7c00
    jmp 0x0:.continue

    .continue:
    sti

    mov [drive_number], dl
    mov [partition_entry], si

    ; use emulator?

    mov ah, 0x08
    xor di, di
    int 0x13
    mov si, error_cannot_read_disk
    jc error
    and cx, 0x3f
    mov [sector_count], cx
    inc dh
    shr dx, 8
    mov [head_count], dx

    mov si, startup_message
    .loop:
    lodsb
    or al, al
    jz .stage_2_load
    mov ah, 0x0e
    int 0x10
    jmp .loop

    .stage_2_load:
    mov cx, 15
    mov eax, 1
    mov edi, stage_2_address
    call load_sectors

    mov dl, [drive_number]
    mov si, [partition_entry]
    mov bx, [sector_count]
    mov cx, [head_count]
    mov eax, dword [kernel_size]
    jmp 0x0:stage_2_address

load_sectors:
    pusha
    push edi

    mov bx, [partition_entry]
    mov ebx, [bx + 8]
    add eax, ebx

    mov [read_structure.lba], eax
    mov ah, 0x42
    mov dl, [drive_number]
    mov si, read_structure
    call load_sector_emu

    mov si, error_cannot_read_disk
    jc error

    pop edi
    mov cx, 0x200
    mov eax, edi
    shr eax, 4
    and eax, 0xf000
    mov es, ax
    mov si, temporary_load_buffer
    rep movsb
    
    popa
    add edi, 0x200
    inc eax
    loop load_sectors
    ret

load_sector_emu:
    mov di, [read_structure.lba]
    xor ax, ax
    mov es, ax
    mov bx, 0x9000

    mov ax, di
    xor dx, dx
    div word [sector_count]
    xor dx, dx
    div word [head_count]
    push dx
    mov ch, al
    shl ah, 6
    mov cl, ah

    mov ax, di
    xor dx, dx
    div word [sector_count]
    inc dx
    or cl, dl

    pop dx
    mov dh, dl
    mov dl, [drive_number]
    mov ax, 0x0201
    int 0x13

    ret

error:
    .loop:
    lodsb
    or al, al
    jz .break
    mov ah, 0x0e
    int 0x10
    jmp .loop

    .break:
    cli
    hlt

kernel_size: dd 0
partition_entry: dw 0
sector_count: dw 0
head_count: dw 0
drive_number: db 0

read_structure:
    dw 0x10
    dw 1
    dd temporary_load_buffer
    .lba: dq 0

startup_message: db "Booting operating system...", 10, 13, 0
error_cannot_read_disk: db "Error: The disk could not be read (BIOS stage 1)", 0

times (0x200 - ($-$$)) db 0x0
