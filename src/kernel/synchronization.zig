const Kernel = @import("kernel.zig");

pub const Spinlock = struct
{
    state: u8,
    owner_cpu: u8,
    interrupts_enabled: bool,

    pub fn acquire(self: *volatile Spinlock) void
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

    pub fn release(self: *volatile Spinlock, force: bool) void
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

    pub fn assert_locked(self: *volatile Spinlock) void
    {
        if (Kernel.scheduler.panic) return;
        if (self.state == 0 or Kernel.Arch.are_interrupts_enabled())
        {
            Kernel.Arch.CPU_stop();
        }
    }
};
