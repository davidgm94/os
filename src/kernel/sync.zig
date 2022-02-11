const kernel = @import("kernel.zig");
const zeroes = kernel.zeroes;
const Volatile = kernel.Volatile;
const LinkedList = kernel.LinkedList;

const arch = kernel.arch;

const Thread = kernel.scheduling.Thread;
const Timer = kernel.scheduling.Timer;

const std = @import("std");

pub const Spinlock = extern struct
{
    state: Volatile(u8),
    owner_cpu: Volatile(u8),
    interrupts_enabled: Volatile(bool),

    pub fn acquire(self: *@This()) void
    {
        if (kernel.scheduler.panic.read_volatile()) return;

        const interrupts_enabled = arch.are_interrupts_enabled();
        arch.disable_interrupts();

        const maybe_local_storage = arch.get_local_storage();
        if (maybe_local_storage) |local_storage|
        {
            local_storage.spinlock_count += 1;
        }

        _ = self.state.atomic_compare_and_swap(0, 1);
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

        const maybe_local_storage = arch.get_local_storage();
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
        
        if (were_interrupts_enabled) arch.enable_interrupts();
    }

    pub fn assert_locked(self: *@This()) void
    {
        if (kernel.scheduler.panic.read_volatile()) return;

        if (self.state.read_volatile() == 0 or arch.are_interrupts_enabled())
        {
            kernel.panic("Spinlock not correctly acquired\n");
        }
    }
};

pub const Mutex = extern struct
{
    owner: ?* align(1) volatile Thread,
    blocked_threads: LinkedList(Thread),

    pub fn acquire(self: *@This()) bool
    {
        if (kernel.scheduler.panic.read_volatile()) return false;

        var current_thread = blk:
        {
            const thread_address = addr_block:
            {
                if (arch.get_current_thread()) |current_thread|
                {
                    if (current_thread.terminatable_state.read_volatile() == .terminatable)
                    {
                        kernel.panic("thread is terminatable\n");
                    }

                    if (self.owner != null and self.owner == current_thread)
                    {
                        kernel.panic("Attempt to acquire a mutex owned by current thread already acquired\n");
                    }

                    break :addr_block @ptrToInt(current_thread);
                }
                else
                {
                    break :addr_block 1;
                }
            };

            break :blk @intToPtr(*volatile align(1) Thread, thread_address);
        };

        if (!arch.are_interrupts_enabled())
        {
            kernel.panic("trying to acquire a mutex with interrupts disabled");
        }

        while (true)
        {
            kernel.scheduler.dispatch_spinlock.acquire();
            const old = self.owner;
            if (old == null) self.owner = current_thread;
            kernel.scheduler.dispatch_spinlock.release();
            if (old == null) break;

            @fence(.SeqCst);

            if (arch.get_local_storage()) |local_storage|
            {
                if (local_storage.scheduler_ready)
                {
                    if (current_thread.state.read_volatile() != .active)
                    {
                        kernel.panic("Attempting to wait on a mutex in a non-active thread\n");
                    }

                    current_thread.blocking.mutex = self;
                    @fence(.SeqCst);

                    current_thread.state.write_volatile(.waiting_mutex);

                    kernel.scheduler.dispatch_spinlock.acquire();
                    const spin = 
                        if (self.owner) |owner| owner.executing.read_volatile()
                        else false;

                    kernel.scheduler.dispatch_spinlock.release();

                    if (!spin and current_thread.blocking.mutex.?.owner != null)
                    {
                        arch.fake_timer_interrupt();
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
            kernel.panic("Invalid owner thread\n");
        }

        return true;
    }

    pub fn release(self: *@This()) void
    {
        if (kernel.scheduler.panic.read_volatile()) return;

        self.assert_locked();
        const maybe_current_thread = arch.get_current_thread();
        kernel.scheduler.dispatch_spinlock.acquire();

        if (maybe_current_thread) |current_thread|
        {
            if (@cmpxchgStrong(?*align(1) volatile Thread, &self.owner, current_thread, null, .SeqCst, .SeqCst) != null)
            {
                kernel.panic("Invalid owner thread\n");
            }
        }
        else self.owner = null;

        const preempt = self.blocked_threads.count != 0;
        if (kernel.scheduler.started.read_volatile())
        {
            kernel.scheduler.notify_object(&self.blocked_threads, true, maybe_current_thread);
        }

        kernel.scheduler.dispatch_spinlock.release();
        @fence(.SeqCst);

        if (preempt) arch.fake_timer_interrupt();
    }

    pub fn assert_locked(self: *@This()) void
    {
        const current_thread = blk:
        {
            if (arch.get_current_thread()) |thread|
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
            kernel.panic("Mutex not correctly acquired\n");
        }
    }
};
pub const Event = extern struct
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
                if (self.blocked_threads.count != 0) unblocked_threads.write_volatile(true);
                kernel.scheduler.notify_object(&self.blocked_threads, !self.auto_reset.read_volatile(), null);
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
        if (self.auto_reset.read_volatile())
        {
            if (self.state.atomic_compare_and_swap(@boolToInt(true), @boolToInt(false))) |value|
            {
                return value != 0;
            }
            else
            {
                return true;
            }
        }
        else
        {
            return self.state.read_volatile() != 0;
        }
    }

    pub fn wait(self: *@This()) bool
    {
        return self.wait_extended(kernel.wait_no_timeout);
    }
    
    pub fn wait_extended(self: *@This(), timeout_ms: u64) bool
    {
        var events: [2]*Event = undefined;
        events[0] = self;

        if (timeout_ms == kernel.wait_no_timeout)
        {
            const index = wait_multiple(&events, 1);
            return index == 0;
        }
        else
        {
            var timer =  zeroes(Timer);
            timer.set(timeout_ms);
            events[1] = &timer.event;
            const index = wait_multiple(&events, 2);
            timer.remove();
            return index == 0;
        }
    }

    fn wait_multiple(event_ptr: [*]*Event, event_len: u64) u64
    {
        var events = event_ptr[0..event_len];
        if (events.len > kernel.max_wait_count) kernel.panic("count too high")
        else if (events.len == 0) kernel.panic("count 0")
        else if (!arch.are_interrupts_enabled()) kernel.panic("timer with interrupts disabled");

        const thread = arch.get_current_thread().?;
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

            arch.fake_timer_interrupt();
        }
        
        return std.math.maxInt(u64);
    }
};

pub const WriterLock = extern struct
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
        const maybe_current_thread = arch.get_current_thread();
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
                    arch.fake_timer_interrupt();
                    thread.state.write_volatile(.active);
                }
                else
                {
                    kernel.panic("scheduler not ready yet\n");
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
            if (!write) kernel.panic("attempt to return shared access to an exclusively owned lock");

            self.state.write_volatile(0);
        }
        else if (lock_state == 0)
        {
            kernel.panic("attempt to return access to an unowned lock");
        }
        else
        {
            if (write) kernel.panic("attempting to return exclusive access to a shared lock");

            self.state.decrement();
        }

        if (self.state.read_volatile() == 0)
        {
            kernel.scheduler.notify_object(&self.blocked_threads, true, null);
        }

        kernel.scheduler.dispatch_spinlock.release();
    }

    pub fn assert_exclusive(self: *@This()) void
    {
        const lock_state = self.state.read_volatile();
        if (lock_state == 0) kernel.panic("unlocked")
        else if (lock_state > 0) kernel.panic("shared mode");
    }

    pub fn assert_shared(self: *@This()) void
    {
        const lock_state = self.state.read_volatile();
        if (lock_state == 0) kernel.panic("unlocked")
        else if (lock_state < 0) kernel.panic("exclusive mode");
    }

    pub fn assert_locked(self: *@This()) void
    {
        if (self.state.read_volatile() == 0) kernel.panic("unlocked");
    }

    pub fn convert_exclusive_to_shared(self: *@This()) void
    {
        kernel.scheduler.dispatch_spinlock.acquire();
        self.assert_exclusive();
        self.state.write_volatile(1);
        kernel.scheduler.notify_object(&self.blocked_threads, true, null);
        kernel.scheduler.dispatch_spinlock.release();
    }

    pub const shared = false;
    pub const exclusive = true;
};
