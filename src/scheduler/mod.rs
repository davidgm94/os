use core::sync::atomic::{AtomicU64, Ordering};
use core::ptr::null_mut;
use {LinkedItem, Volatile, HandleTable};
use memory::AddressSpace;
use {kernel, scheduler, panic};
use synchronization::Spinlock;

#[derive(PartialEq)]
pub enum ProcessKind
{
    kernel,
    desktop,
    normal,
}

impl Default for ProcessKind
{
    fn default() -> Self {
        ProcessKind::normal
    }
}

pub enum ThreadKind
{
}

pub enum ThreadPriority
{
}

#[derive(PartialEq)]
pub enum ThreadState
{
    active,
    waiting_mutex,
    waiting_event,
    waiting_writer_lock,
    terminated,
}

#[derive(PartialEq)]
pub enum ThreadTerminatableState
{
    invalid_TS,
    terminatable,
    in_syscall,
    user_block_request,
}

const thread_priority_count: usize = core::mem::variant_count::<ThreadPriority>();

pub union ThreadBlocking
{
    pub mutex: u64,
}

#[repr(C)]
pub struct Thread
{
    pub in_safe_copy: bool,
    pub process_id: u64,
    pub id: u64,
    pub cpu_time_slices: Volatile<u64>,
    pub handle_count: Volatile<u64>,
    pub executing_processor_ID: u32,

    pub user_stack_base: u64,
    pub kernel_stack_base: u64,
    pub kernel_stack: u64,
    pub TLS_address: u64,
    pub user_stack_reserve: u64,
    pub user_stack_commit: Volatile<u64>,

    pub kind: ThreadKind,
    pub is_kernel_thread: bool,
    pub is_page_generator: bool,
    pub priority: i8,
    pub blocked_thread_priorities: [i32;thread_priority_count],

    pub state: Volatile<ThreadState>,
    pub terminatable_state: Volatile<ThreadTerminatableState>,
    pub executing: Volatile<bool>,
    pub terminating: Volatile<bool>,
    pub paused: Volatile<bool>,
    pub received_yield_IPI: Volatile<bool>,

    pub blocking: ThreadBlocking,

    // (...)
}

pub struct Scheduler
{
    pub dispatch_spinlock: Spinlock,
    pub shutdown: bool,
    pub panic: bool,
    pub started: bool,
}

impl<'a> Scheduler
{
    pub fn get_thread(&mut self, id: u64) -> *mut Thread
    {
        return 0 as *mut Thread;
    }
}

pub struct Process
{
    pub address_space: AddressSpace,
    // message queue
    pub handle_table: HandleTable,
    // threads
    // threads mutex
    //
    // executable node
    // executable name
    // data
    pub permissions: u64,
    // creationflags
    pub kind: ProcessKind,

    pub id: u64,
    pub all_id: u64,
    pub handles: Volatile<u64>,

    // crash mutex
    // crash reason
    pub crashed: bool,

    pub all_threads_terminated: bool,
    pub block_shutdown: bool,
    pub prevent_new_threads: bool,
    pub exit_status: i32,
    // killed event
    //

    pub executable_state: u8,
    pub executable_start_request: bool,
    // executable load attempt complete
    // executable main thread

    pub cpu_time_slices: u64,
    pub idle_time_slices: u64,
}

pub static NEXT_PROCESS_ID: AtomicU64 = AtomicU64::new(0);
