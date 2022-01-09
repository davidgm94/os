use kernel::*;

pub struct Process
{
    pub address_space: memory::AddressSpace,
    pub id: u64,
    pub handle_count: u64,
    pub permissions: ProcessPermissions,
    pub kind: ProcessKind,
}

pub struct Scheduler
{
    pub dispatch_spinlock: Spinlock,
    pub next_process_id: AtomicU64,

    // @TODO: volatile
    pub started: bool,
    pub panic: bool,
    pub shutdown: bool,
}

pub enum ProcessKind
{
    normal,
    kernel,
    desktop,
}

pub struct Writer
{
    lock: VolatilePointer<WriterLock>,
    kind: bool,
}

#[derive(Copy, Clone, PartialEq)]
pub enum ThreadState
{
    active,
    waiting_for_mutex,
    waiting_for_event,
    waiting_for_writer_lock,
    terminated,
}

#[derive(Copy, Clone, PartialEq)]
pub enum ThreadTerminatableState
{
    invalid_TS,
    terminatable,
    in_syscall,
    user_block_request,
}

#[derive(Copy, Clone)]
pub struct ThreadVolatile
{
}

#[derive(Copy, Clone)]
pub struct ThreadWriterLock
{
    pub lock: VolatilePointer<WriterLock>,
    pub kind: bool,
}

pub const max_wait_count: usize = 8;

#[derive(Copy, Clone)]
pub struct ThreadEvent
{
    pub threads: VolatilePointer<LinkedItem<Thread>>,
    pub events: [VolatilePointer<Event>; max_wait_count],
    pub event_count: Volatile<u64>,
}

#[derive(Copy, Clone)]
pub struct ThreadBlocking
{
    pub mutex: VolatilePointer<Mutex>,
    pub writer: ThreadWriterLock,
    pub event: ThreadEvent,
}

#[derive(Copy, Clone)]
pub struct Thread
{
    pub in_safe_copy: bool,

    pub process: *mut Process,

    pub last_interrupt_timestamp: u64,
    pub is_kernel_thread: bool,
    pub is_page_generator: bool,

    pub state: Volatile<ThreadState>,
    pub terminatable_state: Volatile<ThreadTerminatableState>,
    pub executing: Volatile<bool>,
    pub terminating: Volatile<bool>,
    pub blocking: ThreadBlocking,

    pub temporary_address_space: VolatilePointer<memory::AddressSpace>
}

bitflags!
{
    pub struct ProcessPermissions: u64
    {
        const networking = 1 << 0;
        const process_create = 1 << 1;
        const process_open = 1 << 2;
        const screen_modify = 1 << 3;
        const shutdown = 1 << 4;
        const take_system_snapshot = 1 << 5;
        const get_volume_information = 1 << 6;
        const window_manager = 1 << 7;
        const posix_subsystem = 1 << 8;
    }
}

impl Process
{
    pub fn register(&mut self, kind: ProcessKind)
    {
        self.id = unsafe { kernel.scheduler.next_process_id.fetch_add(1, Ordering::SeqCst) };
        self.address_space.reference_count = 1;
        // list, table
        self.handle_count = 1;
        self.permissions = ProcessPermissions::all();
        self.kind = kind;
    }

    //pub fn spawn<'b>(process_kind: ProcessKind) -> Option<&'b mut Process>
    //{
        //if unsafe { kernel.scheduler.shutdown } { return None }

        //let process = match process_kind
        //{
            //ProcessKind::normal | ProcessKind::desktop =>
            //{
                //unimplemented!();
            //},
            //ProcessKind::kernel =>
            //{
                //let result = &mut unsafe { kernel.process };
                //result
            //}
        //};
    //}
}
