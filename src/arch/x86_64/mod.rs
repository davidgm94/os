use panic;
use scheduler::Thread;
use arch;
use memory;
use Kernel;
use bitflags::bitflags;
use synchronization::Mutex;
use kernel;

pub const PAGE_SIZE: u64 = 0x1000;
/// Bytes occupied by page size
pub const PAGE_BIT_COUNT: u64 = 12;
pub const ENTRY_PER_PAGE_TABLE_COUNT: u64 = 512;
pub const ENTRY_PER_PAGE_TABLE_BIT_COUNT: u64 = 9;

const CORE_REGIONS_START: u64 = 0xFFFF8001F0000000;
const CORE_REGIONS_COUNT: u64 = (0xFFFF800200000000 - 0xFFFF8001F0000000) / core::mem::size_of::<crate::memory::Region>() as u64;
const KERNEL_SPACE_START: u64 = 0xFFFF900000000000;
const KERNEL_SPACE_SIZE: u64 = 0xFFFFF00000000000 - 0xFFFF900000000000;
const MODULES_START: u64 = 0xFFFFFFFF90000000;
const MODULES_SIZE: u64 = 0xFFFFFFFFC0000000 - 0xFFFFFFFF90000000;
const CORE_SPACE_START: u64 = 0xFFFF800100000000;
const CORE_SPACE_SIZE: u64 = 0xFFFF8001F0000000 - 0xFFFF800100000000;
const USER_SPACE_START: u64 = 0x100000000000;
const USER_SPACE_SIZE: u64 = 0xF00000000000 - 0x100000000000;
const LOW_MEMORY_MAP_START: u64 = 0xFFFFFE0000000000;
const LOW_MEMORY_LIMIT: u64 = 0x100000000; // The first 4GB is mapped here.

pub struct InterruptContext
{
}

#[repr(C)]
pub struct CPULocalStorage
{
    pub current_thread: Option<u64>,
    pub idle_thread: Option<u64>,
    pub async_task_thread: Option<u64>,
    pub panic_context: InterruptContext,
    pub irq_switch_thread: bool,
    pub scheduler_ready: bool,
    pub in_IRQ: bool,
    pub in_async_task: bool,
    pub processor_ID: u32,
    pub spinlock_count: u64,
    pub cpu: arch::CPU,
    // async_task_list
}

const L1_COMMIT_SIZE: usize = 1 << 23;
const L1_COMMIT_COMMIT_SIZE: usize = 1 << 8;
const L2_COMMIT_SIZE: usize = 1 << 14;
const L3_COMMIT_SIZE: usize = 1 << 5;

pub struct AddressSpace
{
    cr3: u64,
    L1_commit: *mut u8,
    L1_commit_commit: [u8; L1_COMMIT_COMMIT_SIZE],
    L2_commit: [u8; L2_COMMIT_SIZE],
    L3_commit: [u8; L3_COMMIT_SIZE],

    commited_page_table_count: u64,
    active_page_table_count: u64,
    mutex: Mutex,
}

impl AddressSpace
{
    pub const fn zeroed() -> Self
    {
        return Self
        {
            cr3: 0,
            L1_commit: 0 as *mut u8,
            L1_commit_commit: [0;L1_COMMIT_COMMIT_SIZE],
            L2_commit: [0; L2_COMMIT_SIZE],
            L3_commit: [0; L3_COMMIT_SIZE],

            commited_page_table_count: 0,
            active_page_table_count: 0,
            mutex: Mutex::zeroed(),
        };
    }
}

//impl Default for AddressSpace
//{
    //#[default_method_body_is_const] 
    //fn default() -> Self
    //{
        //return Self
        //{
            //cr3: 0
        //}
    //}
//}

const PAGE_TABLE_L4_ADDRESS: u64 = 0xFFFFFF7FBFDFE000;
const PAGE_TABLE_L3_ADDRESS: u64 = 0xFFFFFF7FBFC00000;
const PAGE_TABLE_L2_ADDRESS: u64 = 0xFFFFFF7F80000000;
const PAGE_TABLE_L1_ADDRESS: u64 = 0xFFFFFF0000000000;

#[derive(Clone, Copy)]
enum PageTableLevel
{
    level_1 = 0,
    level_2 = 1,
    level_3 = 2,
    level_4 = 3,
}

pub struct PageTable
{
}

impl PageTable
{
    const fn access(level: PageTableLevel, offset: u64) -> *mut u64
    {
        let base_address = match level
        {
            PageTableLevel::level_1 => PAGE_TABLE_L1_ADDRESS,
            PageTableLevel::level_2 => PAGE_TABLE_L2_ADDRESS,
            PageTableLevel::level_3 => PAGE_TABLE_L3_ADDRESS,
            PageTableLevel::level_4 => PAGE_TABLE_L4_ADDRESS,
        } as *mut u64;
        unsafe { base_address.add(offset as usize) }
    }

    fn read(level: PageTableLevel, offset: u64) -> u64
    {
        unsafe { PageTable::access(level, offset).read_volatile() }
    }

    fn write(level: PageTableLevel, offset: u64, value: u64)
    {
        unsafe { PageTable::access(level, offset).write_volatile(value) }
    }
}

#[repr(C)]
struct PhysicalMemoryRegion
{
    base_address: u64,
    page_count: u64,
}


extern "C"
{
    static mut physicalMemoryRegions: *mut PhysicalMemoryRegion;
    static mut physicalMemoryRegionsCount: u64;
    static mut physicalMemoryRegionsPagesCount: u64;
    static mut physicalMemoryOriginalPagesCount: u64;
    static mut physicalMemoryRegionsIndex: u64;
    static mut physicalMemoryHighest: u64;
}

pub fn early_allocate_page() -> u64
{
    let physical_memory_region_slice = unsafe { core::slice::from_raw_parts_mut(physicalMemoryRegions, physicalMemoryRegionsCount as usize) };

    for (region_i, region) in physical_memory_region_slice.iter_mut().enumerate()
    {
        if region.page_count == 0
        {
            let result = region.base_address;

            region.base_address += PAGE_SIZE;
            region.page_count -= 1;

            unsafe
            {
                physicalMemoryRegionsCount -= 1;
                physicalMemoryRegionsIndex = region_i as u64;
            }

            return result;
        }
    }

    panic();
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
}

const PAGE_TABLE_LEVEL_COUNT: usize = 4;
type PageTableIndices = [u64; PAGE_TABLE_LEVEL_COUNT];

fn compute_page_table_indices(virtual_address: u64) -> PageTableIndices
{
    let mut indices: PageTableIndices = [0;4];
    indices[PageTableLevel::level_1 as usize] = virtual_address >> PAGE_BIT_COUNT;
    indices[PageTableLevel::level_2 as usize] = virtual_address >> (PAGE_BIT_COUNT + ENTRY_PER_PAGE_TABLE_BIT_COUNT * PageTableLevel::level_2 as u64);
    indices[PageTableLevel::level_3 as usize] = virtual_address >> (PAGE_BIT_COUNT + ENTRY_PER_PAGE_TABLE_BIT_COUNT * PageTableLevel::level_3 as u64);
    indices[PageTableLevel::level_4 as usize] = virtual_address >> (PAGE_BIT_COUNT + ENTRY_PER_PAGE_TABLE_BIT_COUNT * PageTableLevel::level_4 as u64);
    return indices;
}

pub fn map_page(physical_allocator: &mut memory::PhysicalAllocator, address_space: &mut memory::AddressSpace, asked_physical_address: u64, asked_virtual_address: u64, flags: MapPageFlags) -> bool
{
    let address_space_address = (address_space as *mut _) as u64;
    if (asked_physical_address | asked_virtual_address) & (PAGE_SIZE - 1) != 0
    {
        panic();
    }

    let page_index = asked_physical_address as usize >> PAGE_BIT_COUNT;
    if physical_allocator.page_frame_database_initialized && page_index < physical_allocator.page_frames.len()
    {
        let frame_state = physical_allocator.page_frames[page_index].state.read();
        match frame_state
        {
            memory::PageFrameState::active(_) | memory::PageFrameState::unusable(_) => {}
            _ => panic()
        }
    }

    if asked_physical_address == 0 { panic() }
    if asked_virtual_address == 0 { panic() }

    if asked_virtual_address < 0xFFFF800000000000 && unsafe { ProcessorReadCR3() } != address_space.arch.cr3 { panic() }
    
    let acquire_frame_lock = !flags.contains(MapPageFlags::no_new_tables | MapPageFlags::frame_lock_acquired);
    if acquire_frame_lock { physical_allocator.page_frame_mutex.acquire(); }

    let acquire_space_lock = flags.complement().contains(MapPageFlags::no_new_tables);
    if acquire_space_lock { address_space.arch.mutex.acquire(); }

    let physical_address = asked_physical_address & 0xFFFFFFFFFFFFF000;
    let virtual_address = asked_virtual_address & 0x0000FFFFFFFFF000;

    let indices = compute_page_table_indices(virtual_address);

    if address_space_address != unsafe { (&mut kernel.core_address_space as *mut _) as u64} && address_space_address != unsafe { (&mut kernel.process.address_space as *mut _) as u64 }
    {

        {
            let index = indices[PageTableLevel::level_4 as usize] as usize;
            if (address_space.arch.L3_commit[index >> 3] & (1 << (index & 0b111))) == 0
            {
                panic();
            }
        }
        {
            let index = indices[PageTableLevel::level_3 as usize] as usize;
            if (address_space.arch.L2_commit[index >> 3] & (1 << (index & 0b111))) == 0
            {
                panic();
            }
        }
        {
            let index = indices[PageTableLevel::level_2 as usize] as usize;
            let l1_commit: &[u8] = unsafe { core::slice::from_raw_parts_mut(address_space.arch.L1_commit, L1_COMMIT_SIZE) };
            if (l1_commit[index >> 3] & (1 << (index & 0b111))) == 0
            {
                panic();
            }
        }
    }

    {
        let level = PageTableLevel::level_4;
        let index = indices[level as usize];
        let preceding_level = PageTableLevel::level_3;
        let preceding_index = indices[preceding_level as usize];

        if PageTable::read(level, index) & 1 == 0
        {
            if flags.contains(MapPageFlags::no_new_tables) { panic() }

            let physical = unsafe { kernel.physical_allocator.allocate_one_page(memory::PhysicalAllocationFlags::lock_acquired) };
            PageTable::write(level, index, physical);
            let page_to_invalidate = PageTable::access(preceding_level, preceding_index) as u64;
            unsafe { ProcessorInvalidatePage(page_to_invalidate) };
            let page_to_zero_out = unsafe { core::slice::from_raw_parts_mut((page_to_invalidate & !(PAGE_SIZE - 1)) as *mut u8, PAGE_SIZE as usize) };
            page_to_zero_out.fill(0);
            address_space.arch.active_page_table_count += 1;
        }
    }

    {
        let level = PageTableLevel::level_3;
        let index = indices[level as usize];
        let preceding_level = PageTableLevel::level_2;
        let preceding_index = indices[preceding_level as usize];

        if PageTable::read(level, index) & 1 == 0
        {
            if flags.contains(MapPageFlags::no_new_tables) { panic() }

            let physical = unsafe { kernel.physical_allocator.allocate_one_page(memory::PhysicalAllocationFlags::lock_acquired) };
            PageTable::write(level, index, physical);
            let page_to_invalidate = PageTable::access(preceding_level, preceding_index) as u64;
            unsafe { ProcessorInvalidatePage(page_to_invalidate) };
            let page_to_zero_out = unsafe { core::slice::from_raw_parts_mut((page_to_invalidate & !(PAGE_SIZE - 1)) as *mut u8, PAGE_SIZE as usize) };
            page_to_zero_out.fill(0);
            address_space.arch.active_page_table_count += 1;
        }
    }

    {
        let level = PageTableLevel::level_2;
        let index = indices[level as usize];
        let preceding_level = PageTableLevel::level_1;
        let preceding_index = indices[preceding_level as usize];

        if PageTable::read(level, index) & 1 == 0
        {
            if flags.contains(MapPageFlags::no_new_tables) { panic() }

            let physical = unsafe { kernel.physical_allocator.allocate_one_page(memory::PhysicalAllocationFlags::lock_acquired) };
            PageTable::write(level, index, physical);
            let page_to_invalidate = PageTable::access(preceding_level, preceding_index) as u64;
            unsafe { ProcessorInvalidatePage(page_to_invalidate) };
            let page_to_zero_out = unsafe { core::slice::from_raw_parts_mut((page_to_invalidate & !(PAGE_SIZE - 1)) as *mut u8, PAGE_SIZE as usize) };
            page_to_zero_out.fill(0);
            address_space.arch.active_page_table_count += 1;
        }
    }

    let old_value = PageTable::access(PageTableLevel::level_1, indices[PageTableLevel::level_1 as usize]) as u64;
    let mut value = physical_address | 3;

    if flags.contains(MapPageFlags::write_combining) { value |= 16 }
    if flags.contains(MapPageFlags::not_cacheable) { value |= 24 }

    if flags.contains(MapPageFlags::user) { value |= 7 }
    else { value |= 1 << 8 }

    if flags.contains(MapPageFlags::read_only) { value &= !2 }
    if flags.contains(MapPageFlags::copied) { value |= 1 << 9 }

    value |= (1 << 5) | (1 << 6);

    // @TODO: assert this is only return value possible
    let mut result = true;
    if old_value & 1 != 0 && !flags.contains(MapPageFlags::overwrite)
    {
        if flags.contains(MapPageFlags::ignore_if_mapped) { result = false }
        else
        {
            if old_value & !(PAGE_SIZE - 1) != physical_address { panic() }

            if old_value == value { panic() }

            if !(old_value & 2 == 0 && value & 2 != 0) { panic() }
        }
    }

    PageTable::write(PageTableLevel::level_1, indices[PageTableLevel::level_1 as usize], value);
    unsafe { ProcessorInvalidatePage(asked_virtual_address) };

    if acquire_frame_lock { physical_allocator.page_frame_mutex.release() }
    if acquire_space_lock { address_space.arch.mutex.release() }

    return result;
}

pub struct Memory
{
}

impl Memory
{
    pub fn init(g_kernel: &mut Kernel)
    {
        unsafe
        {
            let cr3 = ProcessorReadCR3();
            g_kernel.core_address_space.arch.cr3 = cr3;
            g_kernel.process.address_space.arch.cr3 = cr3;
            g_kernel.core_regions[0].base_address = CORE_SPACE_START;
            g_kernel.core_regions[0].page_count = CORE_SPACE_SIZE / PAGE_SIZE;
        }

        for page_i in 0x100..0x200
        {
            if PageTable::read(PageTableLevel::level_4, page_i) == 0
            {
                let allocated_page = g_kernel.physical_allocator.allocate_one_page(memory::PhysicalAllocationFlags::empty());
                PageTable::write(PageTableLevel::level_4, page_i, allocated_page | 3);
                let page_to_zero = PageTable::access(PageTableLevel::level_3, page_i * 0x200);
                let page_to_zero_bytes = unsafe { core::slice::from_raw_parts_mut(core::mem::transmute::<*mut u64, *mut u8>(page_to_zero), PAGE_SIZE as usize) };
                page_to_zero_bytes.fill(0);
            }
        }

        unimplemented!();
    }
}

extern "C"
{
    fn ProcessorReadCR3() -> u64;

    pub fn GetCurrentThread() -> *mut Thread;
    pub fn ProcessorAreInterruptsEnabled() -> bool;
    pub fn ProcessorEnableInterrupts();
    pub fn ProcessorDisableInterrupts();
    pub fn GetLocalStorage() -> *mut CPULocalStorage;
    pub fn ProcessorFakeTimerInterrupt();
    pub fn ProcessorInvalidatePage(virtual_address: u64);
}
