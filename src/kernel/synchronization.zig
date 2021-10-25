pub const Spinlock = struct
{
    state: u8,
    owner_cpu: u8,
    interrupts_enabled: bool,

    pub fn acquire(self: *Spinlock) void
    {
        _ = self;
    }

    pub fn release(self: *Spinlock) void
    {
        _ = self;
    }
};
