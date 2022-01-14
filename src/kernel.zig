const kernel = @This();
const std = @import("std");
const assert = std.debug.assert;
const AtomicOrder = std.builtin.AtomicOrder;

pub const Arch = switch (@import("builtin").target.cpu.arch)
{
    .x86_64 => @import("x86_64.zig"),
    else => unreachable,
};

// Kernel object members
pub var arch: Arch = undefined;
pub var scheduler: Scheduler = undefined;
pub var process: Scheduler.Process = undefined;
pub var core: Core = undefined;
pub var physical_allocator: memory.Physical.Allocator = undefined;

pub const memory = @import("memory.zig");
pub const Scheduler = @import("scheduler.zig");
pub const sync = @import("sync.zig");

pub fn Volatile(comptime T: type) type
{
    return struct
    {
        value: T,

        pub fn read_volatile(self: *@This()) callconv(.Inline) T
        {
            return @ptrCast(*volatile T, &self.value).*;
        }

        pub fn write_volatile(self: *@This(), value: T) callconv(.Inline) void
        {
            @ptrCast(*volatile T, &self.value).* = value;
        }

        /// Only supported for integer types
        pub fn atomic_fetch_add(self: *@This(), value_to_be_added: T) callconv(.Inline) u64
        {
            return @atomicRmw(T, &self.value, .Add, value_to_be_added, .SeqCst);
        }
        
        pub fn increment(self: *@This()) void
        {
            self.write_volatile(self.read_volatile() + 1);
        }
    };
}

pub fn VolatilePointer(comptime T: type) type
{
    return struct
    {
        const Ptr = *volatile T;
        ptr: ?Ptr,

        pub fn overwrite_address(self: *@This(), address: ?*T) callconv(.Inline) void
        {
            self.ptr = @ptrCast(?Ptr, address);
        }

        pub fn dereference_volatile(self: *@This()) callconv(.Inline) T
        {
            assert(self.ptr != null);
            return self.ptr.?.*;
        }

        pub fn get_non_volatile(self: @This()) *T
        {
            return @ptrCast(*T, self.ptr.?);
        }
    };
}

pub fn UnalignedVolatilePointer(comptime T: type) type
{
    return struct
    {
        const Ptr = *volatile align(1)T;
        ptr: ?Ptr,

        pub fn overwrite_address(self: *@This(), address: ?Ptr) callconv(.Inline) void
        {
            self.ptr = address;
        }

        pub fn dereference_volatile(self: *@This()) callconv(.Inline) T
        {
            assert(self.ptr != null);
            return self.ptr.?.*;
        }
    };
}

pub fn Bitflag(comptime EnumT: type) type
{
    return struct
    {
        const IntType = std.meta.Int(.unsigned, @bitSizeOf(EnumT));
        const Enum = EnumT;

        bits: IntType,

        pub fn new(flags: anytype) callconv(.Inline) @This()
        {
            const flags_type = @TypeOf(flags);
            const result = comptime blk:
            {
                const fields = std.meta.fields(flags_type);
                if (fields.len > @bitSizeOf(EnumT)) @compileError("More flags than bits\n");

                var bits: IntType = 0;

                var field_i: u64 = 0;
                inline while (field_i < fields.len) : (field_i += 1)
                {
                    const field = fields[field_i];
                    const enum_value: EnumT = field.default_value.?;
                    bits |= 1 << @enumToInt(enum_value);
                }
                break :blk bits;
            };
            return @This() { .bits = result };
        }

        pub fn new_from_flag(comptime flag: EnumT) callconv(.Inline) @This()
        {
            const bits = 1 << @enumToInt(flag);
            return @This() { .bits = bits };
        }

        pub fn empty() callconv(.Inline) @This()
        {
            return @This()
            {
                .bits = 0,
            };
        }

        pub fn all() callconv(.Inline) @This()
        {
            var result = comptime blk:
            {
                var bits: IntType = 0;
                inline for (@typeInfo(EnumT).Enum.fields) |field|
                {
                    bits |= 1 << field.value;
                }
                break :blk @This()
                {
                    .bits = bits,
                };
            };
            return result;
        }

        pub fn is_empty(self: @This()) callconv(.Inline) bool
        {
            return self.bits == 0;
        }

        /// This assumes invalid values in the flags can't be set.
        pub fn is_all(self: @This()) callconv(.Inline) bool
        {
            return all().bits == self.bits;
        }

        pub fn contains(self: @This(), comptime flag: EnumT) callconv(.Inline) bool
        {
            return ((self.bits & (1 << @enumToInt(flag))) >> @enumToInt(flag)) != 0;
        }

        pub fn or_flag(self: @This(), comptime flag: EnumT) callconv(.Inline) @This()
        {
            const bits = self.bits | 1 << @enumToInt(flag);
            return @This() { .bits = bits };
        }
    };
}



pub const Core = struct
{
    address_space: memory.AddressSpace,
    regions: []memory.Region,
    region_commit_count: u64,
    heap: memory.Heap,
};

pub const Bitset = struct
{
};

pub fn AVLTree(comptime T: type) type
{
    return struct
    {
        const Tree = @This();
        const Key = u64;


        pub const SearchMode = enum
        {
            exact,
            smallest_above_or_equal,
            largest_below_or_equal,
        };

        pub const DuplicateKeyPolicy = enum
        {
            panic,
            allow,
            fail,
        };

        pub fn insert(self: *@This(), item: *Item, item_value: ?*T, key: Key, duplicate_key_policy: DuplicateKeyPolicy) bool
        {
            self.validate();
            
            if (item.tree != null)
            {
                panic_raw("item already in a tree\n");
            }

            item.tree = self;

            item.key = key;
            item.children[0] = null;
            item.children[1] = null;
            item.value = item_value;
            item.height = 1;

            _ = duplicate_key_policy;
            TODO();
            //var link = &self.root;
            //var parent: ?*Item = null;
            

            //while (true)
            //{
                //TODO();
            //}
        }

        fn validate(self: *@This()) void
        {
            _ = self;
            TODO();
        }

        pub const Item = struct
        {
            value: ?*T,
            children: [2]?*Item,
            parent: ?*Item,
            tree: ?*Tree,
            key: Key,
            height: i32,

            // self == tree root item
        };
    };
}

pub fn LinkedList(comptime T: type) type
{
    return struct
    {
        const Self = @This();

        first: ?*Item,
        last: ?*Item,
        count: u64,

        pub const Item = struct
        {
            previous: ?*Item,
            next: ?*Item,
            list: ?*Self,
            this: ?*T,
        };
    };
}


pub const Pool = struct
{
};

pub const Range = struct
{
    from: u64,
    to: u64,

    pub const Set = struct
    {
        ranges: CoreArray(Range),
        contiguous: u64,

        pub fn set(self: *@This(), from: u64, to: u64, maybe_delta: ?*i64, modify: bool) bool
        {
            if (to <= from) panic_raw("invalid range");

            if (self.ranges.items.len == 0)
            {
                if (maybe_delta) |delta|
                {
                    if (from >= self.contiguous) delta.* = to - from
                    else if (to >= self.contiguous) delta.* = to - self.contiguous
                    else delta.* = 0;
                }

                if (!modify) return true;

                if (from <= self.contiguous)
                {
                    if (to > self.contiguous) self.contiguous = to;
                    return true;
                }

                if (!self.normalize()) return false;
            }

            const new_range = blk:
            {
                var range = std.mem.zeroes(Range);
                range.left = if (self.find(from, true)) |left| left.from else from;
                range.right = if (self.find(to, true)) |right| right.to else to;
                break :blk range;
            };

            for (self.ranges.items) |range, range_i|
            {
                if 
            }

            TODO();
        }
    };
};

pub fn CoreArray(comptime T: type) type
{
    return struct
    {
        items: []T,
        cap: u64,
    };
}

pub fn FixedArray(comptime T: type) type
{
    return struct
    {
        items: []T,
        cap: u64,
    };
}

var kernel_panic_buffer: [0x4000]u8 = undefined;

pub fn panic(comptime format: []const u8, args: anytype) noreturn
{
    const formatted_string = std.fmt.bufPrint(kernel_panic_buffer[0..], format, args) catch unreachable;
    panic_raw(formatted_string);
}

fn _foo(msg: []const u8) void
{
    _ = msg;
}
/// This is the raw panic function
pub fn panic_raw(msg: []const u8) noreturn
{
    _foo(msg);
    Arch.CPU_stop();
}

pub fn TODO() noreturn
{
    panic_raw("To be implemented\n");
}

export fn init() callconv(.C) void
{
    kernel.process.register(.kernel);
    kernel.memory.init();
    TODO();
}
