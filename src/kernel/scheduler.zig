const std = @import("std");
const ArrayList = std.ArrayList;
const Kernel = @import("kernel.zig");

const Self = @This();

processes: ArrayList(Process),
kernel_process: Process,
lock: Kernel.Spinlock,
next_process_id: u64,

const Process = struct
{
    id: u64,
    virtual_memory_space: *Kernel.Memory.Space,
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
