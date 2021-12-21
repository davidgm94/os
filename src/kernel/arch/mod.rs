#[cfg(target_arch = "x86_64")]
mod x86_64;
#[cfg(target_arch = "x86_64")]
pub use self::x86_64::*;

pub struct CPU
{
}

pub struct PhysicalMemoryRegion
{
    base_address: u64,
    page_count: u64,
}

