use {Volatile, panic};
use defer;
use arch;
use bitflags::bitflags;
use synchronization::Mutex;
use kernel;

pub struct Core
{
    pub used: bool,
}

pub union CoreNonCore
{
    pub core: Core,
}

impl CoreNonCore
{
    pub const fn zeroed() -> Self
    {
        Self
        {
            core: Core
            {
                used: false
            }
        }
    }
}

// @TODO: separate core regions from the rest. Tagged union for the region types
pub struct Region
{
    pub base_address: u64,
    pub page_count: u64,
    pub flags: u32,
    pub cnc: CoreNonCore,
}

pub struct AddressSpace
{
    pub arch: arch::AddressSpace,
    pub reference_count: Volatile<u32>
}

impl AddressSpace
{
    pub const fn default() -> Self
    {
        Self
        {
            arch: arch::AddressSpace::zeroed(),
            reference_count: Volatile::<u32> { value: 1 }
        }
    }
}

pub struct PageFrameActive
{
    pub references: u64,
}

pub struct PageFrameElse
{
    pub previous: u64,
    pub next: u64,
}

pub enum PageFrameState
{
    unusable(PageFrameElse),
    bad(PageFrameElse),
    zeroed(PageFrameElse),
    free(PageFrameElse),
    standby(PageFrameElse),
    active(PageFrameActive),
}

impl PartialEq for PageFrameState
{
    fn eq(&self, other: &Self) -> bool {
        match (self, other) {
            (Self::unusable(_), Self::unusable(_)) => true,
            (Self::bad(_), Self::bad(_)) => true,
            (Self::zeroed(_), Self::zeroed(_)) => true,
            (Self::free(_), Self::free(_)) => true,
            (Self::standby(_), Self::standby(_)) => true,
            (Self::active(_), Self::active(_)) => true,
            _ => false,
        }
    }
}

pub struct PageFrame
{
    pub state: Volatile<PageFrameState>,
    pub flags: Volatile<u8>,
}

bitflags!
{
    pub struct PhysicalAllocationFlags: u32
    {
        const can_fail = 1 << 0;
        const commit_now = 1 << 1;
        const zeroed = 1 << 2;
        const lock_acquired = 1 << 3;
    }
}

// @TODO: make this platform indepedent
#[repr(align(0x1000))]
pub struct EarlyZeroBufferType
{
    data: [u8; arch::PAGE_SIZE as usize]
}

static mut early_zero_buffer: EarlyZeroBufferType = EarlyZeroBufferType
{
    data: [0; arch::PAGE_SIZE as usize]
};


pub struct PhysicalAllocator<'a>
{
    pub page_frames: &'a mut[PageFrame],
    pub page_frame_mutex: Mutex,
    pub page_frame_database_initialized: bool,
}

impl<'a> PhysicalAllocator<'a>
{
    pub fn allocate_one_page(&mut self, flags: PhysicalAllocationFlags) -> u64
    {
        return self.allocate_extended(flags, 1, 1, 0);
    }

    pub fn allocate_extended(&mut self, flags: PhysicalAllocationFlags, page_count: u64, alignment_in_pages: u64, below: u64) -> u64
    {
        let mutex_already_acquired = flags.contains(PhysicalAllocationFlags::can_fail);
        if !mutex_already_acquired
        {
            unsafe { kernel.physical_allocator.page_frame_mutex.acquire() };
        }
        else
        {
            unsafe { kernel.physical_allocator.page_frame_mutex.assert_locked() };
        }
        defer!(unsafe { kernel.physical_allocator.page_frame_mutex.release() });

        let commit_now = 
        {
            if flags.contains(PhysicalAllocationFlags::commit_now)
            {
                let commit_now = page_count * arch::PAGE_SIZE;
                if self.commit(commit_now, true)
                {
                    return 0
                }

                commit_now
            }
            else
            {
                0
            }
        };

        let simple = page_count == 1 && alignment_in_pages == 1 && below == 0;

        if !self.page_frame_database_initialized
        {
            // Early page allocation before the page frame database is initialised.
            if !simple
            {
                panic();
            }

            let page = arch::early_allocate_page();

            if flags.contains(PhysicalAllocationFlags::zeroed)
            {
                let result = arch::map_page(unsafe { &mut kernel.physical_allocator }, unsafe { &mut kernel.core_address_space }, page, unsafe { (&early_zero_buffer as *const _) as u64 }, arch::MapPageFlags::overwrite | arch::MapPageFlags::no_new_tables | arch::MapPageFlags::frame_lock_acquired);
                assert!(result);
                unsafe { early_zero_buffer.data.fill(0) };
            }

            return page;
        }
        else if !simple
        {
            unimplemented!();
        }
        else
        {
            unimplemented!();
        }
    }

    pub fn commit(&mut self, byte_count: u64, fixed: bool) -> bool
    {
        unimplemented!();
    }
}
