const Kernel = @import("kernel.zig");

pub const Spinlock = struct
{
    const Self = @This();

    state: u8,
    owner_cpu: u8,
    interrupts_enabled: bool,

    pub fn acquire(self: *volatile Self) void
    {
        if (Kernel.scheduler.panic) return;

        const interrupts_enabled = Kernel.Arch.are_interrupts_enabled();
        Kernel.Arch.disable_interrupts();

        var maybe_cpu_storage = Kernel.Arch.get_local_storage();
        if (maybe_cpu_storage) |cpu_local_storage| cpu_local_storage.spinlock_count += 1;

        while (true)
        {
            if (@cmpxchgStrong(u8, &self.state, 0, 1, .SeqCst, .SeqCst)) |old_value|
            {
                if (old_value == 0) break;
            }
        }
        @fence(.SeqCst);

        self.interrupts_enabled = interrupts_enabled;

        if (maybe_cpu_storage) |storage|
        {
            self.owner_cpu = storage.processor_ID;
        }
    }

    pub fn release(self: *volatile Self, force: bool) void
    {
        if (Kernel.scheduler.panic) return;

        if (Kernel.Arch.get_local_storage()) |storage| storage.spinlock_count -= 1;

        if (!force)
        {
            self.assert_locked();
        }

        const were_interrupts_enabled = self.interrupts_enabled;
        @fence(.SeqCst);
        self.state = 0;

        if (were_interrupts_enabled) Kernel.Arch.enable_interrupts();
    }

    pub fn assert_locked(self: *volatile Self) void
    {
        if (Kernel.scheduler.panic) return;
        if (self.state == 0 or Kernel.Arch.are_interrupts_enabled())
        {
            Kernel.Arch.CPU_stop();
        }
    }
};

pub const Mutex = struct
{
    const Self = @This();

    owner: ?*Kernel.Scheduler.Thread,

    const Result = enum
    {
        not_acquired,
        acquired,
    };

    fn acquire(self: *volatile Self) void
    {
        if (Kernel.scheduler.panic) return .not_acquired;

        var current_thread: *Kernel.Scheduler.Thread = undefined;
        if (Kernel.Arch.thread_get_current()) |_current_thread|
        {
            current_thread = _current_thread;
            if (current_thread.terminatable_state) Kernel.Arch.CPU_stop();

            if (self.owner) |mutex_owner| if (mutex_owner == current_thread) Kernel.Arch.CPU_stop();
        }
        else
        {
            current_thread = @intToPtr(*Kernel.Scheduler.Thread, 1);
        }

        if (!Kernel.Arch.are_interrupts_enabled()) Kernel.Arch.CPU_stop();

        while (true)
        {
            Kernel.scheduler.dispatch_spinlock.acquire();
            if (self.owner == null)
            {
                self.owner = current_thread;
            }
            Kernel.scheduler.dispatch_spinlock.release();

            @fence(.SeqCst);

            if (Kernel.Arch.get_local_storage()) |local_storage|
            {
                if (local_storage.scheduler_ready)
                {
                    if (current_thread.state != .active)
                    {
                        Kernel.Arch.CPU_stop();

                        current_thread.blocking.mutex = self;
                        @fence(.SeqCst);

                        current_thread.state = .waiting_mutex;

                        Kernel.scheduler.dispatch_spinlock.acquire();
                        const spin = self.owner != null and self.owner.?.executing;
                        Kernel.scheduler.dispatch_spinlock.release();

                        if (!spin and current_thread.blocking.mutex.owner)
                        {
                            Kernel.Arch.CPU_stop();
                        }

                        while ((!current_thread.terminating or current_thread.terminatable_state != .user_block_request) and self.owner != null)
                        {
                            current_thread.state = .waiting_mutex;
                        }

                        current_thread.state = .active;

                        if (current_thread.terminating and current_thread.terminatable_state == .user_block_request)
                        {
                            return .not_acquired;
                        }
                    }
                }
            }

            @fence(.SeqCst);

            if (self.owner != current_thread)
            {
                Kernel.Arch.CPU_stop();
            }

            return .acquired;
        }
    }
};
