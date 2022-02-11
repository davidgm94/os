const std = @import("std");
const assert = std.debug.assert;
const atomic_order: std.builtin.AtomicOrder = .SeqCst;

pub const Error = i64;

pub fn zeroes(comptime T: type) T
{
    var zero_value: T = undefined;
    std.mem.set(u8, std.mem.asBytes(&zero_value), 0);
    return zero_value;
}

pub const arch = blk:
{
    const current_arch = @import("builtin").target.cpu.arch;
    switch (current_arch)
    {
        .x86_64 => break :blk @import("arch/x86_64.zig"),
        else => @compileError(std.fmt.comptimePrint("Arch {} not supported\n", .{current_arch})),
    }
};

pub const drivers = @import("drivers.zig");
pub const serial = drivers.serial;

pub const files = @import("files.zig");
pub const Shared = @import("shared");
pub const Filesystem = Shared.Filesystem;

pub const memory = @import("memory.zig");
const SharedRegion = memory.SharedRegion;
const Heap = memory.Heap;
const Region = memory.Region;
const AddressSpace = memory.AddressSpace;
const Physical = memory.Physical;

pub const object = @import("object.zig");

pub const scheduling = @import("scheduling.zig");
const Scheduler = scheduling.Scheduler;
const Process = scheduling.Process;
const Thread = scheduling.Thread;

pub const sync = @import("sync.zig");
const Spinlock = sync.Spinlock;
const Mutex = sync.Mutex;
const WriterLock = sync.WriterLock;
const Event = sync.Event;

pub const syscall = @import("syscall.zig");

pub const max_wait_count = 8;
pub const max_processors = 256;
pub const wait_no_timeout = std.math.maxInt(u64);

pub const ES_SUCCESS = -1;

pub export var scheduler: Scheduler = undefined;
pub export var process: Process = undefined;
pub export var desktop_process: *Process = undefined;

pub fn Volatile(comptime T: type) type
{
    return extern struct
    {
        value: T,

        pub fn read_volatile(self: *volatile const @This()) callconv(.Inline) T
        {
            return self.value;
        }

        pub fn write_volatile(self: *volatile @This(), value: T) callconv(.Inline) void
        {
            self.value = value;
        }

        pub fn access_volatile(self: *volatile @This()) callconv(.Inline) *volatile T
        {
            return &self.value;
        }

        pub fn increment(self: *@This()) callconv(.Inline) void
        {
            self.write_volatile(self.read_volatile() + 1);
        }

        pub fn decrement(self: *@This()) callconv(.Inline) void
        {
            self.write_volatile(self.read_volatile() - 1);
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

        pub fn atomic_compare_and_swap(self: *@This(), expected_value: T, new_value: T) callconv(.Inline) ?T
        {
            return @cmpxchgStrong(@TypeOf(self.value), &self.value, expected_value, new_value, .SeqCst, .SeqCst);
        }
    };
}


pub fn TODO(src: std.builtin.SourceLocation) noreturn
{
    panicf("TODO: Unimplemented at {s}:{}:{} -> {s}\n", .{src.file, src.line, src.column, src.fn_name});
}

pub fn panic(message: []const u8) noreturn
{
    arch.disable_interrupts();
    _ = arch.IPI.send(arch.IPI.kernel_panic, true, -1);
    scheduler.panic.write_volatile(true);
    serial.write("KERNEL PANIC:\n");
    serial.write(message);
    arch.halt();
}

var panic_lock: Spinlock = undefined;
var panic_buffer: [0x4000]u8 align(0x1000) = undefined;
pub fn panicf(comptime format: []const u8, args: anytype) noreturn
{
    arch.disable_interrupts();
    _ = arch.IPI.send(arch.IPI.kernel_panic, true, -1);
    scheduler.panic.write_volatile(true);
    log_ex(&panic_buffer, &panic_lock, "KERNEL PANIC:\n" ++ format, args);
    arch.halt();
}

pub const GlobalData = extern struct
{
    click_chain_timeout_ms: Volatile(i32),
    ui_scale: Volatile(f32),
    swap_left_and_right_buttons: Volatile(bool),
    show_cursor_shadow: Volatile(bool),
    use_smart_quotes: Volatile(bool),
    enable_hover_state: Volatile(bool),
    animation_time_multiplier: Volatile(f32),
    scheduler_time_ms: Volatile(u64),
    scheduler_time_offset: Volatile(u64),
    keyboard_layout: Volatile(u16),
};

pub export var mmGlobalDataRegion: *SharedRegion = undefined;
pub export var globalData: *GlobalData = undefined;

pub fn LinkedList(comptime T: type) type
{
    return extern struct
    {
        first: ?*Item,
        last: ?*Item,
        count: u64,

        pub const Item = extern struct
        {
            previous: ?*@This(),
            next: ?*@This(),
            list: ?*LinkedList(T),
            value: ?*T,

            pub fn remove_from_list(self: *@This()) void
            {
                if (self.list) |list|
                {
                    list.remove(self);
                }
                else
                {
                    panic("list null when trying to remove item");
                }
            }
        };

        pub fn insert_at_start(self: *@This(), item: *Item) void
        {
            if (item.list != null) panic("inserting an item that is already in a list");

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
            if (item.list != null) panic("inserting an item that is already in a list");

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
            if (item.list != null) panic("inserting an item that is already in a list");

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
            if (item.list) |list|
            {
                if (list != self) panic("item is in another list");
            }
            else
            {
                panic("item is not in any list");
            }

            if (item.previous) |previous| previous.next = item.next
            else self.first = item.next;

            if (item.next) |next| next.previous = item.previous
            else self.last = item.previous;

            item.previous = null;
            item.next = null;
            item.list = null;

            self.count -= 1;
            self.validate();
        }

        fn validate(self: *@This()) void
        {
            if (self.count == 0)
            {
                if (self.first != null or self.last != null) panic("invalid list");
            }
            else if (self.count == 1)
            {
                if (self.first != self.last or
                    self.first.?.previous != null or
                    self.first.?.next != null or
                    self.first.?.list != self or
                    self.first.?.value == null)
                {
                    panic("invalid list");
                }
            }
            else
            {
                if (self.first == self.last or
                    self.first.?.previous != null or
                    self.last.?.next != null)
                {
                    panic("invalid list");
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
                            panic("invalid list");
                        }

                        item = item.?.next;
                    }

                    if (item != self.last) panic("invalid list");
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
                            panic("invalid list");
                        }

                        item = item.?.previous;
                    }

                    if (item != self.first) panic("invalid list");
                }
            }
        }
    };
}

pub const FatalError = enum(u32)
{
    abort,
    incorrect_file_acces,
    incorrect_node_type,
    insufficient_permissions,
    invalid_buffer,
    invalid_handle,
    invalid_memory_region,
    out_of_range,
    processor_exception,
    recursive_batch,
    unknown_syscall,
};

pub export var heapCore: Heap = undefined;
pub export var heapFixed: Heap = undefined;

// @TODO: initialize
pub export var mmCoreRegions: [*]Region = undefined;
pub export var mmCoreRegionCount: u64 = 0;
pub export var mmCoreRegionArrayCommit: u64 = 0;

pub const Pool = extern struct
{
    element_size: u64, // @ABICompatibility @Delete
    cache_entries: [cache_count]u64,
    cache_entry_count: u64,
    mutex: Mutex,

    const cache_count = 16;

    pub fn add(self: *@This(), element_size: u64) u64
    {
        _ = self.mutex.acquire();
        defer self.mutex.release();

        if (self.element_size != 0 and element_size != self.element_size) panic("pool size mismatch");
        self.element_size = element_size;

        if (self.cache_entry_count != 0)
        {
            self.cache_entry_count -= 1;
            const address = self.cache_entries[self.cache_entry_count];
            std.mem.set(u8, @intToPtr([*]u8, address)[0..self.element_size], 0);
            return address;
        }
        else
        {
            return heapFixed.allocate(self.element_size, true);
            //return @intToPtr(?*T, kernel.core.fixed_heap.allocate(@sizeOf(T), true));
        }
    }

    pub fn remove(self: *@This(), pointer: u64) void
    {
        _ = self.mutex.acquire();
        defer self.mutex.release();

        if (pointer == 0) return;

        if (self.cache_entry_count == cache_count)
        {
            heapFixed.free(pointer, self.element_size);
        }
        else
        {
            self.cache_entries[self.cache_entry_count] = pointer;
            self.cache_entry_count += 1;
        }
    }
};

pub export var address_space: AddressSpace = undefined;
pub export var core_address_space: AddressSpace = undefined;
pub export var pmm: Physical.Allocator = undefined;

pub const SimpleList = extern struct
{
    previous_or_last: ?*@This(),
    next_or_first: ?*@This(),

    pub fn insert(self: *@This(), item: *SimpleList, start: bool) void
    {
        if (item.previous_or_last != null or item.next_or_first != null)
        {
            panic("bad links");
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
        if (self.previous_or_last.?.next_or_first != self or self.next_or_first.?.previous_or_last != self) panic("bad links");

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

pub fn Bitflag(comptime EnumT: type) type
{
    return extern struct
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

const HeapType = enum
{
    core,
    fixed,
};

// @TODO -> this is just to maintain abi compatibility with the C++ implementation
pub fn Array(comptime T: type, comptime heap_type: HeapType) type
{
    _ = heap_type;
    return extern struct
    {
        ptr: ?[*]T,

        pub fn length(self: @This()) u64
        {
            return ArrayHeaderGetLength(@ptrCast(?*u64, self.ptr));
        }

        pub fn get_slice(self: @This()) []T
        {
            if (self.ptr) |ptr|
            {
                return ptr[0..self.length()];
            }
            else
            {
                panic("Array ptr is null");
            }
        }

        pub fn free(self: *@This()) void
        {
            _ArrayFree(@ptrCast(*?*u64, &self.ptr), @sizeOf(T), get_heap());
        }

        pub fn get_heap() *Heap
        {
            return switch (heap_type)
            {
                .core => &heapCore,
                .fixed => &heapFixed,
            };
        }

        pub fn insert(self: *@This(), item: T, position: u64) ?*T
        {
            return @intToPtr(?*T, _ArrayInsert(@ptrCast(*?*u64, &self.ptr), @ptrToInt(&item), @sizeOf(T), @bitCast(i64, position), 0, get_heap()));
        }

        pub fn delete_many(self: *@This(), position: u64, count: u64) void
        {
            _ArrayDelete(@ptrCast(?*u64, self.ptr), position, @sizeOf(T), count);
        }

        pub fn first(self: *@This()) *T
        {
            return &self.ptr.?[0];
        }

        pub fn last(self: *@This()) *T
        {
            const len = self.length();
            assert(len != 0);
            return &self.ptr.?[len - 1];
        }
    };
}

pub const MessageObject = extern struct
{
    array: [5]u64,
};

pub const MessageQueue = extern struct
{
    messages: Array(MessageObject, .core),
    mouseMovedMessage: u64,
    windowResizedMessage: u64,
    eyedropResultMessage: u64,
    keyRepeatMessage: u64,
    pinged: bool,
    mutex: Mutex,
    notEmpty: Event,
};

pub const ES_INVALID_HANDLE: u64 = 0x0;
pub const ES_CURRENT_THREAD: u64 = 0x10;
pub const ES_CURRENT_PROCESS: u64 = 0x11;

pub fn AVLTree(comptime T: type) type
{
    return extern struct
    {
        root: ?*Item,
        modcheck: bool,
        long_keys: bool, // @ABICompatibility @Delete

        const Tree = @This();
        const KeyDefaultType = u64;
        const Key = extern union
        {
            short_key: u64,
            long: extern struct
            {
                key: u64,
                key_byte_count: u64,
            },
        };

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

        pub fn insert(self: *@This(), item: *Item, item_value: ?*T, key: KeyDefaultType, duplicate_key_policy: DuplicateKeyPolicy) bool
        {
            self.validate();
            
            if (item.tree != null)
            {
                panic("item already in a tree\n");
            }

            item.tree = self;

            item.key = zeroes(Key);
            item.key.short_key = key;
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
                        if (duplicate_key_policy == .panic) panic("avl duplicate panic")
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

                if (balance > 1 and Item.compare_keys(key, item_it.children[0].?.key.short_key) <= 0)
                {
                    const right_rotation = item_it.rotate_right();
                    new_root = right_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                    old_parent.children[old_parent_child_index] = right_rotation;
                }
                else if (balance > 1 and Item.compare_keys(key, item_it.children[0].?.key.short_key) > 0 and item_it.children[0].?.children[1] != null)
                {
                    item_it.children[0] = item_it.children[0].?.rotate_left();
                    item_it.children[0].?.parent = item_it;
                    const right_rotation = item_it.rotate_right();
                    new_root = right_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                    old_parent.children[old_parent_child_index] = right_rotation;
                }
                else if (balance < -1 and Item.compare_keys(key, item_it.children[1].?.key.short_key) > 0)
                {
                    const left_rotation = item_it.rotate_left();
                    new_root = left_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.children[1] == item_it);
                    old_parent.children[old_parent_child_index] = left_rotation;
                }
                else if (balance < -1 and Item.compare_keys(key, item_it.children[1].?.key.short_key) <= 0 and item_it.children[1].?.children[0] != null)
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

        pub fn find(self: *@This(), key: KeyDefaultType, search_mode: SearchMode) ?*Item
        {
            if (self.modcheck) panic("concurrent access\n");
            self.validate();
            return self.find_recursive(self.root, key, search_mode);
        }

        pub fn find_recursive(self: *@This(), maybe_root: ?*Item, key: KeyDefaultType, search_mode: SearchMode) ?*Item
        {
            if (maybe_root) |root|
            {
                if (Item.compare_keys(root.key.short_key, key) == 0) return root;

                switch (search_mode)
                {
                    .exact => return self.find_recursive(root.children[0], key, search_mode),
                    .smallest_above_or_equal =>
                    {
                        if (Item.compare_keys(root.key.short_key, key) > 0)
                        {
                            if (self.find_recursive(root.children[0], key, search_mode)) |item| return item
                            else return root;
                        }
                        else return self.find_recursive(root.children[1], key, search_mode);
                    },
                    .largest_below_or_equal =>
                    {
                        if (Item.compare_keys(root.key.short_key, key) < 0)
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
            if (self.modcheck) panic("concurrent modification");
            self.modcheck = true;
            defer self.modcheck = false;

            self.validate();
            if (item.tree != self) panic("item not in tree");

            var fake_root = zeroes(Item);
            self.root.?.parent = &fake_root;
            fake_root.tree = self;
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
                if (root.parent != &fake_root) panic("incorrect root parent");
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

        pub const Item = extern struct
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
                if (self.parent != parent) panic("tree panic");
                if (self.tree != tree) panic("tree panic");

                const left_height = blk:
                {
                    if (self.children[0]) |left|
                    {
                        if (left.compare(self) > 0) panic("invalid tree");
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
                        if (right.compare(self) < 0) panic("invalid tree");
                        break :blk right.validate(tree, self);
                    }
                    else
                    {
                        break :blk @as(i32, 0);
                    }
                };

                const height = 1 + if (left_height > right_height) left_height else right_height;
                if (height != self.height) panic("invalid tree");

                return height;
            }

            fn compare(self: *@This(), other: *@This()) i32
            {
                return compare_keys(self.key.short_key, other.key.short_key);
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

pub const Range = extern struct
{
    from: u64,
    to: u64,

    pub const Set = extern struct
    {
        ranges: Array(Range, .core),
        contiguous: u64,

        pub fn find(self: *@This(), offset: u64, touching: bool) ?*Range
        {
            const length = self.ranges.length();
            if (length == 0) return null;

            var low: i64 = 0;
            var high = @intCast(i64, length) - 1;

            while (low <= high)
            {
                const i = @divTrunc(low + (high - low), 2);
                assert(i >= 0);
                const range = &self.ranges.ptr.?[@intCast(u64, i)];

                if (range.from <= offset and (offset < range.to or (touching and offset <= range.to))) return range
                else if (range.from <= offset) low = i + 1
                else high = i - 1;
            }

            return null;
        }

        pub fn contains(self: *@This(), offset: u64) bool
        {
            if (self.ranges.length() != 0) return self.find(offset, false) != null
            else return offset < self.contiguous;
        }

        fn validate(self: *@This()) void
        {
            var previous_to: u64 = 0;
            if (self.ranges.length() == 0) return;

            for (self.ranges.get_slice()) |range|
            {
                if (previous_to != 0 and range.from <= previous_to) panic("range in set is not placed after the prior range\n");
                if (range.from >= range.to) panic("range in set is invalid\n");

                previous_to = range.to;
            }
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

        pub fn clear(self: *@This(), from: u64, to: u64, maybe_delta: ?*i64, modify: bool) bool
        {
            if (to <= from) panic("invalid range");

            if (self.ranges.length() == 0)
            {
                if (from < self.contiguous and self.contiguous != 0)
                {
                    if (to < self.contiguous)
                    {
                        if (modify)
                        {
                            if (!self.normalize()) return false;
                        }
                        else
                        {
                            if (maybe_delta) |delta| delta.* = @intCast(i64, from) - @intCast(i64, to);
                            return true;
                        }
                    }
                    else
                    {
                        if (maybe_delta) |delta| delta.* = @intCast(i64, from) - @intCast(i64, self.contiguous);
                        if (modify) self.contiguous = from;
                        return true;
                    }
                }
                else
                {
                    if (maybe_delta) |delta| delta.* = 0;
                    return true;
                }
            }

            if (self.ranges.length() == 0)
            {
                self.ranges.free();
                if (maybe_delta) |delta| delta.* = 0;
                return true;
            }

            if (to <= self.ranges.first().from or from >= self.ranges.last().to)
            {
                if (maybe_delta) |delta| delta.* = 0;
                return true;
            }

            if (from <= self.ranges.first().from and to >= self.ranges.last().to)
            {
                if (maybe_delta) |delta|
                {
                    var total: i64 = 0;

                    for (self.ranges.get_slice()) |range|
                    {
                        total += @intCast(i64, range.to) - @intCast(i64, range.from);
                    }

                    delta.* = -total;
                }

                if (modify) self.ranges.free();

                return true;
            }

            var overlap_start = self.ranges.length();
            var overlap_count: u64 = 0;

            for (self.ranges.get_slice()) |*range, i|
            {
                if (range.to > from and range.from < to)
                {
                    overlap_start = i;
                    overlap_count = 1;
                    break;
                }
            }

            for (self.ranges.get_slice()[overlap_start + 1..]) |*range|
            {
                if (range.to >= from and range.from < to) overlap_count += 1
                else break;
            }

            var _delta: i64 = 0;

            if (overlap_count == 1)
            {
                TODO(@src());
            }
            else if (overlap_count > 1)
            {
                TODO(@src());
            }

            if (maybe_delta) |delta| delta.* = _delta;

            self.validate();
            return true;
        }

        pub fn set(self: *@This(), from: u64, to: u64, maybe_delta: ?*i64, modify: bool) bool
        {
            if (to <= from) panic("invalid range");

            const initial_length = self.ranges.length();
            if (initial_length == 0)
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

            const new_range = Range
            {
                .from = if (self.find(from, true)) |left| left.from else from,
                .to = if (self.find(to, true)) |right| right.to else to,
            };

            var i: u64 = 0;
            while (i <= self.ranges.length()) : (i += 1)
            {
                if (i == self.ranges.length() or self.ranges.ptr.?[i].to > new_range.from)
                {
                    if (modify)
                    {
                        if (self.ranges.insert(new_range, i) == null) return false;
                        i += 1;
                    }

                    break;
                }
            }

            var delete_start = i;
            var delete_count: u64 = 0;
            var delete_total: u64 = 0;

            for (self.ranges.get_slice()[i..]) |*range|
            {
                const overlap = (range.from >= new_range.from and range.from <= new_range.to) or (range.to >= new_range.from and range.to <= new_range.to);

                if (overlap)
                {
                    delete_count += 1;
                    delete_total += range.to - range.from;
                }
                else break;
            }

            if (modify) self.ranges.delete_many(delete_start, delete_count);

            self.validate();

            if (maybe_delta) |delta| delta.* = @intCast(i64, new_range.to) - @intCast(i64, new_range.from) - @intCast(i64, delete_total);

            return true;
        }
    };
};

pub export fn EsMemoryFill(from: u64, to: u64, byte: u8) callconv(.C) void
{
    assert(from != 0);
    assert(to != 0);

    var a = @intToPtr(*u8, from);
    var b = @intToPtr(*u8, to);
    while (a != b)
    {
        a.* = byte;
        a = @intToPtr(*u8, @ptrToInt(a) + 1);
    }
}

pub export fn EsMemorySumBytes(source: [*]u8, byte_count: u64) callconv(.C) u8
{
    if (byte_count == 0) return 0;

    var slice = source[0..byte_count];
    var total: u64 = 0;
    for (slice) |byte|
    {
        total += byte;
    }

    return @truncate(u8, total);
}

pub export fn EsMemoryCompare(a: u64, b: u64, byte_count: u64) callconv(.C) i32
{
    if (byte_count == 0) return 0;

    assert(a != 0);
    assert(b != 0);

    const a_slice = @intToPtr([*]u8, a)[0..byte_count];
    const b_slice = @intToPtr([*]u8, b)[0..byte_count];

    for (a_slice) |a_byte, i|
    {
        const b_byte = b_slice[i];

        if (a_byte < b_byte) return -1
        else if (a_byte > b_byte) return 1;
    }

    return 0;
}

pub export fn EsMemoryZero(dst: u64, byte_count: u64) callconv(.C) void
{
    if (byte_count == 0) return;

    var slice = @intToPtr([*]u8, dst)[0..byte_count];
    std.mem.set(u8, slice, 0);
}

pub export fn EsMemoryCopy(dst: u64, src: u64, byte_count: u64) callconv(.C) void
{
    if (byte_count == 0) return;

    const dst_slice = @intToPtr([*]u8, dst)[0..byte_count];
    const src_slice = @intToPtr([*]const u8, src)[0..byte_count];
    std.mem.copy(u8, dst_slice, src_slice);
}

pub export fn EsCRTmemcpy(dst: u64, src: u64, byte_count: u64) callconv(.C) u64
{
    EsMemoryCopy(dst, src, byte_count);
    return dst;
}

pub export fn EsCRTstrlen(str: [*:0]const u8) callconv(.C) u64
{
    var i: u64 = 0;
    while (str[i] != 0)
    {
        i += 1;
    }

    return i;
}

pub export fn EsCRTstrcpy(dst: [*:0]u8, src: [*:0]const u8) callconv(.C) [*:0]u8
{
    const string_length = EsCRTstrlen(src);
    return @intToPtr([*:0]u8, EsCRTmemcpy(@ptrToInt(dst), @ptrToInt(src), string_length + 1));
}

pub export fn EsMemoryCopyReverse(destination: u64, source: u64, byte_count: u64) callconv(.C) void
{
    if (byte_count == 0) return;

    assert(destination != 0);
    assert(source != 0);

    var dst = &(@intToPtr([*]u8, destination)[0..byte_count][byte_count - 1]);
    var src = &(@intToPtr([*]u8, source)[0..byte_count][byte_count - 1]);

    var bytes: u64 = byte_count;
    while (bytes >= 1)
    {
        dst.* = src.*;
        src = @intToPtr(*u8, @ptrToInt(src) - 1);
        dst = @intToPtr(*u8, @ptrToInt(dst) - 1);
        bytes -= 1;
    }
}

const EsGeneric = u64;

pub export fn EsMemoryMove(start_address: u64, end_address: u64, amount: i64, zero_empty_space: bool) callconv(.C) void
{
    if (end_address < start_address) return;

    if (amount > 0)
    {
        const amount_u = @intCast(u64, amount);
        EsMemoryCopyReverse(start_address + amount_u, start_address, end_address - start_address);

        if (zero_empty_space) EsMemoryZero(start_address, amount_u);
    }
    else if (amount < 0)
    {
        const amount_u = @intCast(u64, std.math.absInt(amount) catch unreachable);
        EsMemoryCopy(start_address - amount_u, start_address, end_address - start_address);
        if (zero_empty_space) EsMemoryZero(end_address - amount_u, amount_u);
    }
}

pub export fn EsAssertionFailure(file: [*:0]const u8, line: i32) callconv(.C) void
{
    _ = file; _ = line;
    panic("Assertion failure called");
}

const ArrayHeader = extern struct
{
    length: u64,
    allocated: u64,

};

pub export fn ArrayHeaderGet(array: ?*u64) callconv(.C) *ArrayHeader
{
    return @intToPtr(*ArrayHeader, @ptrToInt(array) - @sizeOf(ArrayHeader));
}

pub export fn ArrayHeaderGetLength(array: ?*u64) callconv(.C) u64
{
    if (array) |arr| return ArrayHeaderGet(arr).length
    else return 0;
}

pub export fn _ArrayMaybeInitialise(array: *?*u64, item_size: u64, heap: *Heap) callconv(.C) bool
{
    const new_length = 4;
    if (@intToPtr(?*ArrayHeader, heap.allocate(@sizeOf(ArrayHeader) + item_size * new_length, true))) |header|
    {
        header.length = 0;
        header.allocated = new_length;
        array.* = @intToPtr(?*u64, @ptrToInt(header) + @sizeOf(ArrayHeader));
        return true;
    }
    else
    {
        return false;
    }
}

pub export fn _ArrayEnsureAllocated(array: *?*u64, minimum_allocated: u64, item_size: u64, additional_header_bytes: u8, heap: *Heap) callconv(.C) bool
{
    if (!_ArrayMaybeInitialise(array, item_size, heap)) return false;

    const old_header = ArrayHeaderGet(array.*);

    if (old_header.allocated >= minimum_allocated) return true;

    _ = additional_header_bytes;

    TODO(@src());

    //if (@intToPtr(?*ArrayHeader, EsHeapReallocate(@ptrToInt(old_header) - additional_header_bytes, @sizeOf(ArrayHeader) + additional_header_bytes + item_size * minimum_allocated, false, heap))) |new_header|
    //{
        //new_header.allocated = minimum_allocated;
        //array.* = @intToPtr(?*u64, @ptrToInt(new_header) + @sizeOf(ArrayHeader) + additional_header_bytes);
        //return true;
    //}
    //else
    //{
        //return false;
    //}
}

pub export fn _ArraySetLength(array: *?*u64, new_length: u64, item_size: u64, additional_header_bytes: u8, heap: *Heap) callconv(.C) bool
{
    if (!_ArrayMaybeInitialise(array, item_size, heap)) return false;

    var header = ArrayHeaderGet(array.*);

    if (header.allocated >= new_length)
    {
        header.length = new_length;
        return true;
    }

    if (!_ArrayEnsureAllocated(array, if (header.allocated * 2 > new_length) header.allocated * 2 else new_length + 16, item_size, additional_header_bytes, heap)) return false;

    header = ArrayHeaderGet(array.*);
    header.length = new_length;
    return true;
}

pub fn memory_move_backwards(comptime T: type, addr: T) std.meta.Int(.signed, @bitSizeOf(T))
{
    return - @intCast(std.meta.Int(.signed, @bitSizeOf(T)), addr);
}

pub export fn _ArrayDelete(array: ?*u64, position: u64, item_size: u64, count: u64) callconv(.C) void
{
    if (count == 0) return;

    const old_array_length = ArrayHeaderGetLength(array);
    if (position >= old_array_length) panic("position out of bounds");
    if (count > old_array_length - position) panic("count out of bounds");
    ArrayHeaderGet(array).length = old_array_length - count;
    const array_address = @ptrToInt(array);
    // @TODO @WARNING @Dangerous @ERROR @PANIC
    EsMemoryMove(array_address + item_size * (position + count), array_address + item_size * old_array_length, memory_move_backwards(u64, item_size) * @intCast(i64, count), false);
}

pub export fn _ArrayDeleteSwap(array: ?*u64, position: u64, item_size: u64) callconv(.C) void
{
    const old_array_length = ArrayHeaderGetLength(array);
    if (position >= old_array_length) panic("position out of bounds");
    ArrayHeaderGet(array).length = old_array_length - 1;
    const array_address = @ptrToInt(array);
    EsMemoryCopy(array_address + item_size * position, array_address * ArrayHeaderGetLength(array), item_size);
}

pub export fn _ArrayInsert(array: *?*u64, item: u64, item_size: u64, maybe_position: i64, additional_header_bytes: u8, heap: *Heap) callconv(.C) u64
{
    const old_array_length = ArrayHeaderGetLength(array.*);
    const position: u64 = if (maybe_position == -1) old_array_length else @intCast(u64, maybe_position);
    if (maybe_position < 0 or position > old_array_length) panic("position out of bounds");
    if (!_ArraySetLength(array, old_array_length + 1, item_size, additional_header_bytes, heap)) return 0;
    const array_address = @ptrToInt(array.*);
    EsMemoryMove(array_address + item_size * position, array_address + item_size * old_array_length, @intCast(i64, item_size), false);
    if (item != 0) EsMemoryCopy(array_address + item_size * position, item, item_size)
    else EsMemoryZero(array_address + item_size * position, item_size);
    return array_address + item_size * position;
}

pub export fn _ArrayInsertMany(array: *?*u64, item_size: u64, maybe_position: i64, insert_count: u64, heap: *Heap) callconv(.C) u64
{
    const old_array_length = ArrayHeaderGetLength(array.*);
    const position: u64 = if (maybe_position == -1) old_array_length else @intCast(u64, maybe_position);
    if (maybe_position < 0 or position > old_array_length) panic("position out of bounds");
    if (!_ArraySetLength(array, old_array_length + insert_count, item_size, 0, heap)) return 0;
    const array_address = @ptrToInt(array.*);
    EsMemoryMove(array_address + item_size * position, array_address + item_size * old_array_length, @intCast(i64, item_size * insert_count), false);
    return array_address + item_size * position;
}

pub export fn _ArrayFree(array: *?*u64, item_size: u64, heap: *Heap) callconv(.C) void
{
    if (array.* == null) return;

    heap.free(@ptrToInt(ArrayHeaderGet(array.*)), @sizeOf(ArrayHeader) + item_size * ArrayHeaderGet(array.*).allocated);
    array.* = null;
}

pub export fn EsCStringLength(maybe_string: ?[*:0]const u8) callconv(.C) u64
{
    if (maybe_string) |string|
    {
        var size: u64 = 0;

        while (string[size] != 0)
        {
            size += 1;
        }

        return size;
    }
    else return 0;
}

pub export fn EsStringCompareRaw(s1: [*:0]const u8, length1: i64, s2: [*:0]const u8, length2: i64) callconv(.C) i32
{
    var len1: u64 = if (length1 == -1) EsCStringLength(s1) else @intCast(u64, length1);
    var len2: u64 = if (length2 == -1) EsCStringLength(s2) else @intCast(u64, length2);

    var i: u64 = 0;
    while (len1 != 0 or len2 != 0) : (i += 1)
    {
        if (len1 == 0) return -1;
        if (len2 == 0) return 1;

        const c1 = s1[i];
        const c2 = s2[i];

        if (c1 != c2) return @intCast(i32, c1) - @intCast(i32, c2);
        len1 -= 1;
        len2 -= 1;
    }

    return 0;
}

pub const Bitset = extern struct
{
    single_usage: [*]u32,
    group_usage: [*]u16, 
    single_usage_count: u64,
    group_usage_count: u64,

    pub fn init(self: *@This(), count: u64, map_all: bool) void
    {
        self.single_usage_count = (count + 31) & ~@as(u64, 31);
        self.group_usage_count = self.single_usage_count / group_size + 1;
        // kernel_address_space
        self.single_usage = @intToPtr([*]u32, address_space.allocate_standard((self.single_usage_count >> 3) + (self.group_usage_count * 2), if (map_all) Region.Flags.from_flag(.fixed) else Region.Flags.empty(), 0, true));
        self.group_usage = @intToPtr([*]u16, @ptrToInt(self.single_usage) + ((self.single_usage_count >> 4) * @sizeOf(u16)));
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

    pub fn get(self: *@This(), count: u64, alignment: u64, asked_below: u64) u64
    {
        var return_value: u64 = std.math.maxInt(u64);

        const below = blk:
        {
            if (asked_below != 0)
            {
                if (asked_below < count) return return_value;
                break :blk asked_below - count;
            }
            else break :blk asked_below;
        };

        if (count == 1 and alignment == 1)
        {
            for (self.group_usage[0..self.group_usage_count]) |*group_usage, group_i|
            {
                if (group_usage.* != 0)
                {
                    var single_i: u64 = 0;
                    while (single_i < group_size) : (single_i += 1)
                    {
                        const index = group_i * group_size + single_i;
                        if (below != 0 and index >= below) return return_value;
                        const index_mask = (@as(u32, 1) << @intCast(u5, index));
                        if (self.single_usage[index >> 5] & index_mask != 0)
                        {
                            self.single_usage[index >> 5] &= ~index_mask;
                            self.group_usage[group_i] -= 1;
                            return index;
                        }
                    }
                }
            }
        }
        else if (count == 16 and alignment == 16)
        {
            TODO(@src());
        }
        else if (count == 32 and alignment == 32)
        {
            TODO(@src());
        }
        else
        {
            var found: u64 = 0;
            var start: u64 = 0;

            for (self.group_usage[0..self.group_usage_count]) |*group_usage, group_i|
            {
                if (group_usage.* == 0)
                {
                    found = 0;
                    continue;
                }

                var single_i: u64 = 0;
                while (single_i < group_size) : (single_i += 1)
                {
                    const index = group_i * group_size + single_i;
                    const index_mask = (@as(u32, 1) << @truncate(u5, index));

                    if (self.single_usage[index >> 5] & index_mask  != 0)
                    {
                        if (found == 0)
                        {
                            if (index >= below and below != 0) return return_value;
                            if (index % alignment != 0) continue;

                            start = index;
                        }

                        found += 1;
                    }
                    else
                    {
                        found = 0;
                    }

                    if (found == count)
                    {
                        return_value = start;

                        var i: u64 = 0;
                        while (i < count) : (i += 1)
                        {
                            const index_b = start + i;
                            self.single_usage[index_b >> 5] &= ~((@as(u32, 1) << @truncate(u5, index_b)));
                        }

                        return return_value;
                    }
                }
            }
        }

        return return_value;
    }

    const group_size = 0x1000;
};

pub fn round_down(comptime T: type, value: T, divisor: T) T
{
    return value / divisor * divisor;
}

pub fn round_up(comptime T: type, value: T, divisor: T) T
{
    return (value + (divisor - 1)) / divisor * divisor;
}

pub const RandomNumberGenerator = extern struct
{
    s: [4]u64,
    lock: UserSpinlock,

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

    const UserSpinlock = extern struct
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
            if (self.state.read_volatile() == 0) panic("spinlock not acquired");
            self.state.write_volatile(0);
            @fence(.SeqCst);
        }
    };
};

pub var rng: RandomNumberGenerator = undefined;

pub fn log_ex(buffer: []u8, buffer_lock: *Spinlock, comptime format: []const u8, args: anytype) void
{
    buffer_lock.acquire();
    var log_slice = std.fmt.bufPrint(buffer[0..], format, args)
    catch |err|
    {
        var _format_buffer: [512]u8 = undefined;
        const error_str = std.fmt.bufPrint(_format_buffer[0..], "Unable to print: {}", .{err}) catch unreachable;
        panic(error_str);
    };
    serial.write(log_slice);
    buffer_lock.release();
}

var format_buffer: [0x4000]u8 align(0x1000) = undefined;
var format_lock: Spinlock = undefined;
pub fn log(comptime format: []const u8, args: anytype) void
{
    log_ex(&format_buffer, &format_lock, format, args);
}

export var shutdownEvent: Event = undefined;
pub export fn KernelInitialise() callconv(.C) void
{
    // Serial driver is initialized before calling this function, so we can safely invoke the serial debugging routines without worrying about it
    serial.write("KernelInitialise\n");
    _ = Process.spawn(.kernel).?;
    memory.init();
    // Currently it felt impossible to pass arguments to this function
    _ = Thread.spawn(arch.GetKernelMainAddress(), 0, Thread.Flags.empty(), null, 0);
    arch.init();
    scheduler.started.write_volatile(true);
}

pub export fn KernelMain(_: u64) callconv(.C) void
{
    serial.write("KernelMain\n");
    desktop_process = Process.spawn(.desktop).?;
    drivers.init();
    files.parse_superblock();
    scheduling.start_desktop_process();
    _ = shutdownEvent.wait();
}

pub const Workgroup = extern struct
{
    remaining: Volatile(u64),
    success: Volatile(u64),
    event: Event,

    pub fn init(self: *@This()) void
    {
        self.remaining.write_volatile(1);
        self.success.write_volatile(1);
        self.event.reset();
    }

    pub fn wait(self: *@This()) bool
    {
        if (self.remaining.atomic_fetch_sub(1) != 1) _ = self.event.wait();
        if (self.remaining.read_volatile() != 0) panic("Expected remaining operations to be 0 after event set");

        return self.success.read_volatile() != 0;
    }

    pub fn start(self: *@This()) void
    {
        if (self.remaining.atomic_fetch_add(1) == 0) panic("Could not start operation on completed dispatch group");
    }

    pub fn end(self: *@This(), success: bool) void
    {
        if (!success)
        {
            self.success.write_volatile(0);
            @fence(.SeqCst);
        }

        if (self.remaining.atomic_fetch_sub(1) == 1) _ = self.event.set(false);
    }
};

extern fn KSwitchThreadAfterIRQ() callconv(.C) void;

pub const Timeout = extern struct
{
    end: u64,

    pub fn new(ms: u64) callconv(.Inline) Timeout
    {
        return Timeout
        {
            .end = scheduler.time_ms + ms,
        };
    }

    pub fn hit(self: @This()) callconv(.Inline) bool
    {
        return scheduler.time_ms >= self.end;
    }
};

pub fn align_u64(address: u64, alignment: u64) u64
{
    const mask = alignment - 1;
    assert(alignment & mask == 0);
    return (address + mask) & ~mask;
}


extern fn CreateLoadExecutableThread(process: *Process) callconv(.C) ?*Thread;

pub const CrashReason = extern struct
{
    error_code: FatalError,
    during_system_call: i32,
};

pub const Errors = struct
{
    pub const ES_ERROR_BLOCK_ACCESS_INVALID: Error = -74;
    pub const ES_ERROR_DRIVE_CONTROLLER_REPORTED: Error = -35;
    pub const ES_ERROR_UNSUPPORTED_EXECUTABLE: Error = -62;
    pub const ES_ERROR_INSUFFICIENT_RESOURCES: Error = -52;
};
