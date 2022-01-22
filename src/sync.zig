const kernel = @import("kernel.zig");

const panic_raw = kernel.panic_raw;

const TODO = kernel.TODO;

const max_wait_count = kernel.max_wait_count;
const no_timeout = kernel.wait_no_timeout;

const Volatile = kernel.Volatile;

const LinkedList = kernel.LinkedList;

const Thread = kernel.Scheduler.Thread;
const Timer = kernel.Scheduler.Timer;

const get_current_thread = kernel.Arch.get_current_thread;
const LocalStorage = kernel.Arch.LocalStorage;
const interrupts = kernel.Arch.Interrupt;
const fake_timer_interrupt = kernel.Arch.fake_timer_interrupt;

const std = @import("std");
const zeroes = std.mem.zeroes;

pub const Mutex = struct
{
    owner: ?*align(1) volatile Thread,
    blocked_threads: LinkedList(Thread),

    pub fn acquire(self: *@This()) bool
    {
        if (kernel.scheduler.panic.read_volatile()) return false;

        const current_thread = blk:
        {
            const thread_address = addr_block:
            {
                if (get_current_thread()) |current_thread|
                {
                    if (current_thread.terminatable_state.read_volatile() == .terminatable)
                    {
                        panic_raw("thread is terminatable\n");
                    }

                    if (self.owner == current_thread)
                    {
                        panic_raw("Attempt to acquire a mutex owned by current thread already acquired\n");
                    }

                    break :addr_block @ptrToInt(current_thread);
                }
                else
                {
                    break :addr_block 1;
                }
            };

            break :blk @intToPtr(*align(1) Thread, thread_address);
        };

        while (true)
        {
            kernel.scheduler.dispatch_spinlock.acquire();
            if (self.owner == null) self.owner = current_thread;
            kernel.scheduler.dispatch_spinlock.release();

            if (self.owner == null) break;

            @fence(.SeqCst);

            if (LocalStorage.get()) |local_storage|
            {
                if (local_storage.scheduler_ready)
                {
                    if (current_thread.state.read_volatile() != .active)
                    {
                        panic_raw("Attempting to wait on a mutex in a non-active thread\n");
                    }

                    current_thread.blocking.mutex = self;
                    @fence(.SeqCst);

                    current_thread.state.write_volatile(.waiting_mutex);

                    kernel.scheduler.dispatch_spinlock.acquire();
                    const spin = blk:
                    {
                        if (self.owner) |owner|
                        {
                            const boolean = owner.executing;
                            break :blk boolean.read_volatile();
                        }
                        break :blk false;
                    };

                    kernel.scheduler.dispatch_spinlock.release();

                    if (!spin and current_thread.blocking.mutex.?.owner != null)
                    {
                        fake_timer_interrupt();
                    }

                    while ((!current_thread.terminating.read_volatile() or current_thread.terminatable_state.read_volatile() != .user_block_request) and self.owner != null)
                    {
                        current_thread.state.write_volatile(.waiting_mutex);
                    }

                    current_thread.state.write_volatile(.active);

                    if (current_thread.terminating.read_volatile() and current_thread.terminatable_state.read_volatile() == .user_block_request)
                    {
                        // mutex was not acquired because the thread is terminating
                        return false;
                    }
                }
            }
        }

        @fence(.SeqCst);

        if (self.owner != current_thread)
        {
            panic_raw("Invalid owner thread\n");
        }

        return true;
    }

    pub fn release(self: *@This()) void
    {
        if (kernel.scheduler.panic.read_volatile()) return;

        self.assert_locked();
        const maybe_current_thread = get_current_thread();
        kernel.scheduler.dispatch_spinlock.acquire();

        if (maybe_current_thread) |current_thread|
        {
            if (@cmpxchgStrong(@TypeOf(self.owner), &self.owner, current_thread, null, .SeqCst, .SeqCst) != null)
            {
                panic_raw("Invalid owner thread\n");
            }
        }
        else self.owner = null;

        const preempt = self.blocked_threads.count != 0;
        if (kernel.scheduler.started.read_volatile())
        {
            TODO();
        }

        kernel.scheduler.dispatch_spinlock.release();
        @fence(.SeqCst);

        if (preempt) fake_timer_interrupt();
    }

    pub fn assert_locked(self: *@This()) void
    {
        const current_thread = blk:
        {
            if (get_current_thread()) |thread|
            {
                break :blk @ptrCast(*align(1) Thread, thread);
            }
            else
            {
                break :blk @intToPtr(*align(1) Thread, 1);
            }
        };

        if (self.owner != current_thread)
        {
            panic_raw("Mutex not correctly acquired\n");
        }
    }
};

pub const Spinlock = struct
{
    state: Volatile(u8),
    owner_cpu: Volatile(u8),
    interrupts_enabled: Volatile(bool),

    pub fn acquire(self: *@This()) void
    {
        if (kernel.scheduler.panic.read_volatile()) return;

        const interrupts_enabled = interrupts.are_enabled();
        interrupts.disable();

        const maybe_local_storage = LocalStorage.get();
        if (maybe_local_storage) |local_storage|
        {
            local_storage.spinlock_count += 1;
        }

        _ = @cmpxchgStrong(@TypeOf(self.state.value), &self.state.value, 0, 1, .SeqCst, .SeqCst);
        @fence(.SeqCst);
        self.interrupts_enabled.write_volatile(interrupts_enabled);

        if (maybe_local_storage) |local_storage|
        {
            // @Unsafe
            self.owner_cpu.write_volatile(@intCast(u8, local_storage.processor_ID));
        }
    }

    pub fn release(self: *@This()) void
    {
        self.release_ex(false);
    }

    pub fn release_ex(self: *@This(), comptime force: bool) void
    {
        if (kernel.scheduler.panic.read_volatile()) return;

        const maybe_local_storage = LocalStorage.get();
        if (maybe_local_storage) |local_storage|
        {
            local_storage.spinlock_count -= 1;
        }

        if (force)
        {
            self.assert_locked();
        }

        const were_interrupts_enabled = self.interrupts_enabled.read_volatile();
        @fence(.SeqCst);
        self.state.write_volatile(0);
        
        if (were_interrupts_enabled) interrupts.enable();
    }

    pub fn assert_locked(self: *@This()) void
    {
        if (kernel.scheduler.panic.read_volatile()) return;

        if (self.state.read_volatile() == 0 or interrupts.are_enabled())
        {
            panic_raw("Spinlock not correctly acquired\n");
        }
    }
};

pub const WriterLock = struct
{
    blocked_threads: LinkedList(Thread),
    state: Volatile(i64),

    pub fn take(self: *@This(), write: bool) bool
    {
        return self.take_extended(write, false);
    }

    pub fn take_extended(self: *@This(), write: bool, poll: bool) bool
    {
        var done = false;
        const maybe_current_thread = get_current_thread();
        if (maybe_current_thread) |thread|
        {
            thread.blocking.writer.lock = self;
            thread.blocking.writer.type = write;
            @fence(.SeqCst);
        }

        while (true)
        {
            kernel.scheduler.dispatch_spinlock.acquire();

            if (write)
            {
                if (self.state.read_volatile() == 0)
                {
                    self.state.write_volatile(-1);
                    done = true;
                }
            }
            else
            {
                if (self.state.read_volatile() >= 0)
                {
                    self.state.increment();
                    done = true;
                }
            }

            kernel.scheduler.dispatch_spinlock.release();

            if (poll or done) break
            else
            {
                if (maybe_current_thread) |thread|
                {
                    thread.state.write_volatile(.waiting_writer_lock);
                    fake_timer_interrupt();
                    thread.state.write_volatile(.active);
                }
                else
                {
                    panic_raw("scheduler not ready yet\n");
                }
            }
        }

        return done;
    }

    pub fn return_lock(self: *@This(), write: bool) void
    {
        kernel.scheduler.dispatch_spinlock.acquire();

        const lock_state = self.state.read_volatile();
        if (lock_state == -1)
        {
            if (!write) panic_raw("attempt to return shared access to an exclusively owned lock");

            self.state.write_volatile(0);
        }
        else if (lock_state == 0)
        {
            panic_raw("attempt to return access to an unowned lock");
        }
        else
        {
            if (write) panic_raw("attempting to return exclusive access to a shared lock");

            self.state.decrement();
        }

        if (self.state.read_volatile() == 0)
        {
            kernel.scheduler.notify_object(&self.blocked_threads, true);
        }

        kernel.scheduler.dispatch_spinlock.release();
    }

    pub fn assert_exclusive(self: *@This()) void
    {
        const lock_state = self.state.read_volatile();
        if (lock_state == 0) panic_raw("unlocked")
        else if (lock_state > 0) panic_raw("shared mode");
    }

    pub fn assert_shared(self: *@This()) void
    {
        const lock_state = self.state.read_volatile();
        if (lock_state == 0) panic_raw("unlocked")
        else if (lock_state < 0) panic_raw("exclusive mode");
    }

    pub fn assert_locked(self: *@This()) void
    {
        if (self.state.read_volatile() == 0) panic_raw("unlocked");
    }

    pub const shared = false;
    pub const exclusive = true;
};

pub const Event = struct
{
    auto_reset: Volatile(bool),
    state: Volatile(u64),
    blocked_threads: LinkedList(Thread),
    handle_count: Volatile(u64),

    /// already_set default = false
    pub fn set(self: *@This(), already_set: bool) bool
    {
        if (self.state.read_volatile() != 0 and !already_set)
        {
            // log error
        }

        kernel.scheduler.dispatch_spinlock.acquire();

        var unblocked_threads = Volatile(bool) { .value = false };

        if (self.state.read_volatile() == 0)
        {
            self.state.write_volatile(@boolToInt(true));

            if (kernel.scheduler.started.read_volatile())
            {
                TODO();
            }
        }

        kernel.scheduler.dispatch_spinlock.release();
        return unblocked_threads.read_volatile();
    }

    pub fn reset(self: *@This()) void
    {
        if (self.blocked_threads.first != null and self.state.read_volatile() != 0)
        {
            // log error
        }

        self.state.write_volatile(@boolToInt(false));
    }

    pub fn poll(self: *@This()) bool
    {
        _ = self; TODO();
    }

    pub fn wait(self: *@This()) bool
    {
        return self.wait_extended(no_timeout);
    }
    
    pub fn wait_extended(self: *@This(), timeout_ms: u64) bool
    {
        var events: [2]*Event = undefined;
        events[0] = self;

        if (timeout_ms == no_timeout)
        {
            const index = wait_multiple(events[0..1]);
            return index == 0;
        }
        else
        {
            var timer: Timer = undefined;
            std.mem.set(u8, @ptrCast([*]u8, &timer)[0..@sizeOf(Timer)], 0);
            timer.set(timeout_ms);
            events[1] = &timer.event;
            const index = wait_multiple(events[0..2]);
            timer.remove();
            return index == 0;
        }
    }

    fn wait_multiple(events: []*Event) u64
    {
        if (events.len > max_wait_count) panic_raw("count too high")
        else if (events.len == 0) panic_raw("count 0")
        else if (!interrupts.are_enabled()) panic_raw("timer with interrupts disabled");

        const thread = get_current_thread().?;
        thread.blocking.event.count = events.len;

        var event_items = zeroes([512]LinkedList(Thread).Item);
        thread.blocking.event.items = &event_items;
        defer thread.blocking.event.items = null;

        for (thread.blocking.event.items.?[0..thread.blocking.event.count]) |*event_item, i|
        {
            event_item.value = thread;
            thread.blocking.event.array[i] = events[i];
        }

        while (!thread.terminating.read_volatile() or thread.terminatable_state.read_volatile() != .user_block_request)
        {
            for (events) |event, i|
            {
                if (event.auto_reset.read_volatile())
                {
                    if (event.state.read_volatile() != 0)
                    {
                        thread.state.write_volatile(.active);
                        const result = event.state.atomic_compare_and_swap(0, 1);
                        if (result) |resultu|
                        {
                            if (resultu != 0) return i;
                        }
                        else
                        {
                            return i;
                        }

                        thread.state.write_volatile(.waiting_event);
                    }
                }
                else
                {
                    if (event.state.read_volatile() != 0)
                    {
                        thread.state.write_volatile(.active);
                        return i;
                    }
                }
            }

            fake_timer_interrupt();
        }
        
        return std.math.maxInt(u64);
    }
};
