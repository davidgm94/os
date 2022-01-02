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

pub mod Physical
{
    use kernel::*;

    pub struct PageFrame
    {
    }

    pub struct Allocator<'a>
    {
        pub pageframes: &'a mut [Volatile<PageFrame>],
        pub commit_mutex: Mutex,
        pub pageframe_mutex: Mutex,
    }

    bitflags!
    {
        pub struct Flags: u32
        {
            const can_fail = 1 << 0;
            const commit_now = 1 << 1;
            const zeroed = 1 << 2;
            const lock_acquired = 1 << 3;
        }
    }
    impl<'a> Allocator<'a>
    {
        pub fn allocate_extended(&mut self, flags: Flags, count: u64, alignment: u64, below: u64) -> u64
        {
            let mutex_already_acquired = flags.contains(Flags::lock_acquired);
            if mutex_already_acquired
            {
                self.pageframe_mutex.assert_locked();
            }
            else
            {
            }
            unimplemented!();
        }

        pub fn allocate_with_flags(&mut self, flags: Flags) -> u64
        {
            self.allocate_extended(flags, 1, 1, 0)
        }
    }
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
