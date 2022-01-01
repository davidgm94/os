pub mod arch;
pub mod memory;
pub mod scheduler;

use self::scheduler::{Scheduler, Process, Thread};

extern crate bitflags;
pub use self::bitflags::bitflags;

pub use core::sync::atomic::*;
pub use core::arch::asm;
pub use core::mem::{size_of, transmute};
pub use core::intrinsics::unreachable;
pub use core::ptr::{null, null_mut};

pub struct Kernel<'a>
{
    core: Core<'a>,
    scheduler: Scheduler,
    process: Process,
    arch: arch::Specific<'a>,
}

pub struct Core<'a>
{
    regions: &'a mut[memory::Region],
    region_commit_count: u64,
}

impl<'a> Kernel<'a>
{
    #[inline(never)]
    pub fn init(&mut self)
    {
        self.process.register(scheduler::ProcessKind::kernel);
        self.memory_init();
    }
}

pub static mut kernel: Kernel = Kernel
{
    core: Core
    {
        regions: &mut[],
        region_commit_count: 0,
    },
    scheduler: Scheduler
    {
        next_process_id: AtomicU64::new(0),
        started: false,
        panic: false,
        shutdown: false,
    },
    process: Process
    {
        id: 0,
        handle_count: 0,
        address_space: memory::AddressSpace
        {
            arch: arch::Memory::AddressSpace
            {
                cr3: 0,
            },
            reference_count: 0,
        },
        permissions: scheduler::ProcessPermissions::empty(),
        kind: scheduler::ProcessKind::kernel,
    },
    arch: arch::Specific::default(),
};

fn _panic(_: &str)
{
    
}

pub fn panic(msg: &str) -> !
{
    _panic(msg);
    loop{}
}
