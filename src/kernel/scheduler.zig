const std = @import("std");
const ArrayList = std.ArrayList;
const Kernel = @import("kernel.zig");

const Self = @This();

// substitute for real dynamic data structure
processes: [16]Process,
kernel_process: Process,
next_process_id: u64,
dispatch_spinlock: Kernel.Spinlock,

shutdown: bool,
panic: bool,

pub const Thread = struct
{
    process: *Process,
    temporary_address_space: ?*volatile Kernel.Memory.Space,
    is_page_generator: bool,
    is_kernel_thread: bool,
};

pub fn init(self: *Self) void
{
    // @Spinlock
    self.kernel_process = Process
    {
        .id = self.next_process_id,
        .virtual_memory_space = &Kernel.kernel_memory_space,
        .type = .kernel,
        .name = "kernel",
        .permissions = Process.Permissions.all,
    };

    self.next_process_id += 1;
}

pub const Process = struct
{
    id: u64,
    address_space: *Kernel.Memory.Space,
    permissions: u64,
    type: Type,
    name: []const u8, // @TODO: should the process own the memory for the name?

    const Permissions = enum(u64)
    {
        none = 0,
        const all: u64 = std.math.maxInt(u64);
    };

    const Type = enum
    {
        normal,
        kernel,
    };
};

pub fn prepare_process(self: *Self, comptime process_type: Process.Type) ?*Process
{
    if (self.shutdown) return null;

    var process =
        if (process_type == .kernel) &self.kernel_process
        else Kernel.Arch.CPU_stop();

    process.address_space = 
        if (process_type == .kernel)
            &Kernel.memory_space
        else
            Kernel.Arch.CPU_stop();

    process.id = @atomicRmw(u64, &self.next_process_id, .Add, 1, .SeqCst);
    //process.address_space.reference_count = 1;
    process.type = process_type;
    process.permissions = Process.Permissions.all;

    if (process_type == .kernel)
    {
        process.name = "Kernel";
    }

    return process;
}
