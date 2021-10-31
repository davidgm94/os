const std = @import("std");
const Array = @import("array.zig").Array;
const Kernel = @import("kernel.zig");
// @TODO: improve implementation

pub fn Short(comptime T: type) type
{
    return struct
    {
        const Self = @This();
        const Key = u64;

        pub const Item = struct
        {
            value: ?*T,
            children: [2]?*Item,
            parent: ?*Item,
            key: Key,
            height: i32,

            fn rotate_left(self: *Item) *Item
            {
                // self = x
                const y = self.children[1].?;
                const t = self.children[0];
                y.children[0] = self;
                self.children[1] = t;

                self.parent = y;
                if (t) |t_unwrapped| t_unwrapped.parent = self;

                self.compute_height();
                y.compute_height();

                return y;
            }

            fn rotate_right(self: *Item) *Item
            {
                // self = y
                const x = self.children[0].?;
                x.children[1] = self;
                const t = self.children[1];
                self.children[0] = t;

                self.parent = x;
                if (t) |t_unwrapped| t_unwrapped.parent = self;

                self.compute_height();
                x.compute_height();

                return x;
            }

            fn compute_height(self: *Item) void
            {
                const left_height = if (self.children[0]) |child0| child0.height else 0;
                const right_height = if (self.children[1]) |child1| child1.height else 0;
                const balance = left_height - right_height;
                self.height = 1 + if (balance > 0) left_height else right_height;
            }
        };

        pub const DuplicateKeyPolicy = enum
        {
            panic,
            fail,
            allow,
        };

        root: ?*Item,

        const InsertError = error
        {
            duplicate,
        };

        pub fn insert(self: *Self, item: *Item, value: *T, key: Key, duplicate_key_policy: DuplicateKeyPolicy) !void
        {
            item.key = key;
            item.children[0] = null;
            item.children[1] = null;
            item.value = value;
            item.height = 1;

            var link = &self.root;
            var parent: ?*Item = null;

            while (true)
            {
                const maybe_node = link.*;

                if (maybe_node) |node|
                {
                    const compare_result = compare(item.key, node.key);
                    if (compare_result == 0)
                    {
                        if (duplicate_key_policy == .panic)
                        {
                            Kernel.Arch.CPU_stop();
                        }
                        else if (duplicate_key_policy == .fail)
                        {
                            return InsertError.duplicate;
                        }
                    }

                    link = @intToPtr(*?*Item, @ptrToInt(&node.children) + @as(u64, @boolToInt(compare_result > 0)) * @sizeOf(u64));
                    parent = node;
                }
                else
                {
                    link.* = item;
                    item.parent = parent;
                    break;
                }
            }

            var fake_root = std.mem.zeroes(Item);
            self.root.?.parent = &fake_root;
            fake_root.children[0] = self.root;

            var item_iterator: *Item = item.parent.?;

            while (@ptrToInt(item_iterator) != @ptrToInt(&fake_root))
            {
                const left_height = if (item_iterator.children[0]) |child0| child0.height else 0;
                const right_height = if (item_iterator.children[1]) |child1| child1.height else 0;
                const balance = left_height - right_height;

                item_iterator.height = (if (balance > 0) left_height else right_height) + 1;
                var new_root: ?*Item = null;
                var old_parent: ?*Item = item_iterator.parent;

                if (balance > 1 and compare(key, item_iterator.children[0].?.key) <= 0)
                {
                    const right_rotation = item_iterator.rotate_right();
                    new_root = right_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.?.children[1] == item_iterator);
                    old_parent.?.children[old_parent_child_index] = right_rotation;
                }
                else if (balance > 1 and compare(key, item_iterator.children[0].?.key) > 0 and item_iterator.children[0].?.children[1] != null)
                {
                    item_iterator.children[0] = item_iterator.children[0].?.rotate_left();
                    item_iterator.children[0].?.parent = item_iterator;
                    const right_rotation = item_iterator.rotate_right();
                    new_root = right_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.?.children[1] == item_iterator);
                    old_parent.?.children[old_parent_child_index] = right_rotation;
                }
                else if (balance < -1 and compare(key, item_iterator.children[1].?.key) > 0)
                {
                    const left_rotation = item_iterator.rotate_left();
                    new_root = left_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.?.children[1] == item_iterator);
                    old_parent.?.children[old_parent_child_index] = left_rotation;
                }
                else if (balance < -1 and compare(key, item_iterator.children[1].?.key) <= 0 and item_iterator.children[1].?.children[0] != null)
                {
                    item_iterator.children[1] = item_iterator.children[1].?.rotate_right();
                    item_iterator.children[1].?.parent = item_iterator;
                    const left_rotation = item_iterator.rotate_left();
                    new_root = left_rotation;
                    const old_parent_child_index = @boolToInt(old_parent.?.children[1] == item_iterator);
                    old_parent.?.children[old_parent_child_index] = left_rotation;
                }

                if (new_root) |new_root_unwrapped| new_root_unwrapped.parent = old_parent;
                item_iterator = old_parent.?;
            }

            self.root = fake_root.children[0];
            self.root.?.parent = null;
        }

        fn compare(key_1: Key, key_2: Key) i32
        {
            if (key_1 < key_2) return -1;
            if (key_1 > key_2) return 1;
            return 0;
        }
    };
}
