[bits 16]
[org 0x7c00]

start:
    cli
    .hlt:
    hlt
    jmp .hlt
