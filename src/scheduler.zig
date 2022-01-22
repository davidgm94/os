const kernel = @import("kernel.zig");


const SimpleList = kernel.SimpleList;
const Volatile = kernel.Volatile;

const Bitflag = kernel.Bitflag;

const TODO = kernel.TODO;
const panic_raw = kernel.panic_raw;

const LinkedList = kernel.LinkedList;
const Pool = kernel.Pool;

const open_handle = kernel.open_handle;

const max_wait_count = kernel.max_wait_count;

const Event = kernel.sync.Event;
const Spinlock = kernel.sync.Spinlock;
const Mutex = kernel.sync.Mutex;
const WriterLock = kernel.sync.WriterLock;

const AddressSpace = kernel.memory.AddressSpace;
const Region = kernel.memory.Region;

const interrupts = kernel.Arch.Interrupt;
const InterruptContext = interrupts.Context;
const get_current_thread = kernel.Arch.get_current_thread;
const page_size = kernel.Arch.page_size;
const LocalStorage = kernel.Arch.LocalStorage;

const std = @import("std");
const Atomic = std.atomic.Atomic;

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

thread_pool: Pool(Thread),
process_pool: Pool(Process),
address_space_pool: Pool(AddressSpace),

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

pub fn notify_object_extended(self: *@This(), blocked_threads: *LinkedList(Thread), unblock_all: bool, previous_mutex_owner: ?*Thread) void
{
    self.dispatch_spinlock.assert_locked();

    if (blocked_threads.first) |unblocked_item|
    {
        _ = unblocked_item;
        _ = previous_mutex_owner;
        _ = unblock_all;
        while (true)
        {
            //const next_unblocked_item = unblocked_item.next;
            //const unblocked_thread = unblocked_item.this;
            TODO();
        }
    }
}

pub fn notify_object(self: *@This(), blocked_threads: *LinkedList(Thread), unblock_all: bool) void
{
    self.notify_object_extended(blocked_threads, unblock_all, null);
}

pub fn add_active_thread(self: *@This(), thread: *Thread, start: bool) void
{
    if (thread.type == .async_task) return;

    self.dispatch_spinlock.assert_locked();

    if (thread.state.read_volatile() != .active) panic_raw("thread not active");
    if (thread.executing.read_volatile()) panic_raw("thread executing");
    if (thread.type != .normal) panic_raw("thread is not normal");
    if (thread.item.list != null) panic_raw("thread is already in a queue");

    if (thread.paused.read_volatile() and thread.terminatable_state.read_volatile() == .terminatable)
    {
        self.paused_threads.insert_at_start(&thread.item);
    }
    else
    {
        const effective_priority = self.get_thread_efective_priority(thread);

        if (start) self.active_threads[@intCast(u64, effective_priority)].insert_at_start(&thread.item)
        else self.active_threads[@intCast(u64, effective_priority)].insert_at_end(&thread.item);
    }
}

pub fn get_thread_efective_priority(self: *@This(), thread: *Thread) i8
{
    self.dispatch_spinlock.assert_locked();

    var priority: i8 = 0;
    while (priority < thread.priority) : (priority += 1)
    {
        if (thread.blocked_thread_priorities[@intCast(u64, priority)] != 0) return priority;
    }

    return thread.priority;
}

pub fn async_task_thread() callconv(.C) void
{
    TODO();
}

const max_processors = 256;

pub fn create_processor_threads(self: *@This(), local_storage: *LocalStorage) void
{
    local_storage.async_task_thread = kernel.process.spawn_thread(@ptrToInt(async_task_thread), 0, Thread.Flags.from_flag(.async_task));
    local_storage.idle_thread = kernel.process.spawn_thread(0, 0, Thread.Flags.from_flag(.idle));
    local_storage.current_thread = local_storage.idle_thread;
    local_storage.processor_ID = @intCast(u32, @atomicRmw(@TypeOf(self.next_processor_id), &self.next_processor_id, .Add, 1, .SeqCst));
    if (local_storage.processor_ID >= max_processors) panic_raw("maximum processor count reached");
}

pub fn thread_kill(task: *AsyncTask) void
{
    _ = task;
    TODO();
}

pub fn yield(self: *@This(), context: *InterruptContext) void
{
    if (!self.started.read_volatile()) return;
    if (LocalStorage.get()) |local|
    {
        if (!local.scheduler_ready) return;

        if (local.processor_ID == 0)
        {
            self.time_ms = kernel.arch.get_time_ms();
            kernel.global_data.scheduler_time_ms.write_volatile(self.time_ms);
            self.active_timers_spinlock.acquire();
            var timer_it = self.active_timers.first;

            while (timer_it != null) : (timer_it = timer_it.?.next)
            {
                const timer = timer_it.?.value.?;

                if (timer.trigger_time_ms <= self.time_ms)
                {
                    self.active_timers.remove(timer_it.?);
                    _ = timer.event.set(false);

                    if (timer.callback != null)
                    {
                        timer.async_task.register(timer.callback.?);
                    }
                }
                else
                {
                    break;
                }
            }

            self.active_timers_spinlock.release();
        }

        if (local.spinlock_count != 0) panic_raw("spinlocks acquired while attempting to yield");

        interrupts.disable();
        self.dispatch_spinlock.acquire();

        if (self.dispatch_spinlock.interrupts_enabled.read_volatile()) panic_raw("interrupts were enabled when scheduler lock was acquired");

        const current_thread = local.current_thread.?;
        if (!current_thread.executing.read_volatile()) panic_raw("current thread marked as not executing");

        const old_address_space: *AddressSpace = if (current_thread.temporary_address_space) |temp_addr_space| @ptrCast(*AddressSpace, temp_addr_space) else &current_thread.process.?.address_space;
        current_thread.interrupt_context = context;
        current_thread.executing.write_volatile(false);

        const kill_thread = current_thread.terminatable_state.read_volatile() == .terminatable and current_thread.terminating.read_volatile();
        const keep_thread_alive = current_thread.terminatable_state.read_volatile() == .user_block_request and current_thread.terminating.read_volatile();

        if (kill_thread)
        {
            current_thread.state.write_volatile(.terminated);
            current_thread.kill_async_task.register(thread_kill);
        }
        else
        {
            switch (current_thread.state.read_volatile())
            {
                .waiting_mutex =>
                {
                    const mutex = current_thread.blocking.mutex.?;

                    if (!keep_thread_alive and mutex.owner != null)
                    {
                        // @INFO: this should fail if the result is negative
                        const index = @intCast(u64, current_thread.priority);
                        mutex.owner.?.blocked_thread_priorities[index] += 1;
                        TODO();
                    }
                    else
                    {
                        current_thread.state.write_volatile(.active);
                    }
                },
                .waiting_event =>
                {
                    if (keep_thread_alive)
                    {
                        current_thread.state.write_volatile(.active);
                    }
                    else
                    {
                        TODO();
                    }
                },
                .waiting_writer_lock =>
                {
                    TODO();
                },
                else => {},
            }
        }

        if (!kill_thread and current_thread.state.read_volatile() == .active and current_thread.type == .normal)
        {
            TODO();
        }

        if (self.pick_thread(local)) |new_thread|
        {
            local.current_thread = new_thread;

            if (new_thread.executing.read_volatile()) panic_raw("thread in active queue already executing");

            new_thread.executing.write_volatile(true);
            new_thread.executing_processor_ID = local.processor_ID;
            new_thread.cpu_time_slices.increment();
            if (new_thread.type == .idle) new_thread.process.?.idle_time_slices += 1
            else new_thread.process.?.cpu_time_slices += 1;

            const one_ms = 1;
            kernel.Arch.next_timer(one_ms);

            const new_context = new_thread.interrupt_context;
            // @TODO: this may cause bugs!!!
            const address_space = if (new_thread.temporary_address_space) |new_thread_tmp_addr_space| @ptrCast(*AddressSpace, new_thread_tmp_addr_space) else &new_thread.process.?.address_space;
            address_space.open_reference();
            kernel.Arch.switch_context(new_context, &address_space.arch, new_thread.kernel_stack, new_thread, old_address_space);
        }
        else
        {
            panic_raw("could not find a thread to execute");
        }
    }
}

pub fn pick_thread(self: *@This(), local: *LocalStorage) ?*Thread
{
    self.dispatch_spinlock.assert_locked();

    if ((local.async_task_list.next_or_first != null or local.in_async_task) and local.async_task_thread.?.state.read_volatile() == .active)
    {
        return local.async_task_thread;
    }

    var thread_priority: u64 = 0;
    while (thread_priority < Thread.priority_count) : (thread_priority += 1)
    {
        if (self.active_threads[thread_priority].first) |item|
        {
            item.remove_from_list();
            return item.value;
        }
    }

    return local.idle_thread;
}

pub const Thread = struct
{
    in_safe_copy: bool,
    item: LinkedList(Thread).Item,
    all_item: LinkedList(Thread).Item,
    process_item: LinkedList(Thread).Item,

    process: ?*Process,
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
    timer_adjust_address: u64,
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
        mutex: ?*volatile Mutex,
        writer: struct
        {
            lock: ?*volatile WriterLock,
            type: bool,
        },
        event: struct
        {
            items: ?[*]volatile LinkedList(Thread).Item,
            array: [max_wait_count]*volatile Event,
            count: u64,
        },
    },

    killed_event: Event,
    kill_async_task: AsyncTask,

    temporary_address_space: ?*volatile AddressSpace,
    interrupt_context: *InterruptContext,
    last_known_execution_address: u64, // @TODO: for debugging

    pub const Priority = enum(i8)
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

    pub const Flags = Bitflag(enum(u32)
        {
            userland = 0,
            low_priority = 1,
            paused = 2,
            async_task = 3,
            idle = 4,
        });
};

pub const MessageQueue = struct
{
};

pub const HandleTable = struct
{
};

pub const Process = struct
{
    // @TODO: maybe turn into a pointer
    address_space: AddressSpace,
    message_queue: MessageQueue,
    handle_table: HandleTable,

    threads: LinkedList(Thread),
    threads_mutex: Mutex,

    permissions: Process.Permission,
    type: Process.Type,
    id: u64,
    handle_count: Volatile(u64),
    all_item: LinkedList(Process).Item,

    crash_mutex: Mutex,
    //...
    all_threads_terminated: bool,
    block_shutdown: bool,
    prevent_new_threads: bool,
    exit_status: i32,
    killed_event: Event,

    executable_state: u8,
    executable_start_request: bool,
    executable_load_attempt_complete: Event,
    executable_main_thread: ?*Thread,

    cpu_time_slices: u64,
    idle_time_slices: u64,
    
    pub const Type = enum
    {
        normal,
        desktop,
        kernel,
    };

    pub const Permission = Bitflag(enum(u64)
        {
            networking = 0,
            process_create = 1,
            process_open = 2,
            screen_modify = 3,
            shutdown = 4,
            take_system_snapshot = 5,
            get_volume_information = 6,
            window_manager = 7,
            posix_subsystem = 8,
        });

    pub fn register(self: *@This(), process_type: Process.Type) void
    {
        self.id = @atomicRmw(@TypeOf(kernel.scheduler.next_processor_id), &kernel.scheduler.next_process_id, .Add, 1, .SeqCst);
        self.address_space.reference_count.write_volatile(1);
        //// list, table
        self.handle_count.write_volatile(1);
        self.permissions = Process.Permission.all();
        self.type = process_type;
    }

    pub fn spawn_thread_extended(self: *@This(), start_address: u64, argument1: u64, flags: Thread.Flags, argument2: u64) ?*Thread
    {
        const userland = flags.contains(.userland);

        const parent_thread = get_current_thread();
        _ = parent_thread;

        if (userland and self == &kernel.process)
        {
            panic_raw("cannot add userland thread to kernel process");
        }

        _ = self.threads_mutex.acquire();
        defer self.threads_mutex.release();

        if (self.prevent_new_threads) return null;

        if (kernel.scheduler.thread_pool.add()) |thread|
        {
            const kernel_stack_size: u64 = 0x5000;
            const user_stack_reserve: u64 = if (userland) 0x400000 else kernel_stack_size;
            const user_stack_commit: u64 = if (userland) 0x10000 else 0;
            var user_stack: u64 = 0;
            var kernel_stack: u64 = 0;

            var failed = false;
            if (!flags.contains(.idle))
            {
                kernel_stack = kernel.process.address_space.standard_allocate(kernel_stack_size, Region.Flags.from_flag(.fixed));
                if (kernel_stack != 0)
                {
                    if (userland)
                    {
                        user_stack = self.address_space.standard_allocate_extended(user_stack_reserve, Region.Flags.empty(), 0, false);

                        const region = self.address_space.find_and_pin_region(user_stack, user_stack_reserve).?;
                        _ = self.address_space.reserve_mutex.acquire();
                        const success = self.address_space.commit_range(region, (user_stack_reserve - user_stack_commit) / page_size, user_stack_commit / page_size);
                        self.address_space.reserve_mutex.release();
                        self.address_space.unpin_region(region);
                        failed = !success or user_stack == 0;
                    }
                    else
                    {
                        user_stack = kernel_stack;
                    }
                }
                else
                {
                    failed = true;
                }
            }

            if (!failed)
            {
                thread.paused.write_volatile((parent_thread != null and parent_thread.?.process != null and parent_thread.?.paused.read_volatile()) or flags.contains(.paused));
                thread.handle_count.write_volatile(2);
                thread.is_kernel_thread = !userland;
                thread.priority = @enumToInt(if (flags.contains(.low_priority)) Thread.Priority.low else Thread.Priority.normal);
                thread.kernel_stack_base = kernel_stack;
                thread.user_stack_base = if (userland) user_stack else 0;
                thread.user_stack_reserve = user_stack_reserve;
                thread.user_stack_commit.write_volatile(user_stack_commit);
                thread.terminatable_state.write_volatile(if (userland) .terminatable else .in_syscall);
                thread.type = if (flags.contains(.async_task)) Thread.Type.async_task else (if (flags.contains(.idle)) Thread.Type.idle else Thread.Type.normal);
                thread.id = @atomicRmw(u64, &kernel.scheduler.next_thread_id, .Add, 1, .SeqCst);
                thread.process = self;
                thread.item.value = thread;
                thread.all_item.value = thread;
                thread.process_item.value = thread;

                if (thread.type != .idle)
                {
                    thread.interrupt_context = kernel.Arch.initialize_thread(kernel_stack, kernel_stack_size, thread, start_address, argument1, argument2, userland, user_stack, user_stack_reserve);
                }
                else
                {
                    thread.state.write_volatile(.active);
                    thread.executing.write_volatile(true);
                }

                self.threads.insert_at_end(&thread.process_item);

                _ = kernel.scheduler.all_threads_mutex.acquire();
                kernel.scheduler.all_threads.insert_at_start(&thread.all_item);
                kernel.scheduler.all_threads_mutex.release();

                _ = open_handle(Process, self, 0);
                // log

                if (thread.type == .normal)
                {
                    // add to the start of the active thread list
                    kernel.scheduler.dispatch_spinlock.acquire();
                    kernel.scheduler.add_active_thread(thread, true);
                    kernel.scheduler.dispatch_spinlock.release();
                }
                else {} // idle and asynchronous threads dont need to be added to a scheduling list

                // The thread may now be terminated at any moment
                return thread;
            }
            else
            {
                if (user_stack != 0) _ = self.address_space.free(user_stack);
                if (kernel_stack != 0) _ = self.address_space.free(kernel_stack);
                kernel.scheduler.thread_pool.remove(thread);
                return null;
            }
        }
        else
        {
            return null;
        }

    }

    pub fn spawn_thread(self: *@This(), start_address: u64, argument1: u64, flags: Thread.Flags) ?*Thread
    {
        return self.spawn_thread_extended(start_address, argument1, flags, 0);
    }

    pub fn spawn_thread_no_flags(self: *@This(), start_address: u64, argument1: u64) ?*Thread
    {
        return self.spawn_thread(start_address, argument1, Thread.Flags.empty());
    }
};

pub const AsyncTask = struct
{
    item: SimpleList,
    callback: ?Callback,

    pub const Callback = fn (*@This()) void;

    pub fn register(self: *@This(), callback: Callback) void
    {
        kernel.scheduler.async_task_spinlock.acquire();
        if (self.callback == null)
        {
            self.callback = callback;
            LocalStorage.get().?.async_task_list.insert(&self.item, false);
        }
        kernel.scheduler.async_task_spinlock.release();
    }
};

pub const Timer = struct
{
    event: Event,
    async_task: AsyncTask,
    item: LinkedList(Timer).Item,
    trigger_time_ms: u64,
    callback: ?AsyncTask.Callback,
    argument: u64,

    pub fn set_extended(self: *@This(), trigger_in_ms: u64, maybe_callback: ?AsyncTask.Callback, maybe_argument: u64) void
    {
        kernel.scheduler.active_timers_spinlock.acquire();

        if (self.item.list != null) kernel.scheduler.active_timers.remove(&self.item);

        self.event.reset();

        self.trigger_time_ms = trigger_in_ms + kernel.scheduler.time_ms;
        self.callback = maybe_callback;
        self.argument = maybe_argument;
        self.item.value = self;

        var maybe_timer = kernel.scheduler.active_timers.first;
        while (maybe_timer != null)
        {
            const timer = maybe_timer.?.value.?;
            const next = maybe_timer.?.next;
            if (timer.trigger_time_ms > self.trigger_time_ms) break;

            maybe_timer = next;
        }

        if (maybe_timer) |timer|
        {
            kernel.scheduler.active_timers.insert_before(&self.item, timer);
        }
        else
        {
            kernel.scheduler.active_timers.insert_at_end(&self.item);
        }

        kernel.scheduler.active_timers_spinlock.release();
    }

    pub fn set(self: *@This(), trigger_in_ms: u64) void
    {
        self.set_extended(trigger_in_ms, null, 0);
    }

    pub fn remove(self: *@This()) void
    {
        kernel.scheduler.active_timers_spinlock.acquire();

        if (self.callback != null) panic_raw("timer with callback cannot be removed");

        if (self.item.list != null) kernel.scheduler.active_timers.remove(&self.item);

        kernel.scheduler.active_timers_spinlock.release();
    }
};
