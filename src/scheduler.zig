const kernel = @import("kernel.zig");

const Volatile = kernel.Volatile;
const VolatilePointer = kernel.VolatilePointer;

const LinkedList = kernel.LinkedList;
const Pool = kernel.Pool;

const Event = kernel.sync.Event;
const Spinlock = kernel.sync.Spinlock;
const Mutex = kernel.sync.Mutex;
const WriterLock = kernel.sync.WriterLock;

const AddressSpace = kernel.memory.AddressSpace;

const InterruptContext = kernel.Arch.Interrupt.Context;

const std = @import("std");

dispatch_spinlock: Spinlock,
active_timers_spinlock: Spinlock,
active_threads: [Thread.priority_count]LinkedList(Thread),
paused_threads: LinkedList(Thread),
active_timers: LinkedList(Timer),

all_threads_mutex: Mutex,
all_processes_mutex: Mutex,
async_task_spinlock: Spinlock,
all_threads: LinkedList(Thread),
all_processes: LinkedList(Process),

thread_pool: Pool,
process_pool: Pool,
address_space_pool: Pool,

next_thread_id: u64,
next_process_id: u64,
next_processor_id: u64,

all_processes_terminated_event: Event,
block_shutdown_process_count: Volatile(u64),
active_process_count: Volatile(u64),
started: Volatile(bool),
panic: Volatile(bool),
shutdown: Volatile(bool),
time_ms: u64,

pub const Thread = struct
{
    in_safe_copy: bool,
    item: LinkedList(Thread).Item,
    all_item: LinkedList(Thread).Item,
    process_item: LinkedList(Thread).Item,

    process: *Process,
    id: u64,
    cpu_time_slices: Volatile(u64),
    handle_count: Volatile(u64),
    executing_processor_ID: u32,

    user_stack_base: u64,
    kernel_stack_base: u64,
    kernel_stack: u64,
    user_stack_reserve: u64,
    user_stack_commit: Volatile(u64),

    tls_address: u64,
    time_adjust_address: u64,
    timer_adjust_ticks: u64,
    last_interrupt_timestamp: u64,

    type: Thread.Type,
    is_kernel_thread: bool,
    is_page_generator: bool,
    priority: i8,
    blocked_thread_priorities: [Thread.priority_count]i32,

    state: Volatile(Thread.State),
    terminatable_state: Volatile(Thread.TerminatableState),
    executing: Volatile(bool),
    terminating: Volatile(bool),
    paused: Volatile(bool),
    received_yield_IPI: Volatile(bool),

    blocking: extern union
    {
        mutex: VolatilePointer(Mutex),
        writer: struct
        {
            lock: VolatilePointer(WriterLock),
            type: bool,
        },
        event: struct
        {
            items: LinkedList(Thread).Item,
            events: [max_wait_count]VolatilePointer(Event),
            event_count: u64,
        },
    },

    killed_event: Event,
    kill_async_task: AsyncTask,

    temporary_address_space: VolatilePointer(AddressSpace),
    interrupt_context: *InterruptContext,
    last_known_execution_address: u64, // @TODO: for debugging

    pub const Priority = enum(u8)
    {
        normal = 0,
        low = 1,
    };
    pub const priority_count = std.enums.values(Priority).len;

    pub const State = enum(i8)
    {
        active = 0,
        waiting_mutex = 1,
        waiting_event = 2,
        waiting_writer_lock = 3,
        terminated = 4,
    };

    pub const Type = enum(i8)
    {
        normal = 0,
        idle = 1,
        async_task = 2,
    };

    pub const TerminatableState = enum(i8)
    {
        invalid_TS = 0,
        terminatable = 1,
        in_syscall = 2,
        user_block_request = 3,
    };
};

pub const Process = struct
{
    // @TODO: maybe turn into a pointer
    address_space: AddressSpace,
};

pub const max_wait_count = 8;
pub const wait_no_timeout = std.math.maxInt(u64);

pub const AsyncTask = struct
{
};

pub const Timer = struct
{
};
