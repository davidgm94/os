ENTRY(_start)

virtual_base = 0xFFFFFFFF80000000;
SECTIONS
{
    . = virtual_base;
	.text ALIGN(4K) : AT(ADDR(.text) - virtual_base)
	{
		*(.text)
        *(.text.memset)
        *(.text.memcpy)
        *(.text.compiler_rt.udivmod.udivmod)
        *(.text.__udivti3)
	}
	.rodata ALIGN(4K) : AT(ADDR(.rodata) - virtual_base)
	{
		*(.rodata)
        *(.rodata.str1.1)
        *(.rodata.cst4)
        *(.rodata.cst8)
        *(.rodata.cst16)
        *(.rodata.cst32)
	}
	.data ALIGN(4K) : AT(ADDR(.data) - virtual_base)
	{
		*(.data)
        *(.data.rel.ro)
	}
	.bss ALIGN(4K) : AT(ADDR(.bss) - virtual_base)
	{
		*(COMMON)
		*(.bss)
	}
}
