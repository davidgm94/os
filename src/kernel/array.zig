const Kernel = @import("kernel.zig");
const Heap = Kernel.Memory.Heap;

pub fn Array(comptime T: type) type
{
    return struct
    {
        const Self = @This();
        
        items: []T,
        heap: *Heap,

        pub fn zero_init() Array(T)
        {
            return .{ .items = &[_]T{}, .heap = undefined, };
        }

        pub fn insert(self: *Self, item: T, position: u64) ?*T
        {
            _ = position;
            _ = item;
            _ = self;
            Kernel.Arch.CPU_stop();
        }

        pub fn delete_many(self: *Self, position: u64, count: u64) void
        {
            _ = self; _ = position; _ = count;
            Kernel.Arch.CPU_stop();
        }
    };
}
