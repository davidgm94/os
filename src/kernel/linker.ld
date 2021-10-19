OUTPUT_FORMAT(elf64-x86-64)
ENTRY(_start)

virtual_base = 0xFFFFFFFF80000000;

SECTIONS
{
    . = virtual_base;

    .text ALIGN(0x1000) : AT(ADDR(.text) - virtual_base)
    {
        *(.text)
    }
    .rodata ALIGN(0x1000): AT(ADDR(.rodata) - virtual_base)
    {
        *(.rodata)
    }
    .data ALIGN(0x1000): AT(ADDR(.data) - virtual_base)

    {
        *(.data)
    }
    .bss ALIGN(0x1000): AT(ADDR(.bss) - virtual_base)
    {
        *(COMMON)
        *(.bss)
    }
}
