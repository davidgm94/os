[bits 16]
[org 0x600]

start: 
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov sp, 0x7c00

    sti
    xor ax, ax
    int 0x10
    mov ax, 3
    int 0x10

    cld
    mov si, 0x7c00
    mov di, 0x600
    mov cx, 0x200
    rep movsb

    jmp 0x0:find_partition

find_partition:
    mov byte [drive_number], dl
    mov ah, 0x8
    xor di, di
    int 0x13
    mov si, error_cannot_read_disk
    jc error
    and cx, 0x3f
    mov word [sector_count], cx
    inc dh
    shr dx, 8
    mov word [head_count], dx
    mov si, error_invalid_geometry
    or cx, cx
    jz error
    or dx, dx
    jz error

    mov bx, partition_entry_1
    cmp byte [bx], 0x80
    je found_partition

    mov bx, partition_entry_2
    cmp byte [bx], 0x80
    je found_partition

    mov bx, partition_entry_3
    cmp byte [bx], 0x80
    je found_partition

    mov bx, partition_entry_4
    cmp byte [bx], 0x80
    je found_partition

    mov si, error_no_bootable_partition
    jmp error

found_partition:
    push bx
    mov di, [bx + 8]
    mov bx, 0x7c00
    call load_sector

    jmp 0x0:0x7c00

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

; di - LBA.
; es:bx - buffer
load_sector:
	; Calculate cylinder and head.
	mov	ax,di
	xor	dx,dx
	div	word [sector_count]
	xor	dx,dx
	div	word [head_count]
	push	dx ; remainder - head
	mov	ch,al ; quotient - cylinder
	shl	ah,6
	mov	cl,ah

	; Calculate sector.
	mov	ax,di
	xor	dx,dx
	div	word [sector_count]
	inc	dx
	or	cl,dl

	; Load the sector.
	pop	dx
	mov	dh,dl
	mov	dl,[drive_number]
	mov	ax,0x0201
	int	0x13
	mov	si,error_cannot_read_disk
	jc	error

	ret


error_cannot_read_disk: db "Error: the disk could not be read (MBR)", 0
error_invalid_geometry: db "Error: invalid disk geometry (MBR)", 0
error_no_bootable_partition: db "Error: no bootable partition (MBR)", 0

drive_number: db 0
sector_count: dw 0
head_count: dw 0

times 0x1b4-($-$$) db 0

disk_identifier: times 10 db 0
partition_entry_1: times 16 db 0
partition_entry_2: times 16 db 0
partition_entry_3: times 16 db 0
partition_entry_4: times 16 db 0

dw 0xaa55
