use kernel::*;

pub struct AddressSpace
{
    pub reserve_mutex: Mutex,
    pub arch: arch::Memory::AddressSpace,
    pub reference_count: u64,
}

impl const Default for AddressSpace
{
    fn default() -> Self {
        Self
        {
            reserve_mutex: Mutex::default(),
            arch: arch::Memory::AddressSpace
            {
                cr3: 0,
            },
            reference_count: 0,
        }
    }
}

// @TODO: properly formalize this
pub const shared_entry_present: u64 = 1;

impl AddressSpace
{
    pub fn standard_allocate_extended(&mut self, byte_count: u64, flags: RegionFlags, base_address: u64, commit_all: bool) -> u64
    {
        self.reserve_mutex.acquire();

        let resulting_address =
        {
            if let Some(region) = unsafe { self.reserve_extended(byte_count, flags | RegionFlags::normal, base_address, true).as_mut() }
            {
                if commit_all && !self.commit_range(region, 0, region.page_count)
                {
                    self.unreserve(region, false);
                    0
                }
                else
                {
                    region.base_address
                }
            }
            else
            {
                0
            }
        };

        self.reserve_mutex.release();
        return resulting_address;
    }

    pub fn standard_allocate(&mut self, byte_count: u64, flags: RegionFlags) -> u64
    {
        self.standard_allocate_extended(byte_count, flags, 0, true)
    }

    pub fn reserve_extended(&mut self, byte_count: u64, flags: RegionFlags, forced_address: u64, generate_guard_pages: bool) -> *mut Region
    {
        unimplemented!()
    }

    pub fn reserve(&mut self, byte_count: u64, flags: RegionFlags) -> *mut Region
    {
        self.reserve_extended(byte_count, flags, 0, false)
    }

    pub fn unreserve_extended(&mut self, region_to_remove: &mut Region, unmap_pages: bool, guard_region: bool)
    {
        unimplemented!()
    }

    pub fn unreserve(&mut self, region_to_remove: &mut Region, unmap_pages: bool)
    {
        self.unreserve_extended(region_to_remove, unmap_pages, false)
    }

    pub fn commit_range(&mut self, region: &mut Region, page_offset: u64, page_count: u64) -> bool
    {
        self.reserve_mutex.assert_locked();

        if region.flags.contains(RegionFlags::no_commit_tracking)
        {
            panic("region does not support commit tracking\n");
        }

        if page_offset >= region.page_count || page_count > region.page_count - page_offset
        {
            panic("invalid region offset and page count\n");
        }

        if !region.flags.contains(RegionFlags::normal)
        {
            panic("cannot commit into non normal region\n");
        }

        unimplemented!()
    }
}

pub struct Region
{
    base_address: u64,
    page_count: u64,
    flags: RegionFlags,
    used: bool,
}

bitflags!
{
    pub struct MapPageFlags: u32
    {
        const not_cacheable = 1 << 0;
        const user = 1 << 1;
        const overwrite = 1 << 2;
        const commit_tables_now = 1 << 3;
        const read_only = 1 << 4;
        const copied = 1 << 5;
        const no_new_tables = 1 << 6;
        const frame_lock_acquired = 1 << 7;
        const write_combining = 1 << 8;
        const ignore_if_mapped = 1 << 9;
    }

    pub struct RegionFlags: u32
    {
        const fixed = 1 << 0;
        const not_cacheable = 1 << 1;
        const no_commit_tracking = 1 << 2;
        const read_only = 1 << 3;
        const copy_on_write = 1 << 4;
        const write_combining = 1 << 5;
        const executable = 1 << 6;
        const user = 1 << 7;
        const physical = 1 << 8;
        const normal = 1 << 9;
        const shared = 1 << 10;
        const guard = 1 << 11;
        const cache = 1 << 12;
        const file = 1 << 13;
    }
}


pub mod Physical
{
    use kernel::*;

    pub const critical_available_page_count_threshold: u64 = 1048576 / page_size;
    pub const critical_remaining_commit_threshold: u64 = critical_available_page_count_threshold;

#[repr(C, align(0x1000))]
    struct EarlyZeroBuffer
    {
        memory: [u8; page_size as usize],
    }
    static mut early_zero_buffer: EarlyZeroBuffer = EarlyZeroBuffer { memory: [0;page_size as usize] };

    pub enum PageFrameState
    {
        unusable,
        bad,
        zeroed,
        free,
        standby,
        active,
    }

    pub struct PageFrameUnionList
    {
        pub next: Volatile<u64>,
        pub previous: VolatilePointer<u64>,
    }

    pub struct PageFrameUnionActive
    {
        references: Volatile<u64>,
    }

    pub union PageFrameUnion
    {
        pub list: PageFrameUnionList,
        pub active: PageFrameUnionActive,
    }

    pub struct PageFrame
    {
        state: Volatile<PageFrameState>,
        flags: Volatile<u8>,
        cache_reference: VolatilePointer<u64>,
        union: PageFrameUnion,
    }

    pub struct Allocator<'a>
    {
        pub pageframes: &'a mut [PageFrame],
        pub commit_mutex: Mutex,
        pub pageframe_mutex: Mutex,

        pub free_or_zeroed_page_bitset: Bitset<'a>,

        pub first_free_page: u64,
        pub first_zeroed_page: u64,
        pub first_standby_page: u64,
        pub last_standby_page: u64,

        pub zeroed_page_count: u64,
        pub free_page_count: u64,
        pub standby_page_count: u64,
        pub active_page_count: u64,

        pub commit_fixed: i64,
        pub commit_pageable: i64,
        pub commit_fixed_limit: i64,
        pub commit_limit: i64,

        pub approximate_total_object_cache_byte_count: u64,
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
                self.pageframe_mutex.acquire();
            }
            scopeguard::defer! (
                if !mutex_already_acquired
                {
                    self.pageframe_mutex.release()
                }
            );

            let commit_now = 
            {
                if flags.contains(Flags::commit_now)
                {
                    let bytes_to_commit_now = count * page_size;
                    if !self.commit(bytes_to_commit_now, true)
                    {
                        if !mutex_already_acquired
                        {
                            self.pageframe_mutex.release()
                        }

                        return 0
                    }
                    bytes_to_commit_now
                }
                else
                {
                    0
                }
            };

            let simple = count == 1 && alignment == 1 && below == 0;

            if self.pageframes.len() == 0
            {
                if !simple { panic("non-simple allocation before initializing the pageframe database\n") }

                let page = arch::early_allocate_page();

                if flags.contains(Flags::zeroed)
                {
                    let _ = arch::map_page(unsafe { &mut kernel.core.address_space }, page, unsafe { (&mut early_zero_buffer) as *mut _ } as u64, memory::MapPageFlags::overwrite | memory::MapPageFlags::no_new_tables | memory::MapPageFlags::frame_lock_acquired);
                    unsafe { early_zero_buffer.memory.fill(0) };
                }

                if !mutex_already_acquired
                {
                    self.pageframe_mutex.release()
                }
                return page;
            }
            else if !simple
            {
                // Slow path. // TODO: standby pages
                let pages = self.free_or_zeroed_page_bitset.get(count, alignment, below);
                if pages == u64::MAX
                {
                    // @TODO: fail and put defers properly
                    unimplemented!()
                }
                self.activate_pages(pages, count);
                let address = pages << page_bit_count;
                if flags.contains(Flags::zeroed) { unimplemented!() }
                return address;
            }
            else
            {
                let mut page = 0;
                let mut not_zeroed = false;

                if page == 0 { page = self.first_zeroed_page }
                if page == 0 { page = self.first_free_page; not_zeroed = true; }
                if page == 0 { page = self.last_standby_page; not_zeroed = true; }
                if page == 0
                {
                    // @TODO: fail and put defers properly
                    unimplemented!()
                }

                let frame = &mut self.pageframes[page as usize];
                match frame.state.read_volatile()
                {
                    PageFrameState::active =>
                    {
                        panic("corrupt pageframe database\n")
                    }
                    PageFrameState::standby =>
                    {
                        if frame.cache_reference.deref_volatile() != ((page << page_bit_count) | super::shared_entry_present)
                        {
                            panic("corrupt shared reference back pointer in frame\n");
                        }

                        frame.cache_reference.write_volatile(0);
                    }
                    _ =>
                    {
                        self.free_or_zeroed_page_bitset.take(page);
                    }
                }

                self.activate_pages(page, 1);
                let address = page << page_bit_count;
                if not_zeroed && flags.contains(Flags::zeroed)
                {
                    unimplemented!()
                }
                return address;
            }
            // @TODO: implement defer and fail
            unimplemented!()
        }

        pub fn allocate_with_flags(&mut self, flags: Flags) -> u64
        {
            self.allocate_extended(flags, 1, 1, 0)
        }

        pub fn activate_pages(&mut self, pages: u64, count: u64)
        {
            unimplemented!()
        }

        fn get_available_page_count(&self) -> u64
        {
            return self.zeroed_page_count + self.free_page_count + self.standby_page_count;
        }

        fn get_remaining_commit(&self) -> i64
        {
            return self.commit_limit - self.commit_pageable - self.commit_fixed;
        }

        fn should_trim_object_cache(&self) -> bool
        {
            return (self.approximate_total_object_cache_byte_count / page_size) as i64 > self.get_maximum_page_count_object_cache();
        }

        fn get_maximum_page_count_object_cache(&self) -> i64
        {
            return self.commit_limit - self.get_non_cache_memory_page_count();
        }

        fn get_non_cache_memory_page_count(&self) -> i64
        {
            return self.commit_fixed + self.commit_pageable - (self.approximate_total_object_cache_byte_count / page_size) as i64;
        }

        pub fn commit(&mut self, byte_count: u64, fixed: bool) -> bool
        {
            if (byte_count & (page_size - 1)) != 0
            {
                panic("bytes to be commited must be page-aligned\n");
            }

            self.commit_mutex.acquire();
            ::defer!(
                self.commit_mutex.release()
            );

            let needed_page_count = (byte_count / page_size) as i64;

            if self.commit_limit != 0
            {
                if fixed
                {
                    if needed_page_count > self.commit_fixed_limit - self.commit_fixed
                    {
                        return false;
                    }

                    if self.get_available_page_count() as i64 - needed_page_count < critical_available_page_count_threshold as i64 && unsafe { arch::get_current_thread().as_mut().unwrap().is_page_generator }
                    {
                        return false;
                    }

                    self.commit_fixed += needed_page_count;
                }
                else
                {
                    if needed_page_count > (self.get_remaining_commit() -
                        {
                            if unsafe { arch::get_current_thread().as_mut().unwrap().is_page_generator }
                            {
                                0 as i64
                            }
                            else
                            {
                                critical_remaining_commit_threshold as i64
                            }
                        })
                    {
                        return false;
                    }

                    self.commit_pageable += needed_page_count;
                }

                if self.should_trim_object_cache()
                {
                }

                unimplemented!();
            }
            // else -> We haven't started tracking commit counts yet

            true
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
        self.core.regions[0].page_count = arch::core_address_space_size / page_size as u64;
        arch::Memory::init(self);
    }
}
