#![allow(non_snake_case)]
#![allow(non_camel_case_types)]
#![allow(non_upper_case_globals)]
#![allow(unsupported_naked_functions)]

#![no_std]
#![no_main]

#![feature(untagged_unions)]
#![feature(naked_functions)]
#![feature(variant_count)]
#![feature(link_llvm_intrinsics)]
#![feature(integer_atomics)]
#![feature(core_intrinsics)]

#![feature(asm_const)]
#![feature(asm_sym)]

#![feature(const_maybe_uninit_assume_init)]
#![feature(const_slice_from_raw_parts)]
#![feature(const_default_impls)]
#![feature(const_trait_impl)]
#![feature(const_fn_trait_bound)]
#![feature(const_fn_fn_ptr_basics)]
#![feature(const_ptr_offset)]
#![feature(const_ptr_offset_from)]
#![feature(const_option)]
#![feature(const_mut_refs)]
#![feature(maybe_uninit_slice)]

use core::panic::PanicInfo;
use core::arch::asm;
use core::mem::size_of;
pub struct CR3;

impl CR3
{
    #[inline(always)]
    fn flush()
    {
        unsafe
        {
            asm!( "mov rax, cr3", "mov cr3, rax")
        }
    }
}

#[naked]
#[no_mangle]
pub extern "C" fn _start()
{
    unsafe
    {
        asm!(
            "mov rax, 0x63",
            "mov fs, ax",
            "mov gs, ax",

            "mov {0:e}, edx",
            "mov {1}, rsi",
            "mov {2}, rdi",
            out(reg) arch_kernel.kernel_size,
            out(reg) arch_kernel.bootloader_id,
            out(reg) arch_kernel.bootloader_information_offset,
        );

        if arch_kernel.bootloader_information_offset == 0
        {
            *(0x7fe8 as *mut u64) = arch_kernel.bootloader_information_offset;
        }

        asm!(
            "mov rsp, OFFSET {} + {}",
            sym stack,
            const size_of::<Stack>()
        );

        arch_kernel.installation_id = *((arch_kernel.bootloader_information_offset + 0x7ff0) as *mut u128);

        *(0xFFFFFF7FBFDFE000 as *mut u64) = 0;
        CR3::flush();
        Foo::foo();
    }
}

pub struct Foo
{
}

impl Foo
{
    fn foo()
    {
    }
}

#[repr(C, align(16))]
pub struct Stack
{
    memory: [u8; 0x4000],
}

#[link_section = ".bss"]
pub static mut stack: Stack = Stack { memory: [0; 0x4000] };

pub struct Arch
{
    installation_id: u128,
    bootloader_id: u64,
    bootloader_information_offset: u64,
    kernel_size: u32,
}

pub static mut arch_kernel: Arch = Arch { installation_id: 0, bootloader_id: 0, bootloader_information_offset: 0, kernel_size: 0 };

#[panic_handler]
pub extern "C" fn panic(_ : &PanicInfo) -> !
{
    loop{}
}
