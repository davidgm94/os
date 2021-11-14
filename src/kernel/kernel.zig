const Kernel = @This();

pub const Arch = @import("arch.zig");
pub const Drivers = @import("../drivers.zig");
pub const Logger = @import("logger.zig");
pub const Memory = @import("memory.zig");
pub const Scheduler = @import("scheduler.zig");
pub usingnamespace @import("synchronization.zig");

pub const panic = Logger.panic;
pub const panic_lf = Logger.panic_lockfree;
pub const log_lf = Logger.log_lockfree;

pub var scheduler: Scheduler = undefined;
pub var memory_space: Memory.Space = undefined;
pub var process: *Scheduler.Process = undefined;
pub var physical_memory_allocator: Memory.Physical.Allocator = undefined;

pub var core_memory_space: Memory.Space = undefined;
pub var core_heap: Memory.Heap = undefined;

pub var fixed_heap: Memory.Heap = undefined;

pub const CPULocalStorage = extern struct
{
    cpu: *Kernel.Arch.CPU,
    processor_ID: u8, // Scheduler ID
};

pub fn init() void
{
    Kernel.process = scheduler.prepare_process(.kernel) orelse unreachable;
    Memory.init();
    Arch.init();
}
