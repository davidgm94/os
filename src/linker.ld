ENTRY(_start)

virtual_base = 0xFFFFFFFF80000000;
SECTIONS
{
	. = virtual_base;
	.text ALIGN(4K) : AT(ADDR(.text) - virtual_base)
	{
		*(.text)
	}
	.rodata ALIGN(4K) : AT(ADDR(.rodata) - virtual_base)
	{
		*(.rodata)
	}
    .data.rel.ro ALIGN(4K) : AT(ADDR(.data.rel.ro) - virtual_base)
    {
        *(.data.rel.ro)
    }
	.data ALIGN(4K) : AT(ADDR(.data) - virtual_base)
	{
		*(.data)
	}
	.bss ALIGN(4K) : AT(ADDR(.bss) - virtual_base)
	{
		*(COMMON)
		*(.bss)
	}
}
