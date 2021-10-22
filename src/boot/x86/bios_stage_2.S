[bits 16]
[org 0x1000]

%define superblock 0x8000
%define kernel_file_entry 0x8800
%define page_directory 0x40000
%define page_directory_length 0x20000
%define memory_map 0x60000
%define temporary_load_buffer 0x9000
%define partition_offset (0x800 * 0x200)
;%define kernel_byte_offset (0x102000 - partition_offset)
%define kernel_sector 0x10

start:
    mov dword [kernel_size], eax
    mov esp, 0x7c00

    mov [drive_number], dl
    mov [partition_entry], si
    mov [sector_count], bx
    mov [head_count], cx

check_pci:
    mov ax, 0xb101
    xor edi, edi
    int 0x1a
    mov si, error_no_pci
    jc error
    or ah, ah
    jnz error

check_cpuid:
    mov dword [24], .no_cpuid
    mov eax, 0
    cpuid
    jmp .has_cpuid
    .no_cpuid:
    mov si, error_no_cpuid
    jmp error
    .has_cpuid:

check_msr:
    mov dword [24], .no_msr
    mov ecx, 0xC0000080
    rdmsr
    jmp .has_msr
    .no_msr:
    mov si, error_no_msr
    jmp error
    .has_msr:

enable_a20:
    cli
    call check_a20
    jc .a20_enabled
    mov ax, 0x2401
    int 0x15
    call check_a20
    jc .a20_enabled
    mov si, error_cannot_enable_a20_line
    jmp error
    .a20_enabled:
    sti
    jmp identity_paging

check_a20:
; Set the carry flag if the A20 line is enabled
	mov	ax,0
	mov	es,ax
	mov	ax,0xFFFF
	mov	fs,ax
	mov	byte [es:0x600],0
	mov	byte [fs:0x610],0xFF
	cmp	byte [es:0x600],0xFF
	je	.enabled
	stc
	ret
	.enabled: 
	clc
	ret

identity_paging:
    mov eax, page_directory / 16
    mov es, ax

    xor eax, eax
    mov ecx, 0x400
    xor di, di
    rep stosd

    mov dword [es: 0x3ff * 4], page_directory | 3
    mov dword [es: 0], (page_directory + 0x1000) | 3

    mov edi, 0x1000
    mov cx, 0x400
    mov eax, 3
    .loop:
    mov [es:edi], eax
    add edi, 4
    add eax, 0x1000
    loop .loop

    mov eax, page_directory
    mov cr3, eax

load_gdt:
    lgdt [gdt_data.gdt]

inform_bios_mix_mode:
    mov eax, 0xec00
    mov ebx, 3
    int 0x15

load_memory_map:
    xor ebx, ebx
    xor ax, ax
    mov es, ax
    mov ax, memory_map / 16
    mov fs, ax

    .loop:
    mov di, .entry
    mov edx, 0x534D4150
    mov ecx, 24
    mov eax, 0xe820
    mov byte [.acpi], 1
    int 0x15
    jc .finished

    cmp eax, 0x534D4150
    jne .fail

    cmp dword [.type], 1
    jne .try_next
    cmp dword [.size], 0
    je .try_next
    cmp dword [.acpi], 0
    je .try_next

    mov eax, [.size]
    and eax, ~0x3ff
    or eax, eax
    jz .try_next

    cmp dword [.base + 4], 0
    jne .base_good
    cmp dword [.base], 0x100000
    jl .try_next

    .base_good:
    mov eax, [.base]
    and eax, 0xfff
    or eax, eax
    jz .base_aligned
    mov eax, [.base]
    and eax, ~0xfff
    add eax, 0x1000
    mov [.base], eax
    sub dword [.size], 0x1000
    sbb dword [.size + 4], 0

    .base_aligned:
    mov eax, [.size]
    and eax, ~0xfff
    mov [.size], eax

    mov eax, [.size]
    shr eax, 12
    push ebx
    mov ebx, [.size + 4]
    shl ebx, 20
    add eax, ebx
    pop ebx
    mov [.size], eax
    mov dword [.size + 4], 0

    push ebx
    mov ebx, [.pointer]
    mov eax, [.base]
    mov [fs:bx], eax
    mov eax, [.base + 4]
    mov [fs:bx + 4], eax
    mov eax, [.size]
    mov [fs:bx + 8], eax
    add [.total_memory], eax
    mov eax, [.size + 4]
    adc [.total_memory + 4], eax
    mov [fs:bx + 12], eax
    add dword [.pointer], 16
    pop ebx

    .try_next:
    or ebx, ebx
    jnz .loop

    .finished:
    mov eax, [.pointer]
    shr eax, 4
    or eax, eax
    jz .fail

    mov ebx, [.pointer]
    mov dword [fs:bx], 0
    mov dword [fs:bx + 4], 0

    mov eax, [.total_memory]
    mov dword [fs:bx + 8], eax
    mov eax, [.total_memory + 4]
    mov dword [fs:bx + 12], eax

    jmp allocate_kernel_buffer

    .fail:
    mov si, error_could_not_get_memory_map
    jmp error

    .pointer:
    dd 0
    .entry:
        .base: dq 0
        .size: dq 0
        .type: dd 0
        .acpi: dd 0
    .total_memory: dq 0



allocate_kernel_buffer:
    push ds
    push es
    push ss
    cli
    mov eax, cr0
    or eax, 0x80000001
    mov cr0, eax
    jmp 0x8:.protected_mode

    [bits 32]
    .protected_mode:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

    mov ecx, [kernel_size]
    shr ecx, 12
    inc ecx
    mov edx, ecx
    shl edx, 12

    xor ebx, ebx

    .memory_region_loop:
    mov eax, [ebx + memory_map + 4]
    or eax, eax
    jnz .try_next_memory_region
    mov eax, [ebx + memory_map]
    cmp eax, 0x100000
    jne .try_next_memory_region

    mov eax, [ebx + memory_map + 8]
    cmp eax, ecx
    jl .try_next_memory_region

    mov eax, [ebx + memory_map + 0]
    mov [kernel_buffer], eax
    add eax, edx
    mov [ebx + memory_map + 0], eax
    sub dword [ebx + memory_map + 8], ecx
    sbb dword [ebx + memory_map + 12], 0

    jmp .found_buffer

    .try_next_memory_region:
    add ebx, 16
    mov eax, [load_memory_map.pointer]
    cmp ebx, eax
    jne .memory_region_loop
    mov si, error_no_memory
    jmp error_32

    .found_buffer:
    mov eax, cr0
    and eax, 0x7FFFFFFF
    mov cr0, eax
    jmp 0x18:.real_mode

    [bits 16]
    .real_mode:
    mov eax, cr0
    and eax, 0x7FFFFFFE
    mov cr0, eax
    jmp 0x0:.finish

    .finish:
    pop ss
    pop es
    pop ds

load_kernel_into_memory:
    ; CX = sector count to load
    ; EAX = source sector
    ; EDI = destination raw address

    mov eax, dword [kernel_size]
    xor edx, edx
    mov ecx, 0x200
    div ecx ; eax = sector count
    cmp eax, 0x100
    mov si, error_kernel_sector_count_too_big
    jge error
    mov cx, ax
    mov edi, [kernel_buffer]

    ;mov edi, 0x8000
    ;mov cx, 45

    mov eax, kernel_sector
    call load_sectors
    jmp switch_to_protected_mode

; CX = sector count to load
; EAX = source sector
; EDI = destination raw address
load_sectors:
    .loop:
    pushad
    push edi

    mov bx, [partition_entry]
    mov ebx, [bx + 8]
    add eax, ebx

    mov [read_structure.lba], eax
    mov ah, 0x42
    mov dl, [drive_number]
    mov si, read_structure
    ; @TODO: emulator branching
    call load_sector

    mov si, error_cannot_read_disk
    jc error

    pop edi
    call move_sector_to_target

    popad
    add edi, 0x200
    inc eax
    loop .loop
    ret

load_sector:
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

move_sector_to_target:
    push ss
    push ds
    push es

    cli
    mov eax, cr0
    or eax, 0x80000001
    mov cr0, eax
    jmp 0x8:.protected_mode

    [bits 32]
    .protected_mode:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

    mov ecx, 0x200
    mov esi, temporary_load_buffer
    rep movsb

    mov eax, cr0
    and eax, 0x7FFFFFFF
    mov cr0, eax
    jmp 0x18:.real_mode

    [bits 16]
    .real_mode:
    mov eax, cr0
    and eax, 0x7FFFFFFE
    mov cr0, eax
    jmp 0x0:.finish

    .finish:
    pop es
    pop ds
    pop ss
    sti
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

switch_to_protected_mode:
    cli
    mov eax, cr0
    or eax, 0x80000001
    mov cr0, eax
    jmp 0x8:protected_mode

[bits 32]
protected_mode:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

check_elf:
    mov ebx, [kernel_buffer]
    mov esi, error_not_elf
    cmp dword [ebx + 0], 0x464c457f
    jne error_32
    mov esi, error_not_64_bit
    cmp byte [ebx + 4], 2
    jne error_32

stall:
    cli
    hlt

error_32:
    mov eax, cr0
    and eax, 0x7FFFFFFF
    mov cr0, eax
    jmp 0x18:.real_mode

    [bits 16]
    .real_mode:
    mov eax, cr0
    and eax, 0x7FFFFFFE
    mov cr0, eax
    jmp 0x0:.finish

    .finish:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    jmp error


read_structure:
    dw 0x10
    dw 1
    dd temporary_load_buffer
    .lba: dq 0

gdt_data:
    .null_entry dq 0
    .code_entry:
        dd 0xffff ; 0x08
        db 0
        dw 0xcf9a
        db 0
    .data_entry:
        dd 0xffff ; 0x10
        db 0
        dw 0xcf92
        db 0
    .code_entry_16:
        dd 0xffff ; 0x18
        db 0
        dw 0x0f9a
        db 0
    .data_entry_16:
        dd 0xffff ; 0x20
        db 0
        dw 0x0f92
        db 0
    .user_code:
        dd 0xffff ; 0x28
        db 0
        dw 0xcffa
        db 0
    .user_data:
        dd 0xffff ; 0x08
        db 0
        dw 0xcff2
        db 0
    .tss:
        dd 0x68
        db 0
        dw 0xe9
        db 0
        dq 0
    .code_entry_64:
        dd 0xffff ; 0x08
        db 0
        dw 0xaf9a
        db 0
    .data_entry_64:
        dd 0xffff ; 0x08
        db 0
        dw 0xaf92
        db 0
    .user_code_64:
        dd 0xffff ; 0x08
        db 0
        dw 0xaffa
        db 0
    .user_data_64:
        dd 0xffff ; 0x08
        db 0
        dw 0xaff2
        db 0
    .user_code_64c:
        dd 0xffff ; 0x08
        db 0
        dw 0xaffa
        db 0
    .gdt: dw (gdt_data.gdt - gdt_data - 1)
    .gdt2: dq gdt_data

drive_number db 0
partition_entry dw 0
sector_count dw 0
head_count dw 0

their_kernel_size: dq 0

kernel_buffer: dq 0
kernel_size: dd 0

kernel_data_stream_position: dw 0x850

error_no_pci: db "Error: could not find the PCI bus", 0
error_no_cpuid: db "Error: could not find CPUID", 0
error_no_msr: db "Error: could not find MSR", 0
error_cannot_enable_a20_line: db "Error: cannot enable A20 line", 0
error_could_not_get_memory_map: db "Error: could not get memory map", 0

error_not_elf: db "Error: not an ELF", 0
error_not_64_bit: db "Error: not 64-bit kernel", 0
error_cannot_read_disk: db "Error: cannot read disk", 0
error_unexpected_file_problem: db "Error: unexpected file problem", 0
error_kernel_too_large: db "Error: kernel too large", 0
error_no_memory: db "Error: no memory", 0
error_kernel_sector_count_too_big: db "Error: kernel sector count too large", 0
