pub use core::arch::asm;
pub use core::mem::{size_of, transmute};
pub mod arch;

pub struct Kernel<'a>
{
    arch: arch::Specific<'a>,
}

pub static mut kernel: Kernel = Kernel
{
    arch: arch::Specific::default(),
};
