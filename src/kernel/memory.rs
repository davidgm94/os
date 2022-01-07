use core::mem::transmute_copy;

use kernel::*;

use super::arch::{kernel_address_space_start, kernel_address_space_size};

pub struct AddressSpace<'a>
{
    pub reserve_mutex: Mutex,
    pub arch: arch::Memory::AddressSpace<'a>,
    pub reference_count: u64,
}

impl<'a> const Default for AddressSpace<'a>
{
    fn default() -> Self {
        Self
        {
            reserve_mutex: Mutex::default(),
            arch: arch::Memory::AddressSpace
            {
                cr3: 0,

                L1_commit: &mut[],
                L1_commit_commit: [0; arch::Memory::L1_commit_commit_size],
                L2_commit: [0; arch::Memory::L2_commit_size],
                L3_commit: [0; arch::Memory::L3_commit_size],

                commited_page_table_count: 0,
                active_page_table_count: 0,

                mutex: Mutex::default(),
            },
            reference_count: 0,
        }
    }
}

// @TODO: properly formalize this
pub const shared_entry_present: u64 = 1;

impl<'a> AddressSpace<'a>
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
    pub base_address: u64,
    pub page_count: u64,
    pub flags: RegionFlags,
    pub used: bool,
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

#[repr(C)]
pub union HeapRegionFirstUnion
{
    next: u16,
    size: u16,
}

#[repr(C)]
pub union HeapRegionSecondUnion
{
    allocation_size: u64,
    region_list_next: *mut HeapRegion,
}

#[repr(C)]
pub struct HeapRegion
{
    u1: HeapRegionFirstUnion,
    previous: u16,
    offset: u16,
    used: u16,
    u2: HeapRegionSecondUnion,
    region_list_reference: *mut *mut HeapRegion,
}

impl HeapRegion
{
    fn get_address(&self) -> u64
    {
        (self as *const Self) as u64
    }
    fn get_header(&self) -> *mut Self
    {
       (self.get_address() - used_heap_region_header_size as u64) as *mut Self
    }

    fn get_data(&self) -> u64
    {
        self.get_address() + used_heap_region_header_size as u64
    }

    fn get_next(&self) -> *mut HeapRegion
    {
        (self.get_address() + unsafe { self.u1.next } as u64) as *mut Self
    }

    fn get_previous(&self) -> *mut HeapRegion
    {
        if self.previous != 0
        {
            return (self.get_address() - self.previous as u64) as *mut Self
        }

        null_mut()
    }
}
#[repr(C)]
pub struct Heap
{
    mutex: Mutex,

    regions: [*mut HeapRegion; 12],
    allocation_count: Volatile<u64>,
    size: Volatile<u64>,
    block_count: Volatile<u64>,
    blocks: [*mut HeapRegion; 16],
    cannot_validate: bool,
}

pub const used_heap_region_header_size: usize = size_of::<HeapRegion>() - size_of::<*mut *mut HeapRegion>();
pub const free_heap_region_header_size: usize = size_of::<HeapRegion>();
pub const large_allocation_threshold: u64 = 32768;
pub const used_heap_region_magic: u16 = 0xabcd;

impl const Default for Heap
{
    fn default() -> Self {
        Self { mutex: Mutex::default(), regions: [null_mut(); 12], allocation_count: Volatile::new(0), size: Volatile::new(0), block_count: Volatile::new(0), blocks: [null_mut(); 16], cannot_validate: false }
    }
}

impl Heap
{
    pub fn allocate(&mut self, asked_size: u64, zero_memory: bool) -> u64
    {
        if asked_size == 0 { return 0 }
        
        if unsafe { transmute_copy::<u64, i64>(&asked_size) } < 0
        {
            panic("heap panic\n");
        }

        let mut size = asked_size;
        size += used_heap_region_header_size as u64;
        size = (size + 0x1f) & !0x1f;

        if size >= large_allocation_threshold
        {
            if let Some(region) = unsafe { (self.allocate_call(size) as *mut HeapRegion).as_mut() }
            {
                region.used = used_heap_region_magic;
                region.u1.size = 0;
                region.u2.allocation_size = asked_size;
                unsafe { transmute::<&mut u64, AtomicU64>(&mut self.size.value).fetch_add(asked_size, Ordering::SeqCst) };

                return region.get_data();
            }
            else
            {
                return 0;
            }
        }

        self.mutex.acquire();

        self.validate();

        unimplemented!();
    }

    fn validate(&self)
    {
        if self.cannot_validate { return }

        let block_count = self.block_count.read_volatile() as usize;
        assert!(block_count <= self.blocks.len());

        for &block in self.blocks[0..block_count].iter()
        {
            if let Some(start) = unsafe { block.as_ref() }
            {
                let end = (block as u64 + 65536) as *mut HeapRegion;
                let mut previous: *const HeapRegion = null_mut();
                let mut region = start;

                while (region as *const HeapRegion) < end
                {
                    if let Some(_) = unsafe { previous.as_ref() }
                    {
                        if previous != region.get_previous()
                        {
                            panic("heap panic\n");
                        }
                    }
                    else if region.previous != 0
                    {
                        panic("heap panic\n");
                    }

                    if unsafe { region.u1.size & 31 != 0 } { panic("heap panic\n") }

                    if (region.get_address() - (start as *const _) as u64) as u16 != region.offset
                    {
                        panic("heap panic\n");
                    }

                    if region.used != used_heap_region_magic && region.used != 0
                    {
                        panic("heap panic\n");
                    }

                    if region.used == 0 && unsafe { region.u2.region_list_next.is_null() }
                    {
                        panic("heap panic\n");
                    }

                    if region.used == 0 && unsafe { !region.u2.region_list_next.is_null() } && unsafe { region.u2.region_list_next.as_ref().unwrap().region_list_reference as u64 } != ((unsafe { &region.u2.region_list_next }) as *const _) as u64
                    {
                        panic("heap panic\n");
                    }

                    previous = &*region;
                    region = unsafe { region.get_next().as_mut().unwrap() };
                }

                if region as *const _ != end
                {
                    panic("heap panic\n");
                }
            }
        }
    }

    #[inline(always)]
    fn allocate_call(&mut self, size: u64) -> u64
    {
        if self as *mut Self == unsafe { (&mut kernel.core.heap) as *mut Self }
        {
            unsafe { kernel.core.address_space.standard_allocate(size, RegionFlags::fixed) }
        }
        else
        {
            unsafe { kernel.process.address_space.standard_allocate(size, RegionFlags::fixed) }
        }
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

    #[derive(PartialEq)]
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
        pub state: Volatile<PageFrameState>,
        pub flags: Volatile<u8>,
        pub cache_reference: VolatilePointer<u64>,
        pub union: PageFrameUnion,
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
            let mut failed = false;
            let mut result: u64 = 0;

            let simple = count == 1 && alignment == 1 && below == 0;

            if self.pageframes.is_empty()
            {
                if !simple { panic("non-simple allocation before initializing the pageframe database\n") }

                let page = arch::early_allocate_page();

                if flags.contains(Flags::zeroed)
                {
                    let _ = arch::map_page(unsafe { &mut kernel.core.address_space }, page, unsafe { (&mut early_zero_buffer) as *mut _ } as u64, memory::MapPageFlags::overwrite | memory::MapPageFlags::no_new_tables | memory::MapPageFlags::frame_lock_acquired);
                    unsafe { early_zero_buffer.memory.fill(0) };
                }

                result = page;
            }
            else if !simple
            {
                // Slow path.
                // TODO: standby pages
                let pages = self.free_or_zeroed_page_bitset.get(count, alignment, below);
                let failed = pages == u64::MAX;
                if !failed
                {
                    self.activate_pages(pages, count);
                    let address = pages << page_bit_count;
                    if flags.contains(Flags::zeroed) { unimplemented!() }
                    result = address;
                }
            }
            else
            {
                let mut page = 0;
                let mut not_zeroed = false;

                if page == 0 { page = self.first_zeroed_page }
                if page == 0 { page = self.first_free_page; not_zeroed = true; }
                if page == 0 { page = self.last_standby_page; not_zeroed = true; }
                failed = page == 0;

                if !failed
                {
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

                            frame.cache_reference.write_volatile_at_address(0);
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
                    result = address;
                }
            }

            if failed
            {
                if flags.contains(Flags::can_fail)
                {
                    panic("physical page allocation failed: out of memory\n");
                }
                self.decommit(commit_now, true);
                result = 0;
            }
            if !mutex_already_acquired
            {
                self.pageframe_mutex.release()
            }
            result
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
            self.zeroed_page_count + self.free_page_count + self.standby_page_count
        }

        fn get_remaining_commit(&self) -> i64
        {
            self.commit_limit - self.commit_pageable - self.commit_fixed
        }

        fn should_trim_object_cache(&self) -> bool
        {
            (self.approximate_total_object_cache_byte_count / page_size) as i64 > self.get_maximum_page_count_object_cache()
        }

        fn get_maximum_page_count_object_cache(&self) -> i64
        {
            self.commit_limit - self.get_non_cache_memory_page_count()
        }

        fn get_non_cache_memory_page_count(&self) -> i64
        {
            self.commit_fixed + self.commit_pageable - (self.approximate_total_object_cache_byte_count / page_size) as i64
        }

        pub fn commit(&mut self, byte_count: u64, fixed: bool) -> bool
        {
            if (byte_count & (page_size - 1)) != 0
            {
                panic("bytes to be commited must be page-aligned\n");
            }

            self.commit_mutex.acquire();
            let mut succedeed = true;

            let needed_page_count = (byte_count / page_size) as i64;

            if self.commit_limit != 0
            {
                if fixed
                {
                    let failed = (needed_page_count > self.commit_fixed_limit - self.commit_fixed) || (self.get_available_page_count() as i64 - needed_page_count < critical_available_page_count_threshold as i64 && unsafe { arch::get_current_thread().as_mut().unwrap().is_page_generator }); 
                    succedeed = !failed;

                    if succedeed
                    {
                        self.commit_fixed += needed_page_count;
                    }
                }
                else
                {
                    succedeed = !(needed_page_count > (self.get_remaining_commit() -
                        {
                            if unsafe { arch::get_current_thread().as_mut().unwrap().is_page_generator }
                            {
                                0 as i64
                            }
                            else
                            {
                                critical_remaining_commit_threshold as i64
                            }
                        }));

                    if succedeed
                    {
                        self.commit_pageable += needed_page_count;
                    }
                }

                if succedeed
                {
                    if self.should_trim_object_cache()
                    {
                        unimplemented!();
                    }

                    unimplemented!();
                }
            }
            // else -> We haven't started tracking commit counts yet

            // @TODO: log either if succedeed or failed

            self.commit_mutex.release();
            succedeed
        }

        fn decommit(&self, bytes_to_decomit: u64, fixed: bool)
        {
            todo!()
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

        let region = unsafe { (self.core.heap.allocate(size_of::<Region>() as u64, true) as *mut Region).as_mut().unwrap() };
        region.base_address = kernel_address_space_start;
        region.page_count = kernel_address_space_size / page_size;
    }
}
