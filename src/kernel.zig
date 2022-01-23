const kernel = @This();


// Kernel object members
pub var arch: Arch = undefined;
pub var scheduler: Scheduler = undefined;
pub var process: Scheduler.Process = undefined;
pub var desktop: Scheduler.Process = undefined;
pub var core: Core = undefined;
pub var physical_allocator: memory.Physical.Allocator = undefined;
pub var active_session_manager: cache.ActiveSession.Manager = undefined;
pub var global_data_region: *memory.SharedRegion = undefined;
pub var global_data: *GlobalData = undefined;
pub var random_number_generator: RandomNumberGenerator = undefined;

pub var acpi: ACPI = undefined;

pub const Arch = switch (@import("builtin").target.cpu.arch)
{
    .x86_64 => @import("x86_64.zig"),
    else => unreachable,
};
pub const memory = @import("memory.zig");
pub const Scheduler = @import("scheduler.zig");
pub const sync = @import("sync.zig");
pub const cache = @import("cache.zig");
pub const ACPI = @import("acpi.zig");
pub const drivers = @import("drivers.zig");

const std = @import("std");
const assert = std.debug.assert;
const AtomicOrder = std.builtin.AtomicOrder;
const zeroes = std.mem.zeroes;

pub fn Volatile(comptime T: type) type
{
    return struct
    {
        value: T,

        pub fn read_volatile(self: *const @This()) callconv(.Inline) T
        {
            return @ptrCast(*const volatile T, &self.value).*;
        }

        pub fn write_volatile(self: *@This(), value: T) callconv(.Inline) void
        {
            @ptrCast(*volatile T, &self.value).* = value;
        }

        /// Only supported for integer types
        pub fn atomic_fetch_add(self: *@This(), value: T) callconv(.Inline) T
        {
            return @atomicRmw(T, &self.value, .Add, value, .SeqCst);
        }
        pub fn atomic_fetch_sub(self: *@This(), value: T) callconv(.Inline) T
        {
            return @atomicRmw(T, &self.value, .Sub, value, .SeqCst);
        }
        
        pub fn increment(self: *@This()) void
        {
            self.write_volatile(self.read_volatile() + 1);
        }

        pub fn decrement(self: *@This()) void
        {
            self.write_volatile(self.read_volatile() - 1);
        }

        pub fn atomic_compare_and_swap(self: *@This(), expected_value: T, new_value: T) ?T
        {
            return @cmpxchgStrong(@TypeOf(self.value), &self.value, expected_value, new_value, .SeqCst, .SeqCst);
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

        pub fn from_flags(flags: anytype) callconv(.Inline) @This()
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

        pub fn from_bits(bits: IntType) @This()
        {
            return @This() { .bits = bits };
        }

        pub fn from_flag(comptime flag: EnumT) callconv(.Inline) @This()
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

        // TODO: create a mutable version of this
        pub fn or_flag(self: @This(), comptime flag: EnumT) callconv(.Inline) @This()
        {
            const bits = self.bits | 1 << @enumToInt(flag);
            return @This() { .bits = bits };
        }
    };
}
pub const max_wait_count = 8;
pub const wait_no_timeout = std.math.maxInt(u64);

pub const Core = struct
{
    address_space: memory.AddressSpace,
    regions: []memory.Region,
    region_commit_count: u64,
    heap: memory.Heap,
    fixed_heap: memory.Heap,
};

pub const Bitset = struct
{
    single_usage: []u32,
    group_usage: []u16,

    pub fn init(self: *@This(), count: u64, map_all: bool) void
    {
        self.single_usage.len = (count + 31) & ~@as(u64, 31);
        self.group_usage.len = self.single_usage.len / group_size + 1;
        self.single_usage.ptr = @intToPtr([*]u32, kernel.process.address_space.standard_allocate((self.single_usage.len >> 3) + (self.group_usage.len * 2), if (map_all) memory.Region.Flags.from_flag(.fixed) else memory.Region.Flags.empty()));
        self.group_usage.ptr = @intToPtr([*]u16, @ptrToInt(self.single_usage.ptr) + ((self.single_usage.len >> 4) * @sizeOf(u16)));
    }

    pub fn put(self: *@This(), index: u64) void
    {
        self.single_usage[index >> 5] |= @as(u32, 1) << @truncate(u5, index);
        self.group_usage[index / group_size] += 1;
    }

    pub fn take(self: *@This(), index: u64) void
    {
        const group = index / group_size;
        self.group_usage[group] -= 1;
        self.single_usage[index >> 5] &= ~(@as(u32, 1) << @truncate(u5, index));
    }

    const group_size = 0x1000;
};

pub fn AVLTree(comptime T: type) type
{
    return struct
    {
        root: ?*Item,
        modcheck: bool,

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

            var link = &self.root;
            var parent: ?*Item = null;
            
            while (true)
            {
                if (link.*) |node|
                {
                    if (item.compare(node) == 0)
                    {
                        if (duplicate_key_policy == .panic) panic_raw("avl duplicate panic")
                        else if (duplicate_key_policy == .fail) return false;
                    }

                    const child_index = @boolToInt(item.compare(node) > 0);
                    link = &node.children[child_index];
                    parent = node;
                }
                else
                {
                    link.* = item;
                    item.parent = parent;
                    break;
                }
            }

            var fake_root = zeroes(Item);
            self.root.?.parent = &fake_root;
            fake_root.tree = self;
            fake_root.key = 0;
            fake_root.children[0] = self.root;

            var item_it = item.parent.?;

            while (item_it != &fake_root)
            {
                const left_height = if (item_it.children[0]) |left| left.height else 0;
                const right_height = if (item_it.children[1]) |right| right.height else 0;
                const balance = left_height - right_height;
                item_it.height = 1 + if (balance > 0) left_height else right_height;
                var new_root: ?*Item = null;
                var old_parent = item_it.parent.?;

                if (balance > 1 and Item.compare_keys(key, item_it.children[0].?.key) <= 0)
                {
                    const right_rotation = item_it.rotate_right();
                    new_root = right_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                    old_parent.children[old_parent_child_index] = right_rotation;
                }
                else if (balance > 1 and Item.compare_keys(key, item_it.children[0].?.key) > 0 and item_it.children[0].?.children[1] != null)
                {
                    item_it.children[0] = item_it.children[0].?.rotate_left();
                    item_it.children[0].?.parent = item_it;
                    const right_rotation = item_it.rotate_right();
                    new_root = right_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                    old_parent.children[old_parent_child_index] = right_rotation;
                }
                else if (balance < -1 and Item.compare_keys(key, item_it.children[1].?.key) > 0)
                {
                    const left_rotation = item_it.rotate_left();
                    new_root = left_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                    old_parent.children[old_parent_child_index] = left_rotation;
                }
                else if (balance < -1 and Item.compare_keys(key, item_it.children[1].?.key) <= 0 and item_it.children[1].?.children[0] != null)
                {
                    item_it.children[1] = item_it.children[1].?.rotate_right();
                    item_it.children[1].?.parent = item_it;
                    const left_rotation = item_it.rotate_left();
                    new_root = left_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                    old_parent.children[old_parent_child_index] = left_rotation;
                }

                if (new_root) |new_root_unwrapped| new_root_unwrapped.parent = old_parent;
                item_it = old_parent;
            }

            self.root = fake_root.children[0];
            self.root.?.parent = null;

            self.validate();
            return true;
        }

        pub fn find(self: *@This(), key: Key, search_mode: SearchMode) ?*Item
        {
            if (self.modcheck) panic_raw("concurrent access\n");
            self.validate();
            return self.find_recursive(self.root, key, search_mode);
        }

        pub fn find_recursive(self: *@This(), maybe_root: ?*Item, key: Key, search_mode: SearchMode) ?*Item
        {
            if (maybe_root) |root|
            {
                if (Item.compare_keys(root.key, key) == 0) return root;

                switch (search_mode)
                {
                    .exact => return self.find_recursive(root.children[0], key, search_mode),
                    .smallest_above_or_equal =>
                    {
                        if (Item.compare_keys(root.key, key) > 0)
                        {
                            if (self.find_recursive(root.children[0], key, search_mode)) |item| return item
                            else return root;
                        }
                        else return self.find_recursive(root.children[1], key, search_mode);
                    },
                    .largest_below_or_equal =>
                    {
                        if (Item.compare_keys(root.key, key) < 0)
                        {
                            if (self.find_recursive(root.children[1], key, search_mode)) |item| return item
                            else return root;
                        }
                        else return self.find_recursive(root.children[0], key, search_mode);
                    },
                }
            }
            else
            {
                return null;
            }
        }

        pub fn remove(self: *@This(), item: *Item) void
        {
            if (self.modcheck) panic_raw("concurrent modification");
            self.modcheck = true;
            defer self.modcheck = false;

            self.validate();
            if (item.tree != self) panic_raw("item not in tree");

            var fake_root = zeroes(Item);
            self.root.?.parent = &fake_root;
            fake_root.tree = self;
            fake_root.key = 0;
            fake_root.children[0] = self.root;

            if (item.children[0] != null and item.children[1] != null)
            {
                const smallest = 0;
                const a = self.find_recursive(item.children[1], smallest, .smallest_above_or_equal).?;
                const b = item;
                a.swap(b);
            }

            var link = &item.parent.?.children[@boolToInt(item.parent.?.children[1] == item)];
            link.* = if (item.children[0]) |left| left else item.children[1];

            item.tree = null;
            var item_it = blk:
            {
                if (link.*) |link_u|
                {
                    link_u.parent = item.parent;
                    break :blk link.*.?;
                }
                else break :blk item.parent.?;
            };

            while (item_it != &fake_root)
            {
                const left_height = if (item_it.children[0]) |left| left.height else 0;
                const right_height = if (item_it.children[1]) |right| right.height else 0;
                const balance = left_height - right_height;
                item_it.height = 1 + if (balance > 0) left_height else right_height;

                var new_root: ?*Item = null;
                var old_parent = item_it.parent.?;

                if (balance > 1)
                {
                    const left_balance = if (item_it.children[0]) |left| left.get_balance() else 0;
                    if (left_balance >= 0)
                    {
                        const right_rotation = item_it.rotate_right();
                        new_root = right_rotation;
                        const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                        old_parent.children[old_parent_child_index] = right_rotation;
                    }
                    else
                    {
                        item_it.children[0] = item_it.children[0].?.rotate_left();
                        item_it.children[0].?.parent = item_it;
                        const right_rotation = item_it.rotate_right();
                        new_root = right_rotation;
                        const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                        old_parent.children[old_parent_child_index] = right_rotation;
                    }
                }
                else if (balance < -1)
                {
                    const right_balance = if (item_it.children[1]) |left| left.get_balance() else 0;
                    if (right_balance <= 0)
                    {
                        const left_rotation = item_it.rotate_left();
                        new_root = left_rotation;
                        const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                        old_parent.children[old_parent_child_index] = left_rotation;
                    }
                    else
                    {
                        item_it.children[1] = item_it.children[1].?.rotate_right();
                        item_it.children[1].?.parent = item_it;
                        const left_rotation = item_it.rotate_left();
                        new_root = left_rotation;
                        const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                        old_parent.children[old_parent_child_index] = left_rotation;
                    }
                }

                if (new_root) |new_root_unwrapped| new_root_unwrapped.parent = old_parent;
                item_it = old_parent;
            }

            self.root = fake_root.children[0];
            if (self.root) |root|
            {
                if (root.parent != &fake_root) panic_raw("incorrect root parent");
                root.parent = null;
            }

            self.validate();
        }

        fn validate(self: *@This()) void
        {
            if (self.root) |root|
            {
                _ = root.validate(self, null);
            }
            else
            {
                return;
            }
        }

        pub const Item = struct
        {
            value: ?*T,
            children: [2]?*Item,
            parent: ?*Item,
            tree: ?*Tree,
            key: Key,
            height: i32,

            fn rotate_left(self: *@This()) *Item
            {
                const x = self;
                const y = x.children[1].?;
                const maybe_t = y.children[0];
                y.children[0] = x;
                x.children[1] = maybe_t;
                x.parent = y;
                if (maybe_t) |t| t.parent = x;

                {
                    const left_height = if (x.children[0]) |left| left.height else 0;
                    const right_height = if (x.children[1]) |right| right.height else 0;
                    const balance = left_height - right_height;
                    x.height = 1 + if (balance > 0) left_height else right_height;
                }

                {
                    const left_height = if (y.children[0]) |left| left.height else 0;
                    const right_height = if (y.children[1]) |right| right.height else 0;
                    const balance = left_height - right_height;
                    y.height = 1 + if (balance > 0) left_height else right_height;
                }

                return y;
            }

            fn rotate_right(self: *@This()) *Item
            {
                const y = self;
                const x = y.children[0].?;
                const maybe_t = x.children[1];
                x.children[1] = y;
                y.children[0] = maybe_t;
                y.parent = x;
                if (maybe_t) |t| t.parent = y;

                {
                    const left_height = if (y.children[0]) |left| left.height else 0;
                    const right_height = if (y.children[1]) |right| right.height else 0;
                    const balance = left_height - right_height;
                    y.height = 1 + if (balance > 0) left_height else right_height;
                }

                {
                    const left_height = if (x.children[0]) |left| left.height else 0;
                    const right_height = if (x.children[1]) |right| right.height else 0;
                    const balance = left_height - right_height;
                    x.height = 1 + if (balance > 0) left_height else right_height;
                }

                return x;
            }

            fn swap(self: *@This(), other: *@This()) void
            {
                self.parent.?.children[@boolToInt(self.parent.?.children[1] == self)] = other;
                other.parent.?.children[@boolToInt(other.parent.?.children[1] == other)] = self;

                var temporal_self = self.*;
                var temporal_other = other.*;
                self.parent = temporal_other.parent;
                other.parent = temporal_self.parent;
                self.height = temporal_other.height;
                other.height = temporal_self.height;
                self.children[0] = temporal_other.children[0];
                self.children[1] = temporal_other.children[1];
                other.children[0] = temporal_self.children[0];
                other.children[1] = temporal_self.children[1];

                if (self.children[0]) |a_left| a_left.parent = self;
                if (self.children[1]) |a_right| a_right.parent = self;
                if (other.children[0]) |b_left| b_left.parent = other;
                if (other.children[1]) |b_right| b_right.parent = other;
            }

            fn get_balance(self: *@This()) i32
            {
                const left_height = if (self.children[0]) |left| left.height else 0;
                const right_height = if (self.children[1]) |right| right.height else 0;
                return left_height - right_height;
            }

            fn validate(self: *@This(), tree: *Tree, parent: ?*@This()) i32
            {
                if (self.parent != parent) panic_raw("tree panic");
                if (self.tree != tree) panic_raw("tree panic");

                const left_height = blk:
                {
                    if (self.children[0]) |left|
                    {
                        if (left.compare(self) > 0) panic_raw("invalid tree");
                        break :blk left.validate(tree, self);
                    }
                    else
                    {
                        break :blk @as(i32, 0);
                    }
                };

                const right_height = blk:
                {
                    if (self.children[1]) |right|
                    {
                        if (right.compare(self) < 0) panic_raw("invalid tree");
                        break :blk right.validate(tree, self);
                    }
                    else
                    {
                        break :blk @as(i32, 0);
                    }
                };

                const height = 1 + if (left_height > right_height) left_height else right_height;
                if (height != self.height) panic_raw("invalid tree");

                return height;
            }

            fn compare(self: *@This(), other: *@This()) i32
            {
                return compare_keys(self.key, other.key);
            }

            fn compare_keys(key1: u64, key2: u64) i32
            {
                if (key1 < key2) return -1;
                if (key1 > key2) return 1;
                return 0;
            }
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
            value: ?*T,

            pub fn remove_from_list(self: *@This()) void
            {
                if (self.list) |list|
                {
                    list.remove(self);
                }
                else
                {
                    panic_raw("list null when trying to remove item");
                }
            }
        };

        pub fn insert_at_start(self: *@This(), item: *Item) void
        {
            if (item.list != null) panic_raw("inserting an item that is already in a list");

            if (self.first) |first|
            {
                item.next = first;
                item.previous = null;
                first.previous = item;
                self.first = item;
            }
            else
            {
                self.first = item;
                self.last = item;
                item.previous = null;
                item.next = null;
            }

            self.count += 1;
            item.list = self;
            self.validate();
        }

        pub fn insert_at_end(self: *@This(), item: *Item) void
        {
            if (item.list != null) panic_raw("inserting an item that is already in a list");

            if (self.last) |last|
            {
                item.previous = last;
                item.next= null;
                last.next = item;
                self.last = item;
            }
            else
            {
                self.first = item;
                self.last = item;
                item.previous = null;
                item.next = null;
            }

            self.count += 1;
            item.list = self;
            self.validate();
        }

        pub fn insert_before(self: *@This(), item: *Item, before: *Item) void
        {
            if (item.list != null) panic_raw("inserting an item that is already in a list");

            if (before != self.first)
            {
                item.previous = before.previous;
                item.previous.?.next = item;
            }
            else
            {
                self.first = item;
                item.previous = null;
            }

            item.next = before;
            before.previous = item;

            self.count += 1;
            item.list = self;
            self.validate();
        }

        pub fn remove(self: *@This(), item: *Item) void
        {
            // @TODO: modchecks

            if (item.list) |list|
            {
                if (list != self) panic_raw("item is in another list");
            }
            else
            {
                panic_raw("item is not in any list");
            }

            if (item.previous) |previous| previous.next = item.next
            else self.first = item.next;

            if (item.next) |next| next.previous = item.previous
            else self.last = item.previous;

            item.previous = null;
            item.next = null;
            self.count -= 1;
            self.validate();
        }

        fn validate(self: *@This()) void
        {
            if (self.count == 0)
            {
                TODO();
            }
            else if (self.count == 1)
            {
                if (self.first != self.last or
                    self.first.?.previous != null or
                    self.first.?.next != null or
                    self.first.?.list != self or
                    self.first.?.value == null)
                {
                    panic_raw("invalid list");
                }
            }
            else
            {
                if (self.first == self.last or
                    self.first.?.previous != null or
                    self.last.?.next != null)
                {
                    panic_raw("invalid list");
                }

                {
                    var item = self.first;
                    var index = self.count;

                    while (true)
                    {
                        index -= 1;
                        if (index == 0) break;

                        if (item.?.next == item or item.?.list != self or item.?.value == null)
                        {
                            panic_raw("invalid list");
                        }

                        item = item.?.next;
                    }

                    if (item != self.last) panic_raw("invalid list");
                }

                {
                    var item = self.last;
                    var index = self.count;

                    while (true)
                    {
                        index -= 1;
                        if (index == 0) break;

                        if (item.?.previous == item)
                        {
                            panic_raw("invalid list");
                        }

                        item = item.?.previous;
                    }

                    if (item != self.first) panic_raw("invalid list");
                }
            }
        }
    };
}

pub const SimpleList = struct
{
    previous_or_last: ?*@This(),
    next_or_first: ?*@This(),

    pub fn insert(self: *@This(), item: *SimpleList, start: bool) void
    {
        if (item.previous_or_last != null or item.next_or_first != null)
        {
            panic_raw("bad links");
        }

        if (self.next_or_first == null and self.previous_or_last == null)
        {
            item.previous_or_last = self;
            item.next_or_first = self;
            self.next_or_first = item;
            self.previous_or_last = item;
        }
        else if (start)
        {
            item.previous_or_last = self;
            item.next_or_first = self.next_or_first;
            self.next_or_first.?.previous_or_last = item;
            self.next_or_first = item;
        }
        else
        {
            item.previous_or_last = self.previous_or_last;
            item.next_or_first = self;
            self.previous_or_last.?.next_or_first = item;
            self.previous_or_last = item;
        }
    }

    pub fn remove(self: *@This()) void
    {
        if (self.previous_or_last.next != self or self.next_or_first.previous != self) panic_raw("bad links");

        if (self.previous_or_last == self.next_or_first)
        {
            self.next_or_first.?.next_or_first = null;
            self.next_or_first.?.previous_or_last = null;
        }
        else
        {
            self.previous_or_last.?.next_or_first = self.next_or_first;
            self.next_or_first.?.previous_or_last = self.previous_or_last;
        }

        self.previous_or_last = null;
        self.next_or_first = null;
    }
};

pub fn Pool(comptime T: type) type
{
    return struct
    {
        cache_entries: [cache_count]?*T,
        cache_entry_count: u64,
        mutex: sync.Mutex,

        const cache_count = 16;

        pub fn add(self: *@This()) ?*T
        {
            _ = self.mutex.acquire();
            defer self.mutex.release();

            if (self.cache_entry_count != 0)
            {
                self.cache_entry_count -= 1;
                const address = self.cache_entries[self.cache_entry_count];
                std.mem.set(u8, @ptrCast([*]u8, address)[0..@sizeOf(T)], 0);
                return address;
            }
            else
            {
                return @intToPtr(?*T, kernel.core.fixed_heap.allocate(@sizeOf(T), true));
            }
        }

        pub fn remove(self: *@This(), pointer: ?*T) void
        {
            _ = self.mutex.acquire();
            defer self.mutex.release();

            if (pointer == null) return;

            if (self.cache_entry_count == cache_count)
            {
                kernel.core.fixed_heap.free(@ptrToInt(pointer), @sizeOf(T));
            }
            else
            {
                self.cache_entries[self.cache_entry_count] = pointer;
                self.cache_entry_count += 1;
            }
        }
    };
}

pub const Range = extern struct
{
    from: u64,
    to: u64,

    pub const Set = extern struct
    {
        ranges: Array(Range, .core),
        contiguous: u64,

        pub fn set(self: *@This(), from: u64, to: u64, maybe_delta: ?*i64, modify: bool) bool
        {
            if (to <= from) panic_raw("invalid range");

            if (self.ranges.items.len == 0)
            {
                if (maybe_delta) |delta|
                {
                    if (from >= self.contiguous) delta.* = @intCast(i64, to) - @intCast(i64, from)
                    else if (to >= self.contiguous) delta.* = @intCast(i64, to) - @intCast(i64, self.contiguous)
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
                range.from = if (self.find(from, true)) |left| left.from else from;
                range.to = if (self.find(to, true)) |right| right.to else to;
                break :blk range;
            };

            const index = blk:
            {
                if (!modify) break :blk @as(u64, 0);

                for (self.ranges.items) |range, range_i|
                {
                    if (range.to > new_range.from)
                    {
                        if (self.ranges.insert(new_range, range_i) == null)
                        {
                            return false;
                        }

                        break :blk range_i + 1;
                    }
                }

                const result_index = self.ranges.items.len;
                if (self.ranges.insert(new_range, result_index) == null)
                {
                    return false;
                }
                break :blk result_index + 1;
            };

            var delete_start = index;
            var delete_count: u64 = 0;
            var delete_total: u64 = 0;

            for (self.ranges.items[index..]) |range|
            {
                const overlap =
                    (range.from >= new_range.from and range.from <= new_range.to) or
                    (range.to >= new_range.from and range.to <= new_range.to);
                if (overlap)
                {
                    delete_count += 1;
                    delete_total += range.to - range.from;
                }
                else
                {
                    break;
                }
            }

            if (modify) self.ranges.delete_many(delete_start, delete_count);

            self.validate();

            if (maybe_delta) |delta|
            {
                delta.* = @intCast(i64, new_range.to) - @intCast(i64, new_range.from) - @intCast(i64, delete_total);
            }

            return true;
        }

        pub fn normalize(self: *@This()) bool
        {
            if (self.contiguous != 0)
            {
                const old_contiguous = self.contiguous;
                self.contiguous = 0;

                if (!self.set(0, old_contiguous, null, true)) return false;
            }

            return true;
        }

        pub fn find(self: *@This(), offset: u64, touching: bool) ?*Range
        {
            if (self.ranges.items.len == 0) return null;

            var low: i64 = 0;
            var high = @intCast(i64, self.ranges.items.len - 1);

            while (low <= high)
            {
                const i = @divTrunc(low + (high - low), 2);
                assert(i >= 0);
                const range = &self.ranges.items[@intCast(u64, i)];

                if (range.from <= offset and (offset < range.to or (touching and offset <= range.to))) return range
                else if (range.from <= offset) low = i + 1
                else high = i - 1;
            }

            return null;
        }

        pub fn contains(self: *@This(), offset: u64) bool
        {
            if (self.ranges.items.len != 0) return self.find(offset, false) != null
            else return offset < self.contiguous;
        }

        fn validate(self: *@This()) void
        {
            var previous_to: u64 = 0;
            if (self.ranges.items.len == 0) return;

            for (self.ranges.items) |range|
            {
                if (previous_to != 0 and range.from <= previous_to) panic_raw("range in set is not placed after the prior range\n");
                if (range.from >= range.to) panic_raw("range in set is invalid\n");

                previous_to = range.to;
            }
        }
    };
};

const HeapType = enum
{
    core,
    fixed,
};

pub fn Array(comptime T: type, comptime heap_type: HeapType) type
{
    return struct
    {
        items: []T,
        cap: u64,

        pub fn insert(self: *@This(), item: T, position: u64) ?*T
        {
            _ = self;
            _ = item;
            _ = position;
            _ = heap_type;
            TODO();
        }

        pub fn delete_many(self: *@This(), position: u64, count: u64) void
        {
            _ = self;
            _ = position;
            _ = count;
            TODO();
        }
    };
}

pub fn clamp(comptime Int: type, low: Int, high: Int, integer: Int) Int
{
    if (integer < low) return low;
    if (integer > low) return high;
    return integer;
}

pub fn open_handle(comptime T: type, object: *T, flags: u32) bool
{
    _ = flags;
    var had_no_handles = false;
    var failed = false;
    
    switch (T)
    {
        Scheduler.Process =>
        {
            had_no_handles = 0 == object.handle_count.atomic_fetch_add(1);
        },
        memory.SharedRegion =>
        {
            _ = object.mutex.acquire();
            if (object.handle_count.read_volatile() == 0) had_no_handles = true
            else object.handle_count.increment();
            object.mutex.release();
        },
        else => unreachable,
    }

    if (had_no_handles) panic_raw("object had no handles");

    return !failed;
}

pub fn create_thread(start_address: u64, argument: u64) bool
{
    return kernel.process.spawn_thread_no_flags(start_address, argument) != null;
}

pub fn create_thread_noargs(start_address: u64) bool
{
    return create_thread(start_address, 0);
}

pub const GlobalData = struct 
{
    click_chain_timeout_ms: Volatile(i32),
    UI_scale: Volatile(f32),
    swap_left_and_right_buttons: Volatile(bool),
    show_cursor_shadow: Volatile(bool),
    use_smart_quotes: Volatile(bool),
    enable_hover_state: Volatile(bool),
    animation_time_multiplier: Volatile(f32),
    scheduler_time_ms: Volatile(u64),
    scheduler_time_offset: Volatile(u64),
    keyboard_layout: Volatile(u16),
};

pub fn sum_bytes(bytes: []const u8) u8
{
    if (bytes.len == 0) return 0;

    var total: u64 = 0;
    for (bytes) |byte|
    {
        total += byte;
    }

    return @truncate(u8, total);
}

pub const RandomNumberGenerator = struct
{
    s: [4]u64,
    lock: kernel.sync.Spinlock,

    pub fn add_entropy(self: *@This(), n: u64) void
    {
        @setRuntimeSafety(false); // We are relying on overflow here
        self.lock.acquire();
        var x = n;

        for (self.s) |*s|
        {
            x += 0x9E3779B97F4A7C15;
            var result = x;
            result = (result ^ (result >> 30)) * 0xBF58476D1CE4E5B9;
            result = (result ^ (result >> 27)) * 0x94D049BB133111EB;
            s.* ^= result ^ (result >> 31);
        }
        self.lock.release();
    }

    const Spinlock = struct
    {
        state: Volatile(u8),

        fn acquire(self: *@This()) void
        {
            @fence(.SeqCst);
            while (self.state.atomic_compare_and_swap(0, 1) == null) {}
            @fence(.SeqCst);
        }

        fn release(self: *@This()) void
        {
            @fence(.SeqCst);
            if (self.state.read_volatile() == 0) panic_raw("spinlock not acquired");
            self.state.write_volatile(0);
            @fence(.SeqCst);
        }
    };
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
    _ = create_thread_noargs(@ptrToInt(main_thread));
    kernel.Arch.init();
    kernel.scheduler.started.write_volatile(true);
}

pub var shutdown_event: kernel.sync.Event = undefined;
pub fn main_thread() callconv(.C) void
{
    desktop.register(.desktop);
    drivers.init();
    _ = shutdown_event.wait();
}
