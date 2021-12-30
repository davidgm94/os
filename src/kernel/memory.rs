use kernel::*;

pub struct AddressSpace
{
    pub arch: arch::Memory::AddressSpace,
    pub reference_count: u64,
}

pub struct Region
{
    base_address: u64,
    page_count: u64,
    used: bool,
}

impl<'a> Kernel<'a>
{
    pub fn memory_init(&mut self)
    {
        self.core.regions = unsafe { &mut *core::ptr::slice_from_raw_parts_mut(arch::core_memory_region_start as *mut Region, 1) };
        self.core.regions[0].used = false;
        self.core.regions[0].base_address = arch::core_address_space_start;
        self.core.regions[0].page_count = arch::core_address_space_size / arch::page_size as u64;
        arch::Memory::init(self);
    }
}
