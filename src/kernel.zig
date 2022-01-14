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

        pub fn or_flag(self: *@This(), comptime flag: EnumT) callconv(.Inline) void
        {
            self.bits |= 1 << @enumToInt(flag);
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
        const Self = @This();
        const Key = u64;

        pub const Item = struct
        {
            this: ?*T,
            children: [2]?*Item,
            parent: ?*Item,
            tree: ?*Self,
            key: Key,
            height: i32,
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

pub const RangeSet = struct
{
};

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
}
