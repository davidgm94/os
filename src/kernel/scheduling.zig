const kernel = @import("kernel.zig");

const zeroes = kernel.zeroes;
const align_u64 = kernel.align_u64;
const TODO = kernel.TODO;
const Volatile = kernel.Volatile;
const LinkedList = kernel.LinkedList;
const SimpleList = kernel.SimpleList;
const Pool = kernel.Pool;
const FatalError = kernel.FatalError;
const Bitflag = kernel.Bitflag;
const CrashReason = kernel.CrashReason;

const arch = kernel.arch;
const page_size = arch.page_size;

const serial = kernel.drivers.serial;

const files = kernel.files;

const AddressSpace = kernel.memory.AddressSpace;
const Region = kernel.memory.Region;

const object = kernel.object;

const Spinlock = kernel.sync.Spinlock;
const Mutex = kernel.sync.Mutex;
const Event = kernel.sync.Event;
const WriterLock = kernel.sync.WriterLock;

const std = @import("std");
const assert = std.debug.assert;

pub const Scheduler = extern struct
{
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

    pub fn yield(self: *@This(), context: *arch.InterruptContext) void
    {
        if (!self.started.read_volatile()) return;
        if (arch.get_local_storage()) |local|
        {
            if (!local.scheduler_ready) return;

            if (local.processor_ID == 0)
            {
                self.time_ms = arch.get_time_ms();
                kernel.globalData.scheduler_time_ms.write_volatile(self.time_ms);

                self.active_timers_spinlock.acquire();

                var maybe_timer_item = self.active_timers.first;

                while (maybe_timer_item) |timer_item|
                {
                    const timer = timer_item.value.?;
                    const next = timer_item.next;

                    if (timer.trigger_time_ms <= self.time_ms)
                    {
                        self.active_timers.remove(timer_item);
                        _ = timer.event.set(false);

                        if (@intToPtr(?AsyncTask.Callback, timer.callback)) |callback|
                        {
                            timer.async_task.register(callback);
                        }
                    }
                    else
                    {
                        break;
                    }
                    maybe_timer_item = next;
                }

                self.active_timers_spinlock.release();
            }

            if (local.spinlock_count != 0) kernel.panic("Spinlocks acquired while attempting to yield");

            arch.disable_interrupts();
            self.dispatch_spinlock.acquire();

            if (self.dispatch_spinlock.interrupts_enabled.read_volatile())
            {
                kernel.panic("interrupts were enabled when scheduler lock was acquired");
            }

            if (!local.current_thread.?.executing.read_volatile()) kernel.panic("current thread marked as not executing");

            const old_address_space = if (local.current_thread.?.temporary_address_space) |tas| @ptrCast(*AddressSpace, tas) else local.current_thread.?.process.?.address_space;

            local.current_thread.?.interrupt_context = context;
            local.current_thread.?.executing.write_volatile(false);

            const kill_thread = local.current_thread.?.terminatable_state.read_volatile() == .terminatable and local.current_thread.?.terminating.read_volatile();
            const keep_thread_alive = local.current_thread.?.terminatable_state.read_volatile() == .user_block_request and local.current_thread.?.terminating.read_volatile();

            if (kill_thread)
            {
                local.current_thread.?.state.write_volatile(.terminated);
                local.current_thread.?.kill_async_task.register(Thread.kill);
            }
            else if (local.current_thread.?.state.read_volatile() == .waiting_mutex)
            {
                const mutex = @ptrCast(*Mutex, local.current_thread.?.blocking.mutex.?);
                if (!keep_thread_alive and mutex.owner != null)
                {
                    mutex.owner.?.blocked_thread_priorities[@intCast(u64, local.current_thread.?.priority)] += 1;
                    self.maybe_update_list(@ptrCast(*Thread, @alignCast(@alignOf(Thread), mutex.owner.?)));
                    mutex.blocked_threads.insert_at_end(&local.current_thread.?.item);
                }
                else
                {
                    local.current_thread.?.state.write_volatile(.active);
                }
            }
            else if (local.current_thread.?.state.read_volatile() == .waiting_event)
            {
                if (keep_thread_alive)
                {
                    local.current_thread.?.state.write_volatile(.active);
                }
                else
                {
                    var unblocked = false;

                    for (local.current_thread.?.blocking.event.array[0..local.current_thread.?.blocking.event.count]) |event|
                    {
                        if (event.?.state.read_volatile() != 0)
                        {
                            local.current_thread.?.state.write_volatile(.active);
                            unblocked = true;
                            break;
                        }
                    }

                    if (!unblocked)
                    {
                        for (local.current_thread.?.blocking.event.array[0..local.current_thread.?.blocking.event.count]) |_event, i|
                        {
                            const event = @ptrCast(*Event, _event.?);
                            const item = @ptrCast(*LinkedList(Thread).Item, &local.current_thread.?.blocking.event.items.?[i]);
                            event.blocked_threads.insert_at_end(item);
                        }
                    }
                }
            }
            else if (local.current_thread.?.state.read_volatile() == .waiting_writer_lock)
            {
                const lock = @ptrCast(*WriterLock, local.current_thread.?.blocking.writer.lock.?);
                if ((local.current_thread.?.blocking.writer.type == WriterLock.shared and lock.state.read_volatile() >= 0) or
                    (local.current_thread.?.blocking.writer.type == WriterLock.exclusive and lock.state.read_volatile() == 0))
                {
                    local.current_thread.?.state.write_volatile(.active);
                }
                else
                {
                    lock.blocked_threads.insert_at_end(&local.current_thread.?.item);
                }
            }

            if (!kill_thread and local.current_thread.?.state.read_volatile() == .active)
            {
                if (local.current_thread.?.type == .normal)
                {
                    self.add_active_thread(local.current_thread.?, false);
                }
                else if (local.current_thread.?.type == .idle or local.current_thread.?.type == .async_task)
                {
                }
                else
                {
                    kernel.panic("unrecognized thread type");
                }
            }

            const new_thread = self.pick_thread(local) orelse kernel.panic("Could not find a thread to execute");
            local.current_thread = new_thread;
            if (new_thread.executing.read_volatile()) kernel.panic("thread in active queue already executing");

            new_thread.executing.write_volatile(true);
            new_thread.executing_processor_ID = local.processor_ID;
            new_thread.cpu_time_slices.increment();
            if (new_thread.type == .idle) new_thread.process.?.idle_time_slices += 1
            else new_thread.process.?.cpu_time_slices += 1;

            arch.next_timer(1);
            const new_context = new_thread.interrupt_context;
            const address_space = if (new_thread.temporary_address_space) |tas| @ptrCast(*AddressSpace, tas) else new_thread.process.?.address_space;
            address_space.open_reference();
            arch.switch_context(new_context, &address_space.arch, new_thread.kernel_stack, new_thread, old_address_space);
            kernel.panic("do context switch unexpectedly returned");
        }
    }

    pub fn add_active_thread(self: *@This(), thread: *Thread, start: bool) void
    {
        if (thread.type == .async_task) return;
        if (thread.state.read_volatile() != .active) kernel.panic("thread not active")
        else if (thread.executing.read_volatile()) kernel.panic("thread executing")
        else if (thread.type != .normal) kernel.panic("thread not normal")
        else if (thread.item.list != null) kernel.panic("thread already in queue");

        if (thread.paused.read_volatile() and thread.terminatable_state.read_volatile() == .terminatable)
        {
            self.paused_threads.insert_at_start(&thread.item);
        }
        else
        {
            const effective_priority = @intCast(u64, self.get_thread_effective_priority(thread));
            if (start) self.active_threads[effective_priority].insert_at_start(&thread.item)
            else self.active_threads[effective_priority].insert_at_end(&thread.item);
        }
    }

    pub fn get_thread_effective_priority(self: *@This(), thread: *Thread) i8
    {
        self.dispatch_spinlock.assert_locked();

        for (thread.blocked_thread_priorities[0..@intCast(u64, thread.priority)]) |priority, i|
        {
            if (priority != 0) return @intCast(i8, i);
        }

        return thread.priority;
    }

    pub fn pick_thread(self: *@This(), local: *arch.LocalStorage) ?*Thread
    {
        self.dispatch_spinlock.assert_locked();

        if ((local.async_task_list.next_or_first != null or local.in_async_task)
            and local.async_task_thread.?.state.read_volatile() == .active)
        {
            return local.async_task_thread;
        }

        for (self.active_threads) |*thread_item|
        {
            if (thread_item.first) |first|
            {
                first.remove_from_list();
                return first.value;
            }
        }

        return local.idle_thread;
    }

    pub fn maybe_update_list(self: *@This(), thread: *Thread) void
    {
        if (thread.type == .async_task) return;
        if (thread.type != .normal) kernel.panic("trying to update the active list of a non-normal thread");

        self.dispatch_spinlock.assert_locked();

        if (thread.state.read_volatile() != .active or thread.executing.read_volatile()) return;
        if (thread.item.list == null) kernel.panic("Despite thread being active and not executing, it is not in an active thread list");

        const effective_priority = @intCast(u64, self.get_thread_effective_priority(thread));
        if (&self.active_threads[effective_priority] == thread.item.list) return;
        thread.item.remove_from_list();
        self.active_threads[effective_priority].insert_at_start(&thread.item);
    }

    pub fn unblock_thread(self: *@This(), unblocked_thread: *Thread, previous_mutex_owner: ?*Thread) void
    {
        _ = previous_mutex_owner;
        self.dispatch_spinlock.assert_locked();
        switch (unblocked_thread.state.read_volatile())
        {
            .waiting_mutex => TODO(@src()),
            .waiting_event => TODO(@src()),
            .waiting_writer_lock => TODO(@src()),
            else => kernel.panic("unexpected thread state"),
        }

        unblocked_thread.state.write_volatile(.active);
        if (!unblocked_thread.executing.read_volatile()) self.add_active_thread(unblocked_thread, true);
    }

    pub fn notify_object(self: *@This(), blocked_threads: *LinkedList(Thread), unblock_all: bool, previous_mutex_owner: ?*Thread) void
    {
        self.dispatch_spinlock.assert_locked();

        var unblocked_item = blocked_threads.first;
        if (unblocked_item == null) return;
        while (true)
        {
            if (@ptrToInt(unblocked_item) < 0xf000000000000000)
            {
                kernel.panic("here");
            }
            const next_unblocked_item = unblocked_item.?.next;
            const unblocked_thread = unblocked_item.?.value.?;
            self.unblock_thread(unblocked_thread, previous_mutex_owner);
            unblocked_item = next_unblocked_item;
            if (!(unblock_all and unblocked_item != null)) break;
        }
    }
};

//export fn SchedulerAddActiveThread(thread: *Thread, start: bool) callconv(.C) void
//{
    //scheduler.add_active_thread(thread, start);
//}
//export fn SchedulerGetThreadEffectivePriority(thread: *Thread) callconv(.C) i8
//{
    //return scheduler.get_thread_effective_priority(thread);
//}
//export fn SchedulerPickThread(local: *LocalStorage) callconv(.C) ?*Thread
//{
    //return scheduler.pick_thread(local);
//}
//export fn SchedulerMaybeUpdateActiveList(thread: *Thread) callconv(.C) void
//{
    //scheduler.maybe_update_list(thread);
//}

//export fn SchedulerUnblockThread(unblocked_thread: *Thread, previous_mutex_owner: ?*Thread) callconv(.C) void
//{
    //scheduler.unblock_thread(unblocked_thread, previous_mutex_owner);
//}
////extern fn SchedulerYield(context: *InterruptContext) callconv(.C) void;
//export fn SchedulerYield(context: *InterruptContext) callconv(.C) void
//{
    //scheduler.yield(context);
//}

pub const Thread = extern struct
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
        writer: extern struct
        {
            lock: ?*volatile WriterLock,
            type: bool,
        },
        event: extern struct
        {
            items: ?[*]volatile LinkedList(Thread).Item,
            array: [kernel.max_wait_count]?*volatile Event,
            count: u64,
        },
    },

    killed_event: Event,
    kill_async_task: AsyncTask,

    temporary_address_space: ?*volatile AddressSpace,
    interrupt_context: *arch.InterruptContext,
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

    pub fn remove(self: *@This()) void
    {
        kernel.scheduler.thread_pool.remove(@ptrToInt(self));
    }

    pub export fn SetTemporaryAddressSpace(space: ?*AddressSpace) callconv(.C) void
    {
        kernel.scheduler.dispatch_spinlock.acquire();
        const thread = arch.get_current_thread().?;
        const old_space = if (thread.temporary_address_space) |tas| tas else &kernel.address_space;
        thread.temporary_address_space = space;
        const new_space = if (space) |sp| sp else &kernel.address_space;
        new_space.open_reference(); //open our reference to the space
        new_space.open_reference(); // this reference will be closed in PostContextSwitch, simulating the reference opened in Scheduler.yield
        arch.set_address_space(&new_space.arch);
        kernel.scheduler.dispatch_spinlock.release();
        (@ptrCast(*AddressSpace, old_space)).close_reference(); // close our reference to the space
        (@ptrCast(*AddressSpace, old_space)).close_reference(); // this reference was opened by Scheduler.yield and would have been closed in PostContextSwitch
    }

    pub fn spawn(start_address: u64, argument1: u64, flags: Thread.Flags, maybe_process: ?*Process, argument2: u64) callconv(.C) ?*Thread
    {
        if (start_address == 0 and !flags.contains(.idle)) kernel.panic("Start address is 0");
        const userland = flags.contains(.userland);
        const parent_thread = arch.get_current_thread();
        const process = if (maybe_process) |process_r| process_r else &kernel.process;
        if (userland and process == &kernel.process) kernel.panic("cannot add userland thread to kernel process");

        _ = process.threads_mutex.acquire();
        defer process.threads_mutex.release();

        if (process.prevent_new_threads) return null;

        const thread = @intToPtr(?*Thread, kernel.scheduler.thread_pool.add(@sizeOf(Thread))) orelse return null;
        const kernel_stack_size = 0x5000;
        const user_stack_reserve: u64 = if (userland) 0x400000 else kernel_stack_size;
        const user_stack_commit: u64 = if (userland) 0x10000 else 0;
        var user_stack: u64 = 0;
        var kernel_stack: u64 = 0;

        var failed = false;
        if (!flags.contains(.idle))
        {
            kernel_stack = kernel.address_space.allocate_standard(kernel_stack_size, Region.Flags.from_flag(.fixed), 0, true);
            failed = (kernel_stack == 0);
            if (!failed)
            {
                if (userland)
                {
                    user_stack = process.address_space.allocate_standard(user_stack_reserve, Region.Flags.empty(), 0, false);
                    // @TODO: this migh be buggy, since we are using an invalid stack to get a region?
                    const region = process.address_space.find_and_pin_region(user_stack, user_stack_reserve).?;
                    _ = process.address_space.reserve_mutex.acquire();
                    failed = !process.address_space.commit_range(region, (user_stack_reserve - user_stack_commit) / page_size, user_stack_commit / page_size);
                    process.address_space.reserve_mutex.release();
                    process.address_space.unpin_region(region);
                    failed = failed or user_stack == 0;
                }
                else
                {
                    user_stack = kernel_stack;
                }
            }
        }

        if (!failed)
        {
            thread.paused.write_volatile((parent_thread != null and process == parent_thread.?.process and parent_thread.?.paused.read_volatile()) or flags.contains(.paused));
            thread.handle_count.write_volatile(2);
            thread.is_kernel_thread = !userland;
            thread.priority = if (flags.contains(.low_priority)) @enumToInt(Thread.Priority.low) else @enumToInt(Thread.Priority.normal);
            thread.kernel_stack_base = kernel_stack;
            thread.user_stack_base = if (userland) user_stack else 0;
            thread.user_stack_reserve = user_stack_reserve;
            thread.user_stack_commit.write_volatile(user_stack_commit);
            thread.terminatable_state.write_volatile(if (userland) .terminatable else .in_syscall);
            thread.type = 
                if (flags.contains(.async_task)) Thread.Type.async_task
                else if (flags.contains(.idle)) Thread.Type.idle
                else Thread.Type.normal;
            thread.id = @atomicRmw(u64, &kernel.scheduler.next_thread_id, .Add, 1, .SeqCst);
            thread.process = process;
            thread.item.value = thread;
            thread.all_item.value = thread;
            thread.process_item.value = thread;

            if (thread.type != .idle)
            {
                thread.interrupt_context = arch.initialize_thread(kernel_stack, kernel_stack_size, thread, start_address, argument1, argument2, userland, user_stack, user_stack_reserve);
            }
            else
            {
                thread.state.write_volatile(.active);
                thread.executing.write_volatile(true);
            }

            process.threads.insert_at_end(&thread.process_item);

            _ = kernel.scheduler.all_threads_mutex.acquire();
            kernel.scheduler.all_threads.insert_at_start(&thread.all_item);
            kernel.scheduler.all_threads_mutex.release();

            // object process
            // @TODO
            _ = object.open_handle(process, 0);

            if (thread.type == .normal)
            {
                kernel.scheduler.dispatch_spinlock.acquire();
                kernel.scheduler.add_active_thread(thread, true);
                kernel.scheduler.dispatch_spinlock.release();
            }
            else
            {
                // do nothing
            }
            return thread;
        }
        else
        {
            // fail
            if (user_stack != 0) _ = process.address_space.free(user_stack, 0, false);
            if (kernel_stack != 0) _ = kernel.address_space.free(kernel_stack, 0, false);
            kernel.scheduler.thread_pool.remove(@ptrToInt(thread));
            return null;
        }
    }
    fn kill(task: *AsyncTask) void
    {
        const thread = @fieldParentPtr(Thread, "kill_async_task", task);
        Thread.SetTemporaryAddressSpace(thread.process.?.address_space);

        _ = kernel.scheduler.all_threads_mutex.acquire();
        kernel.scheduler.all_threads.remove(&thread.all_item);
        kernel.scheduler.all_threads_mutex.release();

        _ = thread.process.?.threads_mutex.acquire();
        thread.process.?.threads.remove(&thread.process_item);
        const last_thread = thread.process.?.threads.count == 0;
        thread.process.?.threads_mutex.release();

        if (last_thread) ProcessKill(thread.process.?);

        _ = kernel.address_space.free(thread.kernel_stack_base, 0, false);
        if (thread.user_stack_base != 0) _ = thread.process.?.address_space.free(thread.user_stack_base, 0, false);
        _ = thread.killed_event.set(false);
        object.close_handle(thread.process, 0);
        object.close_handle(thread, 0);
    }
};
pub const Timer = extern struct
{
    event: Event,
    async_task: AsyncTask,
    item: LinkedList(Timer).Item,
    trigger_time_ms: u64,
    callback: u64, //?AsyncTask.Callback,
    argument: u64,

    pub fn set_extended(self: *@This(), trigger_in_ms: u64, maybe_callback: ?AsyncTask.Callback, maybe_argument: u64) void
    {
        kernel.scheduler.active_timers_spinlock.acquire();

        if (self.item.list != null) kernel.scheduler.active_timers.remove(&self.item);

        self.event.reset();

        self.trigger_time_ms = trigger_in_ms + kernel.scheduler.time_ms;
        self.callback = @ptrToInt(maybe_callback);
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

        if (self.callback != 0) kernel.panic("timer with callback cannot be removed");

        if (self.item.list != null) kernel.scheduler.active_timers.remove(&self.item);

        kernel.scheduler.active_timers_spinlock.release();
    }
};

const ObjectCacheItem = SimpleList;
pub const Node = extern struct
{
    driver_node: u64,
    handle_count: Volatile(u64),
    directory_entry: u64,
    filesystem: u64,
    id: u64,
    writer_lock: WriterLock,
    node_error: i64,
    flags: Volatile(u32),
    cache_item: ObjectCacheItem,
};

pub const ProcessCreateData = extern struct
{
    system_data: u64,
    subsystem_data: u64,
    user_data: u64,
    subsystem_ID: u8,
};

const ExecutableState = enum(u8)
{
    not_loaded = 0,
    failed_to_load = 1,
    loaded = 2,
};

pub const Process = extern struct
{
    // @TODO: maybe turn into a pointer
    address_space: *AddressSpace,
    message_queue: kernel.MessageQueue,
    handle_table: object.Handle.Table,

    threads: LinkedList(Thread),
    threads_mutex: Mutex,

    executable_node: ?*Node,
    executable_name: [32]u8,
    data: ProcessCreateData,
    permissions: Process.Permission,
    creation_flags: Process.CreationFlags,
    type: Process.Type,

    id: u64,
    handle_count: Volatile(u64),
    all_item: LinkedList(Process).Item,

    crash_mutex: Mutex,
    crash_reason: CrashReason,
    crashed: bool,

    all_threads_terminated: bool,
    block_shutdown: bool,
    prevent_new_threads: bool,
    exit_status: i32,
    killed_event: Event,

    executable_state: ExecutableState,
    executable_start_request: bool,
    executable_load_attempt_complete: Event,
    executable_main_thread: ?*Thread,

    cpu_time_slices: u64,
    idle_time_slices: u64,
    
    pub const Type = enum(u32)
    {
        normal,
        kernel,
        desktop,
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

    pub const CreationFlags = Bitflag(enum(u32)
        {
            paused = 0,
        });

    pub fn spawn(process_type: Process.Type) ?*Process
    {
        if (kernel.scheduler.shutdown.read_volatile()) return null;

        const process = if (process_type == .kernel) &kernel.process else (@intToPtr(?*Process, kernel.scheduler.process_pool.add(@sizeOf(Process))) orelse return null);

        process.address_space = if (process_type == .kernel) &kernel.address_space else (@intToPtr(?*AddressSpace, kernel.scheduler.address_space_pool.add(@sizeOf(Process))) orelse 
            {
                kernel.scheduler.process_pool.remove(@ptrToInt(process));
                return null;
            });

        process.id = @atomicRmw(@TypeOf(kernel.scheduler.next_process_id), &kernel.scheduler.next_process_id, .Add, 1, .SeqCst);
        process.address_space.reference_count.write_volatile(1);
        process.all_item.value = process;
        process.handle_count.write_volatile(1);
        process.handle_table.process = process;
        process.permissions = Process.Permission.all();
        process.type = process_type;

        if (process_type == .kernel)
        {
            _ = kernel.EsCRTstrcpy(@ptrCast([*:0]u8, &process.executable_name), "Kernel");
            kernel.scheduler.all_processes.insert_at_end(&process.all_item);
        }

        return process;
    }

    pub fn crash(self: *Process, crash_reason: *CrashReason) callconv(.C) void
    {
        assert(arch.get_current_thread().?.process == self);
        if (self == &kernel.process) kernel.panic("kernel process has crashed");
        if (self.type != .normal) kernel.panic("A critical process has crashed");

        var pause_process = false;
        _ = self.crash_mutex.acquire();

        if (!self.crashed)
        {
            self.crashed = true;
            pause_process = true;
            // @Log
            self.crash_reason = crash_reason.*;
            if (!kernel.scheduler.shutdown.read_volatile())
            {
                // Send message to desktop
            }
        }

        self.crash_mutex.release();

        if (pause_process)
        {
            self.pause(false);
        }
    }

    pub fn pause(self: *Process, resume_after: bool) callconv(.C) void
    {
        _ = self.threads_mutex.acquire();
        var maybe_thread_item = self.threads.first;

        while (maybe_thread_item) |thread_item|
        {
            const thread = thread_item.value.?;
            maybe_thread_item = thread_item.next;
            ThreadPause(thread, resume_after);
        }

        self.threads_mutex.release();
    }
};

pub const AsyncTask = extern struct
{
    item: SimpleList,
    callback: u64, // ?Callback

    comptime
    {
        assert(@sizeOf(AsyncTask) == @sizeOf(SimpleList) + 8);
    }

    pub const Callback = fn (*@This()) void;

    pub fn register(self: *@This(), callback: Callback) void
    {
        assert(@ptrToInt(callback) != 0);
        kernel.scheduler.async_task_spinlock.acquire();
        if (self.callback == 0)
        {
            self.callback = @ptrToInt(callback);
            arch.get_local_storage().?.async_task_list.insert(&self.item, false);
        }
        kernel.scheduler.async_task_spinlock.release();
    }
};




export fn KThreadTerminate() callconv(.C) void
{
    thread_exit(arch.get_current_thread().?);
}

export fn ProcessKill(process: *Process) callconv(.C) void
{
    if (process.handle_count.read_volatile() == 0) kernel.panic("process is on the all process list but there are no handles in it");

    _ = kernel.scheduler.active_process_count.atomic_fetch_add(1);

    _ = kernel.scheduler.all_processes_mutex.acquire();
    kernel.scheduler.all_processes.remove(&process.all_item);
    
    if (kernel.pmm.next_process_to_balance == process)
    {
        kernel.pmm.next_process_to_balance = if (process.all_item.next) |next| next.value else null;
        kernel.pmm.next_region_to_balance = null;
        kernel.pmm.balance_resume_position = 0;
    }

    kernel.scheduler.all_processes_mutex.release();

    kernel.scheduler.dispatch_spinlock.acquire();
    process.all_threads_terminated = true;
    kernel.scheduler.dispatch_spinlock.release();
    _ = process.killed_event.set(true);
    process.handle_table.destroy();
    process.address_space.destroy();
}

export fn ThreadPause(thread: *Thread, resume_after: bool) callconv(.C) void
{
    kernel.scheduler.dispatch_spinlock.acquire();

    if (thread.paused.read_volatile() == !resume_after) return;

    thread.paused.write_volatile(!resume_after);

    if (!resume_after and thread.terminatable_state.read_volatile() == .terminatable)
    {
        if (thread.state.read_volatile() == .active)
        {
            if (thread.executing.read_volatile())
            {
                if (thread == arch.get_current_thread())
                {
                    kernel.scheduler.dispatch_spinlock.release();

                    arch.fake_timer_interrupt();

                    if (thread.paused.read_volatile()) kernel.panic("current thread incorrectly resumed");
                }
                else
                {
                    arch.IPI.send_yield(thread);
                }
            }
            else
            {
                thread.item.remove_from_list();
                kernel.scheduler.add_active_thread(thread, false);
            }
        }
    }
    else if (resume_after and thread.item.list == &kernel.scheduler.paused_threads)
    {
        kernel.scheduler.paused_threads.remove(&thread.item);
        kernel.scheduler.add_active_thread(thread, false);
    }

    kernel.scheduler.dispatch_spinlock.release();
}



export fn AsyncTaskThread() callconv(.C) void
{
    const local = arch.get_local_storage().?;

    while (true)
    {
        if (local.async_task_list.next_or_first) |first|
        {
            kernel.scheduler.async_task_spinlock.acquire();
            const item = first;
            const task = @fieldParentPtr(AsyncTask, "item", item);
            const callback = @intToPtr(?AsyncTask.Callback, task.callback) orelse unreachable;
            task.callback = 0;
            local.in_async_task = true;
            item.remove();
            kernel.scheduler.async_task_spinlock.release();
            callback(task);
            Thread.SetTemporaryAddressSpace(null);
            local.in_async_task = false;
        }
        else
        {
            arch.fake_timer_interrupt();
        }
    }
}

pub fn start_desktop_process() callconv(.C) void
{
    const result = process_start_with_something(kernel.desktop_process);
    assert(result);
}

const ProcessStartupInformation = extern struct
{
    is_desktop: bool,
    is_bundle: bool,
    application_start_address: u64,
    tls_image_start: u64,
    tls_image_byte_count: u64,
    tls_byte_count: u64,
    timestamp_ticks_per_ms: u64,
    global_data_region: u64,
    process_create_data: ProcessCreateData,
};


// ProcessStartWithNode
export fn process_start_with_something(process: *Process) bool
{
    kernel.scheduler.dispatch_spinlock.acquire();

    if (process.executable_start_request)
    {
        kernel.scheduler.dispatch_spinlock.release();
        return false;
    }

    process.executable_start_request = true;
    kernel.scheduler.dispatch_spinlock.release();

    if (!process.address_space.init()) return false;

    if (kernel.scheduler.all_processes_terminated_event.poll())
    {
        kernel.panic("all process terminated event was set");
    }

    process.block_shutdown = true;
    _ = kernel.scheduler.active_process_count.atomic_fetch_add(1);
    _ = kernel.scheduler.block_shutdown_process_count.atomic_fetch_add(1);

    _ = kernel.scheduler.all_processes_mutex.acquire();
    kernel.scheduler.all_processes.insert_at_end(&process.all_item);
    const load_executable_thread = Thread.spawn(arch.GetProcesssLoadDesktopExecutableAddress(), 0, Thread.Flags.empty(), process, 0);
    kernel.scheduler.all_processes_mutex.release();

    if (load_executable_thread) |thread|
    {
        object.close_handle(thread, 0);
        _ = process.executable_load_attempt_complete.wait();
        if (process.executable_state == .failed_to_load) return false;
        serial.write("Loaded executable...\n");
        return true;
    }
    else
    {
        object.close_handle(process, 0);
        return false;
    }
}

export fn ProcessLoadDesktopExecutable() callconv(.C) void
{
    const process = arch.get_current_thread().?.process.?;
    var exe = zeroes(files.LoadedExecutable);
    exe.is_desktop = true;
    const result = files.LoadDesktopELF(&exe);
    if (result != kernel.ES_SUCCESS) kernel.panic("Failed to load desktop executable");

    const startup_information = @intToPtr(?*ProcessStartupInformation, process.address_space.allocate_standard(@sizeOf(ProcessStartupInformation), Region.Flags.empty(), 0, true)) orelse kernel.panic("Can't allocate startup information");
    startup_information.is_desktop = true;
    startup_information.is_bundle = false;
    startup_information.application_start_address = exe.start_address;
    startup_information.tls_image_start = exe.tls_image_start;
    startup_information.tls_image_byte_count = exe.tls_image_byte_count;
    startup_information.tls_byte_count = exe.tls_byte_count;
    startup_information.timestamp_ticks_per_ms = arch.timeStampTicksPerMs;
    startup_information.process_create_data = process.data;
    
    var thread_flags = Thread.Flags.from_flag(.userland);
    if (process.creation_flags.contains(.paused)) thread_flags = thread_flags.or_flag(.paused);
    process.executable_state = .loaded;
    process.executable_main_thread = Thread.spawn(exe.start_address, @ptrToInt(startup_information), thread_flags, process, 0) orelse kernel.panic("Couldn't create main thread for executable");
    _ = process.executable_load_attempt_complete.set(false);
}

export fn thread_exit(thread: *Thread) callconv(.C) void
{
    kernel.scheduler.dispatch_spinlock.acquire();

    var yield = false;
    const was_terminating = thread.terminating.read_volatile();
    if (!was_terminating)
    {
        thread.terminating.write_volatile(true);
        thread.paused.write_volatile(false);
    }

    if (thread == arch.get_current_thread())
    {
        thread.terminatable_state.write_volatile(.terminatable);
        yield = true;
    }
    else if (!was_terminating and !thread.executing.read_volatile())
    {
        switch (thread.terminatable_state.read_volatile())
        {
            .terminatable =>
            {
                if (thread.state.read_volatile() != .active) kernel.panic("terminatable thread non-active");

                thread.item.remove_from_list();
                thread.kill_async_task.register(Thread.kill);
                yield = true;
            },
            .user_block_request =>
            {
                const thread_state = thread.state.read_volatile();
                if (thread_state == .waiting_mutex or thread_state == .waiting_event) kernel.scheduler.unblock_thread(thread, null);
            },
            else => {}
        }
    }

    kernel.scheduler.dispatch_spinlock.release();
    if (yield) arch.fake_timer_interrupt();
}

pub export fn process_exit(process: *Process, status: i32) callconv(.C) void
{
    _ = process.threads_mutex.acquire();

    process.exit_status = status;
    process.prevent_new_threads = true;

    const current_thread = arch.get_current_thread().?;
    const is_current_process = process == current_thread.process;
    var found_current_thread = false;
    var maybe_thread_item = process.threads.first;

    while (maybe_thread_item) |thread_item|
    {
        const thread = thread_item.value.?;
        maybe_thread_item = thread_item.next;

        if (thread != current_thread)
        {
            thread_exit(thread);
        }
        else if (is_current_process)
        {
            found_current_thread = true;
        }
        else
        {
            kernel.panic("found current thread in the wrong process");
        }
    }

    process.threads_mutex.release();

    if (!found_current_thread and is_current_process) kernel.panic("could not find current thread in the current process")
    else if (is_current_process)
    {
        thread_exit(current_thread);
    }
}
