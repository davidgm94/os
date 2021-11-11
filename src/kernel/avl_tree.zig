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
            tree: ?*Self,
            height: i32,

            fn rotate_left(self: *Item) *Item
            {
                const x = self;
                const y = x.children[1].?;
                const t = y.children[0];
                y.children[0] = x;
                x.children[1] = t;

                x.parent = y;
                if (t) |t_unwrapped| t_unwrapped.parent = x;

                x.compute_height();
                y.compute_height();

                return y;
            }

            fn rotate_right(self: *Item) *Item
            {
                const y = self;
                const x = y.children[0].?;
                const t = x.children[1].?;

                x.children[1] = y;
                y.children[0] = t;

                y.parent = x;
                t.parent = y;

                y.compute_height();
                x.compute_height();

                return x;
            }

            fn compute_height(self: *Item) void
            {
                const left_height = if (self.children[0]) |child0| child0.height else 0;
                const right_height = if (self.children[1]) |child1| child1.height else 0;
                const balance = left_height - right_height;
                self.height = 1 + (if (balance > 0) left_height else right_height);
            }

            fn validate_item(self: *Item, before: bool, tree: *Self, parent: ?*Item, maybe_depth: ?i32) i32
            {
                const depth = maybe_depth orelse 0;
                if (self.parent != parent) Kernel.Arch.CPU_stop();
                if (self.tree != tree) Kernel.Arch.CPU_stop();
                
                const left_height = blk:
                {
                    if (self.children[0]) |left|
                    {
                        if (compare(left.key, self.key) > 0) Kernel.Arch.CPU_stop();
                        break :blk left.validate_item(before, tree, self, depth + 1);
                    }
                    else
                    {
                        break :blk 0;
                    }
                };

                const right_height = blk: 
                {
                    if (self.children[1]) |right|
                    {
                        if (compare(right.key, self.key) < 0) Kernel.Arch.CPU_stop();
                        break :blk right.validate_item(before, tree, self, depth + 1);
                    }
                    else
                    {
                        break :blk 0;
                    }
                };

                const height = 1 + (if (left_height > right_height) left_height else right_height);
                if (height != self.height) Kernel.Arch.CPU_stop();
                return height;
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

        pub fn insert(self: *Self, item: *Item, value: *T, key: Key, duplicate_key_policy: DuplicateKeyPolicy) InsertError!void
        {
            self.validate(true);
            if (item.tree != null) Kernel.Arch.CPU_stop();
            item.tree = self;

            item.key = key;
            item.children[0] = null;
            item.children[1] = null;
            item.value = value;
            item.height = 1;

            var link = &self.root;
            var parent: ?*Item = null;

            while (true)
            {
                if (link.*) |link_node|
                {
                    const compare_result = compare(item.key, link_node.key);
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

                    const link_index = @boolToInt(compare_result > 0);
                    link = &link_node.children[link_index];
                    parent = link_node;
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
            fake_root.tree = self;
            fake_root.children[0] = self.root;

            var item_iterator: *Item = item.parent.?;

            while (item_iterator != &fake_root)
            {
                const left_height = if (item_iterator.children[0]) |child0| child0.height else 0;
                const right_height = if (item_iterator.children[1]) |child1| child1.height else 0;
                const balance = left_height - right_height;

                item_iterator.height = (if (balance > 0) left_height else right_height) + 1;
                var old_parent: *Item = item_iterator.parent.?;

                if (balance > 1)
                {
                    const left_key = item_iterator.children[0].?.key;
                    const left_compare = compare(key, left_key);

                    if (left_compare <= 0)
                    {
                        const right_rotation = item_iterator.rotate_right();
                        internal_update_old_parent(old_parent, item_iterator, right_rotation);
                    }
                    else if (item_iterator.children[0].?.children[1] != null)
                    {
                        item_iterator.children[0] = item_iterator.children[0].?.rotate_left();
                        item_iterator.children[0].?.parent = item_iterator;
                        const right_rotation = item_iterator.rotate_right();
                        internal_update_old_parent(old_parent, item_iterator, right_rotation);
                    }
                }
                else if (balance < -1)
                {
                    const right_key = item_iterator.children[1].?.key;
                    const right_compare = compare(key, right_key);

                    if (right_compare > 0)
                    {
                        const left_rotation = item_iterator.rotate_left();
                        internal_update_old_parent(old_parent, item_iterator, left_rotation);
                    }
                    else if (item_iterator.children[1].?.children[0] != null)
                    {
                        item_iterator.children[1] = item_iterator.children[1].?.rotate_right();
                        item_iterator.children[1].?.parent = item_iterator;
                        const left_rotation = item_iterator.rotate_left();
                        internal_update_old_parent(old_parent, item_iterator, left_rotation);
                    }
                }

                item_iterator = old_parent;
            }

            self.root = fake_root.children[0];
            self.root.?.parent = null;

            self.validate(false);
        }

        pub const SearchMode = enum
        {
            exact,
            smallest_above_or_equal,
            largest_below_or_equal,
        };

        pub fn find(self: *Self, key: Key, comptime search_mode: SearchMode) ?*Item
        {
            self.validate(true);
            return self.find_recursive(self.root, key, search_mode);
        }

        pub fn find_recursive(self: *Self, maybe_root: ?*Item, key: Key, comptime search_mode: SearchMode) ?*Item
        {
            if (maybe_root) |root|
            {
                const tree_compare = compare(root.key, key);
                if (tree_compare == 0) return root;

                switch (search_mode)
                {
                    .exact =>
                    {
                        const child_index = @boolToInt(tree_compare < 0);
                        return self.find_recursive(root.children[child_index], key, search_mode);
                    },
                    .smallest_above_or_equal =>
                    {
                        if (tree_compare > 0)
                        {
                            if (self.find_recursive(root.children[0], key, search_mode)) |item| return item
                            else return root;
                        }
                        else
                        {
                            return self.find_recursive(root.children[1], key, search_mode);
                        }
                    },
                    .largest_below_or_equal =>
                    {
                        if (tree_compare < 0)
                        {
                            if (self.find_recursive(root.children[1], key, search_mode)) |item| return item
                            else return root;
                        }
                        else
                        {
                            return self.find_recursive(root.children[0], key, search_mode);
                        }
                    },
                }
            }
            else
            {
                return null;
            }
        }

        fn internal_update_old_parent(old_parent: *Item, item_iterator: *Item, new_value: *Item) void
        {
            const old_parent_child_index = @boolToInt(old_parent.children[1] == item_iterator);
            old_parent.children[old_parent_child_index] = new_value;
            old_parent.children[old_parent_child_index].?.parent = old_parent;
        }

        pub fn remove(self: *Self, item: *Item) void
        {
            self.validate(true);
            if (item.tree != self) Kernel.Arch.CPU_stop();

            var fake_root = std.mem.zeroes(Item);
            self.root.?.parent = &fake_root;
            fake_root.tree = self;
            fake_root.children[0] = self.root;

            if (item.children[0] != null and item.children[1] != null)
            {
                const smallest_key = 0;
                const item_to_swap = self.find_recursive(item.children[1], smallest_key, .smallest_above_or_equal) orelse unreachable;
                swap_items(item_to_swap, item);
            }

            var item_iterator = item;
            const link_index = @boolToInt(item_iterator.parent.?.children[1] == item_iterator);
            var link = &item_iterator.parent.?.children[link_index];
            const child_index = @boolToInt(item_iterator.children[0] == null);
            link.* = item_iterator.children[child_index];
            item_iterator.tree = null;

            if (link.*) |link_unwrapped|
            {
                link_unwrapped.parent = item_iterator.parent;
                item_iterator = link_unwrapped;
            }
            else
            {
                item_iterator = item_iterator.parent.?;
            }

            while (item_iterator != &fake_root)
            {
                const left_height = if (item_iterator.children[0] != null) item_iterator.children[0].?.height else 0;
                const right_height = if (item_iterator.children[1] != null) item_iterator.children[1].?.height else 0;
                const balance = left_height - right_height;

                item_iterator.height = 1 + (if (balance > 0) left_height else right_height);

                var old_parent: *Item = item_iterator.parent.?;

                if (balance > 1)
                {
                    if (get_balance(item_iterator.children[0]) < 0)
                    {
                        item_iterator.children[0] = item_iterator.children[0].?.rotate_left();
                        item_iterator.children[0].?.parent = item_iterator;
                    }
                    const right_rotation = item_iterator.rotate_right();
                    internal_update_old_parent(old_parent, item_iterator, right_rotation);
                }
                else if (balance < -1)
                {
                    if (get_balance(item_iterator.children[1]) > 0)
                    {
                        item_iterator.children[1] = item_iterator.children[1].?.rotate_right();
                        item_iterator.children[1].?.parent = item_iterator;
                    }

                    const left_rotation = item_iterator.rotate_left();
                    internal_update_old_parent(old_parent, item_iterator, left_rotation);
                }

                item_iterator = old_parent;
            }

            self.root = fake_root.children[0];

            if (self.root != null)
            {
                if (self.root.?.parent != &fake_root) Kernel.Arch.CPU_stop();
                self.root.?.parent = null;
            }

            self.validate(false);
        }

        fn get_balance(maybe_item: ?*Item) i32
        {
            if (maybe_item) |item|
            {
                const left_height = if (item.children[0] != null) item.children[0].?.height else 0;
                const right_height = if (item.children[1] != null) item.children[1].?.height else 0;
                const balance = left_height - right_height;
                return balance;
            }
            else return 0;
        }

        fn swap_items(a: *Item, b: *Item) void
        {
            a.parent.?.children[@boolToInt(a.parent.?.children[1] == a)] = b;
            b.parent.?.children[@boolToInt(b.parent.?.children[1] == b)] = a;

            var ta = a.*;
            var tb = b.*;

            a.parent = tb.parent;
            b.parent = ta.parent;
            a.height = tb.height;
            b.height = ta.height;

            a.children[0] = tb.children[0];
            a.children[1] = tb.children[1];
            b.children[0] = ta.children[0];
            b.children[1] = ta.children[1];

            if (a.children[0] != null) a.children[0].?.parent = a;
            if (a.children[1] != null) a.children[1].?.parent = a;
            if (b.children[0] != null) b.children[0].?.parent = b;
            if (b.children[1] != null) b.children[1].?.parent = b;
        }

        fn compare(key_1: Key, key_2: Key) i32
        {
            if (key_1 < key_2) return -1;
            if (key_1 > key_2) return 1;
            return 0;
        }

        fn validate(self: *Self, before: bool) void
        {
            if (self.root) |root|
            {
                _ = root.validate_item(before, self, null, null);
            }
        }
    };
}
