pub const Arch = @import("arch.zig");
pub const Logger = @import("logger.zig");
pub const Memory = @import("memory.zig");
pub const Scheduler = @import("scheduler.zig");
pub const Synchronization = @import("synchronization.zig");

pub const panic = Logger.panic;
pub const panic_lf = Logger.panic_lockfree;
pub const log_lf = Logger.log_lockfree;
pub const Spinlock = Synchronization.Spinlock;

pub var scheduler: Scheduler = undefined;
pub var kernel_memory_space: Memory.Space = undefined;
pub var core_memory_space: Memory.Space = undefined;
pub var physical_memory_allocator: Memory.Physical.Allocator = undefined;

pub const LocalStorage = extern struct
{
    foo: u32,
};

pub fn init() void
{
    scheduler.init();
}
