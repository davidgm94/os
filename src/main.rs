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
#![feature(exclusive_range_pattern)]

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

mod kernel;

use core::panic::PanicInfo;

#[panic_handler]
pub extern "C" fn panic(_ : &PanicInfo) -> !
{
    loop{}
}
