const std = @import("std");
const Kernel = @import("kernel.zig");
const Array = @import("array.zig").Array;
const AVLTree = @import("avl_tree.zig").Short;

const Memory = @This();

// @Guard
const guard_pages = false;

const zero_page_threshold = 16;

pub fn init() void
{
    // initialize core and kernel memory space
    {
        core_regions[0].more.core.used = false;
        core_region_count = 1;
        Kernel.Arch.Memory.init();

        const region = @intToPtr(*Region, Kernel.core_heap.allocate(@sizeOf(Region), true) catch unreachable);
        region.base_address = Kernel.Arch.Memory.kernel_space_start;
        region.page_count = Kernel.Arch.Memory.kernel_space_size / Kernel.Arch.Page.size;

        Kernel.kernel_memory_space.free_regions_base.insert(&region.more.non_core.item_base, region, region.base_address, .panic) catch unreachable;
        Kernel.kernel_memory_space.free_regions_size.insert(&region.more.non_core.item.size, region, region.page_count, .allow) catch unreachable;
    }

    // initialize physical memory management
    {
        // @Spinlock
        const manipulation_region = reserve(&Kernel.kernel_memory_space, Physical.manipulation_region_page_count * Kernel.Arch.Page.size, 0, null, null) orelse
        {
            Kernel.Arch.CPU_stop();
        };
        Kernel.physical_memory_allocator.manipulation_region = manipulation_region.base_address;
        // @Spinlock
        
        const page_frame_db_count = (Kernel.Arch.physical_memory_highest_get() + (Kernel.Arch.Page.size << 3)) >> Kernel.Arch.Page.bit_count;
        const page_frames = standard_allocate(&Kernel.kernel_memory_space, page_frame_db_count * @sizeOf(PageFrame), 1 << @enumToInt(Region.Flags.fixed), null, null) catch unreachable;
        Kernel.physical_memory_allocator.page_frames = @intToPtr([*]volatile PageFrame, @ptrToInt(page_frames.ptr))[0..page_frame_db_count];
        Kernel.physical_memory_allocator.free_or_zeroed_page_bitset.initialize(page_frame_db_count, true);

        Physical.insert_free_pages_start();
        const commit_limit = populate_pageframe_database();
        Physical.insert_free_pages_end();
        Kernel.physical_memory_allocator.commit_fixed_limit = commit_limit;
        Kernel.physical_memory_allocator.commit_limit = commit_limit;

        Kernel.physical_memory_allocator.page_frame_db_initialized = true;

        // @TODO: file cache
        //

        //Kernel.physical_memory_allocator.commit_lockfree(Physical.manipulation_region_page_count * Kernel.Arch.Page.size, true) catch unreachable;
        // @TODO: several paging threads
    }
}

fn populate_pageframe_database() u64
{
    var commit_limit: u64 = 0;

    const physical_memory_regions = Kernel.Arch.physical_memory_regions_get();
    for (physical_memory_regions.ptr[0..physical_memory_regions.count]) |region|
    {
        const base = region.base_address >> Kernel.Arch.Page.bit_count;
        const count = region.page_count;
        commit_limit += count;

        var page_i: u64 = 0;
        while (page_i < count) : (page_i += 1)
        {
            const page = base + page_i;
            Kernel.physical_memory_allocator.insert_free_pages_next(page);
        }
    }

    physical_memory_regions.page_count = 0;
    return commit_limit;
}

const Bitset = struct
{
    const Self = @This();
    const bitset_group_size = 0x1000;

    single_usage: [*]u32,
    group_usage: [*]u16,
    single_count: u64,
    group_count: u64,

    fn initialize(self: *Self, count: u64, map_all: bool) void
    {
        self.single_count = (count + 31) & ~@as(@TypeOf(count), 31);
        self.group_count = self.single_count / bitset_group_size + 1;

        const allocation_result = standard_allocate(&Kernel.kernel_memory_space, (self.single_count >> 3) + (self.group_count * 2), if (map_all) 1 << @enumToInt(Region.Flags.fixed) else 0, null, null) catch unreachable;
        self.single_usage = @intToPtr([*]u32, @ptrToInt(allocation_result.ptr));
        self.group_usage = @intToPtr([*]u16, @ptrToInt(self.single_usage) + (@sizeOf(u16) * (self.single_count >> 4)));
    }

    fn put(self: *Self, index: u64) void
    {
        self.single_usage[index >> 5] |= @as(u32, 1) << @truncate(u5, index);
        self.group_usage[index / bitset_group_size] += 1;
    }

    fn take(self: *Self, index: u64) void
    {
        const group = index / bitset_group_size;
        self.group_usage[group] -= 1;
        self.single_usage[index >> 5] &= ~(@as(u32, 1) << @truncate(u5, index & 31));
    }
};

const PageFrame = struct
{
    state: enum(u8)
    {
        unusable,
        bad,
        zeroed,
        free,
        standby,
        active,
    },
    flags: u8,
    cache_reference: *u64,
    value: extern union
    {
        list: struct
        {
            next: u64,
            previous: *volatile u64,
        },
        active: struct
        {
            references: u64,
        },
    },
};

pub const Space = struct
{
    virtual_address_space: Kernel.Arch.VirtualAddressSpace,

    free_regions_base: AVLTree(Region),
    free_regions_size: AVLTree(Region),
    used_regions: AVLTree(Region),

    commit: u64,
    reserve: u64,
    user: bool,
};

const critical_available_page_count_threshold = 0x100000 / Kernel.Arch.Page.size;

pub const PhysicalRegions = extern struct
{
    ptr: [*]PhysicalRegion,
    count: u64,
    page_count: u64,
    original_page_count: u64,
    index: u64,
};

pub var core_regions = @intToPtr([*]Memory.Region, Kernel.Arch.Memory.core_region_start);
pub var core_region_count: u64 = 0;
pub var core_region_array_commit: u64 = 0;

var early_zero_buffer align(Kernel.Arch.Page.size) = [_]u8 { undefined } ** Kernel.Arch.Page.size;

pub const Region = struct
{
    base_address: u64,
    page_count: u64,
    flags: u32,

    data: Data,

    more: More,

    pub const Flags = enum(u8)
    {
        fixed = 0,
        not_cacheable = 1,
        no_commit_tracking = 2,
        read_only = 3,
        copy_on_write = 4,
        write_combining = 5,
        executable = 6,
        user = 7,
        physical = 8,
        normal = 9,
        shared = 10,
        guard = 11,
        cache = 12,
        file = 13,
    };

    const More = extern union
    {
        core: struct
        {
            used: bool,
        },
        non_core: struct
        {
            item_base: AVLTree(Region).Item,

            item: extern union
            {
                size: AVLTree(Region).Item,
                // @TODO: add itemnonguard
            },
        },
    };

    const Data = extern union
    {
        normal: struct
        {
            commit: Range.Set,
            commit_page_count: u64,
            guard_before: ?*Region,
            guard_after: ?*Region,
        },
        physical: struct
        {
            offset: u64,
        },

        fn zero_init() Data
        {
            return Data
            {
                .normal = .
                {
                    .commit = Range.Set
                    {
                        .ranges = Array(Range).zero_init(),
                        .contiguous = 0,
                    },
                    .commit_page_count = 0,
                    .guard_before = null,
                    .guard_after = null,
                },
            };
        }
    };

    // TODO: (...)
};


const Range = struct
{
    from: u64,
    to: u64,

    const Set = struct
    {
        ranges: Array(Range),
        contiguous: u64,

        const SetError = error
        {
            normalize,
            insert,
        };

        fn set(self: *Self, from: u64, to: u64, maybe_delta: ?*i64, modify: bool) SetError!void
        {
            if (to <= from) Kernel.Arch.CPU_stop();

            if (self.ranges.items.len == 0)
            {
                if (maybe_delta) |delta|
                {
                    if (from >= self.contiguous) delta.* = @intCast(i64, to - from)
                    else if (to >= self.contiguous) delta.* = @intCast(i64, to - self.contiguous)
                    else delta.* = 0;
                }

                if (!modify) return;

                if (from <= self.contiguous)
                {
                    if (to > self.contiguous) self.contiguous = to;

                    return;
                }

                self.normalize() catch return SetError.failed_to_normalize;
            }

            var new_range: Range = blk:
            {
                const maybe_left = self.find(from, true);
                const maybe_right = self.find(to, true);

                break :blk Range
                {
                    .from = if (maybe_left) |left| left.from else from,
                    .to = if (maybe_right) |right| right.to else to,
                };
            };

            var i: u64 = 0;

            while (i <= self.ranges.items.len) : (i += 1)
            {
                if (i == self.ranges.items.len or self.ranges.items[i].to > new_range.from)
                {
                    if (modify)
                    {
                        _ = self.ranges.insert(new_range, i) orelse return SetError.insert;

                        i += 1;
                    }

                    break;
                }
            }

            const delete_start = i;
            var delete_count: u64 = 0;
            var delete_total: u64 = 0;

            for (self.ranges.items) |range|
            {
                const overlap = (range.from >= new_range.from and range.from <= new_range.to) or (range.to >= new_range.from and range.to <= new_range.to);
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
                delta.* = @intCast(i64, new_range.to - new_range.from - delete_total);
            }
        }

        fn normalize(self: *Self) !void
        {
            _ = self;
            Kernel.Arch.CPU_stop();
        }

        fn validate(self: *Self) void
        {
            // @TODO:
            _ = self;
        }

        fn find(self: *Self, offset: u64, touching: bool) ?*Range
        {
            if (self.ranges.items.len == 0) return null;

            var low: i64 = 0;
            var high = @intCast(i64, self.ranges.items.len) - 1;

            while (low <= high)
            {
                const i = low + @divTrunc(high - low, 2);
                const range = &self.ranges.items[@intCast(u64, i)];

                if (range.from <= offset and (offset < range.to or (touching and offset <= range.to))) return range
                else if (range.from <= offset) low = i + 1
                else high = i - 1;
            }

            return null;
        }

        fn contains(self: *Self, offset: u64) bool
        {
            if (self.ranges.items.len != 0) return self.find(offset, false) != null
            else return offset < self.contiguous;
        }

        const Self = @This();
    };
};

pub const PhysicalRegion = struct
{
    base_address: u64,
    page_count: u64,
};

const shared_entry_presence = 1;

pub const Physical = struct
{
    pub const manipulation_region_page_count = 0x10;

    pub const Flags = enum(u8)
    {
        can_fail = 0,
        commit_now = 1,
        zeroed = 2,
        lock_acquired = 3,

        fn included(flags: u32, comptime desired_flag: Flags) callconv(.Inline) bool
        {
            return (flags & (1 << @enumToInt(desired_flag))) != 0;
        }
    };

    pub const Allocator = struct
    {
        page_frames: []volatile PageFrame,

        first_free_page: u64,
        first_zeroed_page: u64,
        first_standby_page: u64,
        last_standby_page: u64,
        free_or_zeroed_page_bitset: Bitset, // for large pages

        zeroed_page_count: u64,
        free_page_count: u64,
        standby_page_count: u64,
        active_page_count: u64,

        commit_fixed: u64,
        commit_pageable: u64,
        commit_fixed_limit: u64,
        commit_limit: u64,

        next_region_to_balance: ?*Region,

        manipulation_region: u64,

        page_frame_db_initialized: bool,

        pub const CommitError = error
        {
            FixedCommitError,
            FixedCommitThresholdCrossed,
            PageableCommitError,
        };

        pub fn allocate_lockfree(self: *Allocator, flags: u32, maybe_count: ?u64, maybe_alignment: ?u64, maybe_below: ?u64) u64
        {
            const count = maybe_count orelse 1;
            const alignment = maybe_alignment orelse 1;
            const below = maybe_below orelse 0;

            var commit_now = count * Kernel.Arch.Page.size;

            if (Flags.included(flags, .commit_now))
            {
                self.commit_lockfree(commit_now, true) catch
                {
                    return 0;
                };
            }
            else
            {
                commit_now = 0;
            }

            const simple = count == 1 and alignment == 1 and below == 0;

            if (!Kernel.physical_memory_allocator.page_frame_db_initialized)
            {
                if (!simple)
                {
                    Kernel.Arch.CPU_stop();
                }

                const page = Kernel.Arch.early_allocate_page();

                if (flags & (1 << @enumToInt(Flags.zeroed)) != 0)
                {
                    // @TODO: hack
                    Kernel.Arch.Page.map(&Kernel.core_memory_space, page, @ptrToInt(&early_zero_buffer), 1 << @enumToInt(Kernel.Arch.Page.MapFlags.overwrite) | 1 << @enumToInt(Kernel.Arch.Page.MapFlags.no_new_tables) | 1 << @enumToInt(Kernel.Arch.Page.MapFlags.frame_lock_acquired)) catch
                    {
                        // ignore the error for now
                    };
                    std.mem.set(u8, early_zero_buffer[0..], 0);
                }

                return page;
            }
            else if (!simple)
            {
                Kernel.Arch.CPU_stop();
            }
            else
            {
                var not_zeroed = false;
                var page = Kernel.physical_memory_allocator.first_zeroed_page;
                if (page == 0)
                {
                    page = Kernel.physical_memory_allocator.first_free_page;
                    not_zeroed = true;
                }
                if (page == 0)
                {
                    page = Kernel.physical_memory_allocator.last_standby_page;
                    not_zeroed = true;
                }

                if (page != 0)
                {
                    var frame = &Kernel.physical_memory_allocator.page_frames[page];

                    if (frame.state == .active) Kernel.Arch.CPU_stop();

                    if (frame.state == .standby)
                    {
                        if (frame.cache_reference.* != (page << Kernel.Arch.Page.bit_count | shared_entry_presence)) Kernel.Arch.CPU_stop();

                        frame.cache_reference.* = 0;
                    }
                    else
                    {
                        Kernel.physical_memory_allocator.free_or_zeroed_page_bitset.take(page);
                    }

                    self.activate_pages(page, 1, flags);

                    var address = page << Kernel.Arch.Page.bit_count;
                    if (not_zeroed and (flags & (1 << @enumToInt(Physical.Flags.zeroed)) != 0)) pm_zero(@ptrCast([*]u64, &address), 1, false);
                    return address;
                }

                Kernel.Arch.CPU_stop();
            }

            // Failure:
            if (flags & (1 << @enumToInt(Flags.can_fail)) == 0)
            {
                Kernel.Arch.CPU_stop();
            }

            self.decommit(commit_now, true);
            return 0;
        }

        fn decommit(self: *Allocator, byte_count: u64, fixed: bool) void
        {
            if (byte_count & (Kernel.Arch.Page.size - 1) != 0) Kernel.Arch.CPU_stop();

            const needed_page_count = byte_count / Kernel.Arch.Page.size;

            // @Spinlock
            if (fixed)
            {
                if (self.commit_fixed < needed_page_count) Kernel.Arch.CPU_stop();
                self.commit_fixed -= needed_page_count;
            }
            else
            {
                if (self.commit_pageable < needed_page_count) Kernel.Arch.CPU_stop();
                self.commit_pageable -= needed_page_count;
            }
        }

        const CommitRangeError = error
        {
            commit_failed,
        };

        pub fn commit_range(self: *Allocator, memory_space: *Memory.Space, memory_region: *Memory.Region, page_offset: u64, page_count: u64) !void
        {
            //@Spinlock

            if (memory_region.flags & (1 << @enumToInt(Memory.Region.Flags.no_commit_tracking)) != 0)
            {
                Kernel.Arch.CPU_stop();
            }
            if (page_offset >= memory_region.page_count or page_count > memory_region.page_count - page_offset)
            {
                Kernel.Arch.CPU_stop();
            }
            if (~memory_region.flags & (1 << @enumToInt(Memory.Region.Flags.normal)) != 0)
            {
                Kernel.Arch.CPU_stop();
            }

            var delta: i64 = 0;
            memory_region.data.normal.commit.set(page_offset, page_offset + page_count, &delta, false) catch unreachable;

            if (delta < 0) Kernel.Arch.CPU_stop();

            if (delta == 0) return;

            self.commit_lockfree(@intCast(u64, delta) * Kernel.Arch.Page.size, memory_region.flags & (1 << @enumToInt(Region.Flags.fixed)) != 0) catch
            {
                return CommitRangeError.commit_failed;
            };

            memory_region.data.normal.commit_page_count += @intCast(u64, delta);
            memory_space.commit += @intCast(u64, delta);

            if (memory_region.data.normal.commit_page_count > memory_region.page_count)
            {
                Kernel.Arch.CPU_stop();
            }

            memory_region.data.normal.commit.set(page_offset, page_offset + page_count, null, true) catch
            {
                Kernel.Arch.CPU_stop();
            };

            if (memory_region.flags & (1 << @enumToInt(Region.Flags.fixed)) != 0)
            {
                var page_i: u64 = page_offset;
                while (page_i < page_offset + page_count) : (page_i += 1)
                {
                    PageFault.handle(memory_space, memory_region.base_address + page_i * Kernel.Arch.Page.size, 1 << @enumToInt(PageFault.Flags.lock_acquired)) catch
                    {
                        Kernel.Arch.CPU_stop();
                    };
                }
            }
        }

        pub fn commit_lockfree(self: *Allocator, byte_count: u64, fixed: bool) CommitError!void
        {
            if ((byte_count & (Kernel.Arch.Page.size - 1)) != 0) Kernel.Arch.CPU_stop();
            const page_count = byte_count / Kernel.Arch.Page.size;

            if (self.commit_limit != 0)
            {
                if (fixed)
                {
                    if (page_count > self.commit_fixed_limit - self.commit_fixed)
                    {
                        // fail
                        return CommitError.FixedCommitError;
                    }

                    const available_page_count = self.get_available_page_count();
                    if (available_page_count - page_count < critical_available_page_count_threshold)
                    {
                        if (Kernel.Arch.thread_get_current()) |current_thread|
                        {
                            if (!current_thread.is_page_generator)
                            {
                                // fail
                                return CommitError.FixedCommitThresholdCrossed;
                            }
                        }
                    }

                    self.commit_fixed += page_count;
                }
                else
                {
                    const remaining_commit = self.get_remaining_commit();
                    const sub_value: u64 = blk:
                    {
                        if (Kernel.Arch.thread_get_current()) |current_thread|
                        {
                            if (current_thread.is_page_generator)
                                break :blk 0
                            else break :blk critical_available_page_count_threshold;
                        } else break :blk 0;
                    };

                    if (page_count > remaining_commit - sub_value)
                    {
                        // fail
                        return CommitError.PageableCommitError;
                    }

                    self.commit_pageable += page_count;
                }

                // @TODO: object cache?
            }
            else
            {
                // we dont track commits yet!
            }

            // @TODO: log
        }

        pub fn get_available_page_count(self: *Allocator) u64
        {
            return self.zeroed_page_count + self.free_page_count + self.standby_page_count;
        }

        pub fn get_remaining_commit(self: *Allocator) u64
        {
            return self.commit_limit - self.commit_pageable - self.commit_fixed;
        }

        pub fn insert_free_pages_next(self: *Allocator, page: u64) void
        {
            const frame = &self.page_frames[page];
            frame.state = .free;

            {
                frame.value.list.next = self.first_free_page;
                frame.value.list.previous = &self.first_free_page;
                if (self.first_free_page != 0)
                {
                    self.page_frames[self.first_free_page].value.list.previous = &frame.value.list.next;
                }
                self.first_free_page = page;
            }

            self.free_or_zeroed_page_bitset.put(page);
            self.free_page_count += 1;
        }


        fn activate_pages(self: *Allocator, pages: u64, count: u64, flags: u32) void
        {
            _ = flags;

            // @Spinlock
            //

            for (self.page_frames[pages..pages + count]) |*frame, frame_i|
            {
                switch (frame.state)
                {
                    .free => self.free_page_count -= 1,
                    .zeroed => self.zeroed_page_count -= 1,
                    .standby =>
                    {
                        self.standby_page_count -= 1;

                        if (self.last_standby_page == pages + frame_i)
                        {
                            if (frame.value.list.previous == &self.first_standby_page)
                            {
                                self.last_standby_page = 0;
                            }
                            else
                            {
                                self.last_standby_page = (@ptrToInt(frame.value.list.previous) - @ptrToInt(self.page_frames.ptr)) / @sizeOf(PageFrame);
                            }
                        }
                    },
                    else => Kernel.Arch.CPU_stop(),
                }

                frame.value.list.previous.* = frame.value.list.next;
                if (frame.value.list.next != 0) self.page_frames[frame.value.list.next].value.list.previous = frame.value.list.previous;

                std.mem.set(u8, std.mem.asBytes(frame), 0);
                frame.state = .active;
            }

            self.active_page_count += 1;

            // @TODO: update avaialable page count
        }
    };

    fn insert_free_pages_start() void
    {
    }

    fn insert_free_pages_end() void
    {
        if (Kernel.physical_memory_allocator.free_page_count > zero_page_threshold)
        {
            // ...
        }

        // ...
    }

};

pub const PageFault = struct
{
    pub const Flags = enum(u8)
    {
        write = 0,
        lock_acquired = 1,
        for_supervisor = 2,
    };

    pub const Error = error
    {
        region_not_found,
        read_only_page_fault,
        outside_commit_range,
    };

    pub fn handle(memory_space: *Space, fault_address: u64, fault_flags: u32) PageFault.Error!void
    {
        const address = fault_address & ~@intCast(u64, Kernel.Arch.Page.size - 1);

        // @TODO: @Spinlock
        const lock_acquired = fault_flags & @enumToInt(Flags.lock_acquired) != 0;
        if (!lock_acquired)
        {
            if (Kernel.physical_memory_allocator.get_available_page_count() < critical_available_page_count_threshold)
            {
                if (Kernel.Arch.thread_get_current()) |current_thread|
                {
                    if (!current_thread.is_page_generator)
                    {
                        // wait ???
                        // @Spinlock
                        Kernel.Arch.CPU_stop();
                    }
                }
            }
        }

        const region = blk:
        {
            if (!lock_acquired)
            {
                // @Spinlock
            }
            else
            {
                // @Spinlock
            }

            const found_region = find_region(memory_space, address) orelse
            {
                return Error.region_not_found;
            };

            // @Spinlock
            break :blk found_region;
        };

        // @Spinlock
        //
        const write_access = fault_flags & @enumToInt(Flags.write) != 0;
        if (Kernel.Arch.translate_address(address, write_access) != 0)
        {
            return;
        }

        const copy_on_write = write_access and (region.flags & (1 << @enumToInt(Memory.Region.Flags.copy_on_write)) != 0);
        if (write_access and !copy_on_write and (region.flags & (1 << @enumToInt(Memory.Region.Flags.read_only)) != 0))
        {
            return Error.read_only_page_fault;
        }

        // @TODO: and not read only
        const mark_modified = !copy_on_write;

        const region_offset = address - region.base_address;
        var zero_page = !memory_space.user;
        const need_zero_pages = @as(u32, @boolToInt(zero_page)) << @enumToInt(Physical.Flags.zeroed);

        const flags = 
            @as(u32, @boolToInt(memory_space.user)) << @as(u8, @enumToInt(Kernel.Arch.Page.MapFlags.user)) |
            @as(u32, @boolToInt(region.flags & (1 << @enumToInt(Memory.Region.Flags.not_cacheable)) != 0)) << @enumToInt(Kernel.Arch.Page.MapFlags.not_cacheable) |
            @as(u32, @boolToInt((region.flags & (1 << @enumToInt(Memory.Region.Flags.write_combining))) != 0)) << @enumToInt(Kernel.Arch.Page.MapFlags.write_combining) |
            @as(u32, @boolToInt(!mark_modified and region.flags & (1 << @enumToInt(Memory.Region.Flags.fixed)) == 0 and region.flags & (1 << @enumToInt(Memory.Region.Flags.file)) != 0)) << @enumToInt(Kernel.Arch.Page.MapFlags.read_only);

        if (region.flags & (1 << @enumToInt(Memory.Region.Flags.physical)) != 0)
        {
            Kernel.Arch.Page.map(memory_space, region.data.physical.offset + address - region.base_address, address, flags) catch unreachable;
        }
        else if (region.flags & (1 << @enumToInt(Memory.Region.Flags.shared)) != 0)
        {
            Kernel.Arch.CPU_stop();
        }
        else if (region.flags & (1 << @enumToInt(Memory.Region.Flags.file)) != 0)
        {
            Kernel.Arch.CPU_stop();
        }
        else if (region.flags & (1 << @enumToInt(Memory.Region.Flags.normal)) != 0)
        {
            if (region.flags & (1 << @enumToInt(Memory.Region.Flags.no_commit_tracking)) == 0)
            {
                // @TODO: further check
                 if (!region.data.normal.commit.contains(region_offset >> Kernel.Arch.Page.bit_count))
                 {
                     return Error.outside_commit_range;
                 }
            }

            Kernel.Arch.Page.map(memory_space, Kernel.physical_memory_allocator.allocate_lockfree(need_zero_pages, null, null, null), address, flags) catch unreachable;
            if (zero_page)
            {
                std.mem.set(u8, @intToPtr([*]u8, address)[0..Kernel.Arch.Page.size], 0);
            }
        }
        else if (region.flags & (1 << @enumToInt(Memory.Region.Flags.guard)) != 0)
        {
            Kernel.Arch.CPU_stop();
        }
        else
        {
            Kernel.Arch.CPU_stop();
        }
    }
};

pub fn map_physical(memory_space: *Memory.Space, asked_offset: u64, asked_byte_count: u64, caching: u32) ?u64
{
    const offset2 = asked_offset & (Kernel.Arch.Page.size - 1);
    const offset = asked_offset - offset2;
    const byte_count = asked_byte_count + @as(u64, @boolToInt(offset2 != 0)) * Kernel.Arch.Page.size;
    //@Spinlock
    const region = reserve(memory_space, byte_count, 1 << @enumToInt(Region.Flags.physical) | 1 << @enumToInt(Region.Flags.fixed) | caching, null, null) orelse return null;

    region.data.physical.offset = offset;

    var page_i: u64 = 0;
    while (page_i < region.page_count) : (page_i += 1)
    {
        PageFault.handle(memory_space, region.base_address + page_i * Kernel.Arch.Page.size, 0) catch unreachable;
    }

    return region.base_address + offset2;
}

pub fn free_physical(asked_page: u64, maybe_mutex_already_acquired: ?bool, maybe_page_count: ?u64) void
{
    const mutex_already_acquired = maybe_mutex_already_acquired orelse false;
    _ = mutex_already_acquired;
    const page_count = maybe_page_count orelse 1;

    if (asked_page == 0) Kernel.Arch.CPU_stop();
    // @Spinlock
    //
    if (!Kernel.physical_memory_allocator.page_frame_db_initialized) Kernel.Arch.CPU_stop();
    const page = asked_page >> Kernel.Arch.Page.bit_count;

    Physical.insert_free_pages_start();

    for (Kernel.physical_memory_allocator.page_frames[page..page_count + page]) |*frame|
    {
        if (frame.state == .free) Kernel.Arch.CPU_stop();

        if (Kernel.physical_memory_allocator.commit_fixed_limit != 0) Kernel.physical_memory_allocator.active_page_count -= 1;

        Kernel.physical_memory_allocator.insert_free_pages_next(page);
    }

    Physical.insert_free_pages_end();

    // @Spinlock
}

pub fn find_region(memory_space: *Memory.Space, address: u64) ?*Region
{
    // @Spinlock

    if (@ptrToInt(memory_space) == @ptrToInt(&Kernel.core_memory_space))
    {
        for (core_regions[0..core_region_count]) |*core_region|
        {
            if (core_region.more.core.used and core_region.base_address <= address and core_region.base_address + core_region.page_count * Kernel.Arch.Page.size > address)
            {
                return core_region;
            }
        }
    }
    else
    {
        if (memory_space.used_regions.find(address, .largest_below_or_equal)) |item|
        {
            const region = item.value.?;
            if (region.base_address > address) Kernel.Arch.CPU_stop();
            if (region.base_address + region.page_count * Kernel.Arch.Page.size <= address) return null;
            return region;
        }
        else
        {
            return null;
        }
    }

    return null;
}

pub fn reserve(memory_space: *Memory.Space, byte_count: u64, flags: u32, maybe_forced_address: ?u64, maybe_generate_guard_pages: ?bool) ?*Region
{
    const forced_address = maybe_forced_address orelse 0;
    const generate_guard_pages = maybe_generate_guard_pages orelse false;
    _ = generate_guard_pages;

    const needed_page_count = ((byte_count + Kernel.Arch.Page.size - 1) & ~@as(u64, Kernel.Arch.Page.size - 1)) / Kernel.Arch.Page.size;
    if (needed_page_count == 0) return null;

    // @Spinlock
   
    const output_region = blk:
    {
        if (@ptrToInt(memory_space) == @ptrToInt(&Kernel.core_memory_space))
        {
            if (core_region_count == Kernel.Arch.Memory.core_region_count)
            {
                return null;
            }

            if (forced_address != 0)
            {
                Kernel.Arch.CPU_stop();
            }

            {
                const new_region_count = core_region_count + 1;
                const needed_page_to_commit_count = new_region_count * @sizeOf(Memory.Region) / Kernel.Arch.Page.size + 1;

                while (core_region_array_commit < needed_page_to_commit_count)
                    : (core_region_array_commit += 1)
                {
                    Kernel.physical_memory_allocator.commit_lockfree(Kernel.Arch.Page.size, true) catch
                    {
                        return null;
                    };
                }
            }

            for (core_regions[0..core_region_count]) |*core_region|
            {
                if (!core_region.more.core.used and core_region.page_count >= needed_page_count)
                {
                    if (core_region.page_count > needed_page_count)
                    {

                        var splitted_region  = &core_regions[core_region_count];
                        core_region_count += 1;
                        splitted_region.* = core_region.*;
                        splitted_region.base_address += needed_page_count * Kernel.Arch.Page.size;
                        splitted_region.page_count -= needed_page_count;
                    }

                    core_region.more.core.used = true;
                    core_region.page_count = needed_page_count;
                    core_region.flags = flags;
                    core_region.data = Region.Data.zero_init();

                    break :blk core_region;
                }
            }

            return null;
        }
        else if (forced_address != 0)
        {
            Kernel.Arch.CPU_stop();
        }
        else
        {
            // @Guard
            // @TODO: implement guard pages
            const guard_pages_needed = 0;
            const total_needed_page_count = needed_page_count + guard_pages_needed;

            if (memory_space.free_regions_size.find(total_needed_page_count, .smallest_above_or_equal)) |item|
            {
                const region = item.value.?;
                memory_space.free_regions_base.remove(&region.more.non_core.item_base);
                memory_space.free_regions_size.remove(&region.more.non_core.item.size);

                if (region.page_count > total_needed_page_count)
                {
                    const split = @intToPtr(*Region, Kernel.core_heap.allocate(@sizeOf(Region), true) catch unreachable);
                    split.* = region.*;
                    split.base_address += total_needed_page_count * Kernel.Arch.Page.size;
                    split.page_count -= total_needed_page_count;

                    memory_space.free_regions_base.insert(&split.more.non_core.item_base, split, split.base_address, .panic) catch unreachable;
                    memory_space.free_regions_size.insert(&split.more.non_core.item.size, split, split.page_count, .allow) catch unreachable;
                }

                region.data = Region.Data.zero_init();

                region.page_count = needed_page_count;
                region.flags = flags;

                if (guard_pages_needed > 0)
                {
                }

                memory_space.used_regions.insert(&region.more.non_core.item_base, region, region.base_address, .panic) catch unreachable;

                break :blk region;
            }

            Kernel.Arch.CPU_stop();
        }
    };

    Kernel.Arch.commit_page_tables(memory_space, output_region) catch
    {
        unreserve(memory_space, output_region, false, null);
        return null;
    };

    if (memory_space != &Kernel.core_memory_space)
    {
        //@Guard
        //EsMemoryZero(&outputRegion->itemNonGuard, sizeof(outputRegion->itemNonGuard));
        //outputRegion->itemNonGuard.thisItem = outputRegion;
        //space->usedRegionsNonGuard.InsertEnd(&outputRegion->itemNonGuard); 

        //Kernel.Arch.CPU_stop();
    }

    return output_region;
}

fn unreserve(memory_space: *Memory.Space, region_to_remove: *Memory.Region, unmap_pages: bool, maybe_guard_region: ?bool) void
{
    _ = memory_space;
    const guard_region = maybe_guard_region orelse false;

    // @Spinlock

    if (Kernel.physical_memory_allocator.next_region_to_balance) |next_region_to_balance|
    {
        if (@ptrToInt(next_region_to_balance) == @ptrToInt(region_to_remove))
        {
            Kernel.Arch.CPU_stop();
        }
    }

    if (region_to_remove.flags & (1 << @enumToInt(Region.Flags.normal)) != 0)
    {
        if (region_to_remove.data.normal.guard_before) |guard_before| unreserve(memory_space, guard_before, false, true);
        if (region_to_remove.data.normal.guard_after) |guard_after| unreserve(memory_space, guard_after, false, true);
    }
    else if (region_to_remove.flags & (1 << @enumToInt(Region.Flags.guard)) != 0 and !guard_region)
    {
        Kernel.Arch.CPU_stop();
    }

    // @TODO: guard
    //

    if (unmap_pages)
    {
        Kernel.Arch.Page.unmap(memory_space, region_to_remove.base_address, region_to_remove.page_count, 0, null, null);
    }

    memory_space.reserve += region_to_remove.page_count;

    if (memory_space == &Kernel.core_memory_space)
    {
        region_to_remove.more.core.used = false;

        var remove1: u64 = std.math.maxInt(u64);
        var remove2: u64 = std.math.maxInt(u64);

        for (core_regions[0..core_region_count]) |*region, region_i|
        {
            // @TODO: Remove2 != 1 might be a bug
            if (!(remove1 != std.math.maxInt(u64) or remove2 != 1)) break;

            if (region.more.core.used) continue;
            if (region == region_to_remove) continue;

            if (region.base_address == region_to_remove.base_address + (region_to_remove.page_count << Kernel.Arch.Page.bit_count))
            {
                region_to_remove.page_count += region.page_count;
                remove1 = region_i;
            }
            else if (region_to_remove.base_address == region.base_address + (region.page_count << Kernel.Arch.Page.bit_count))
            {
                region_to_remove.page_count += region.page_count;
                region_to_remove.base_address = region.base_address;
                remove2 = region_i;
            }
        }

        if (remove1 != std.math.maxInt(u64))
        {
            core_region_count -= 1;
            core_regions[remove1] = core_regions[core_region_count];
            if (remove2 == core_region_count) remove2 = remove1;
        }

        if (remove2 != std.math.maxInt(u64))
        {
            core_region_count -= 1;
            core_regions[remove2] = core_regions[core_region_count];
        }
    }
    else
    {
        memory_space.used_regions.remove(&region_to_remove.more.non_core.item_base);

        const address = region_to_remove.base_address;

        if (memory_space.free_regions_base.find(address, .largest_below_or_equal)) |before|
        {
            const before_region = before.value.?;
            if (before_region.base_address + before_region.page_count * Kernel.Arch.Page.size == region_to_remove.base_address)
            {
                region_to_remove.base_address = before_region.base_address;
                region_to_remove.page_count = before_region.page_count;
                memory_space.free_regions_base.remove(before);
                memory_space.free_regions_size.remove(&before_region.more.non_core.item.size);
                Kernel.core_heap.free(@ptrToInt(before_region), @sizeOf(Region));
            }
        }
        if (memory_space.free_regions_base.find(address, .smallest_above_or_equal)) |after|
        {
            const after_region = after.value.?;
            if (region_to_remove.base_address + region_to_remove.page_count * Kernel.Arch.Page.size == after_region.base_address)
            {
                region_to_remove.page_count += after_region.page_count;
                memory_space.free_regions_base.remove(after);
                memory_space.free_regions_size.remove(&after_region.more.non_core.item.size);
                Kernel.core_heap.free(@ptrToInt(after_region), @sizeOf(Region)); 
            }
        }

        memory_space.free_regions_base.insert(&region_to_remove.more.non_core.item_base, region_to_remove, region_to_remove.base_address, .panic) catch unreachable;
        memory_space.free_regions_size.insert(&region_to_remove.more.non_core.item.size, region_to_remove, region_to_remove.page_count, .allow) catch unreachable;
    }
}

const HeapRegion = extern struct
{
    union1: extern union
    {
        next: u16,
        size: u16,
    },

    previous: u16,
    offset: u16,
    used: u16,

    union2: extern union
    {
        allocation_size: u64,
        region_list_next: ?*HeapRegion,
    },

    region_list: ?*?*HeapRegion,

    const used_header_size = @sizeOf(HeapRegion) - @sizeOf([*]*HeapRegion);
    const free_header_size = @sizeOf(HeapRegion);

    const used_magic = 0xabcd;

    fn next(self: *HeapRegion) *HeapRegion
    {
        return @intToPtr(*HeapRegion, @ptrToInt(self) + self.union1.next);
    }

    fn data(self: *HeapRegion) u64
    {
        return @ptrToInt(self) + used_header_size;
    }

    fn header(address: u64) *HeapRegion
    {
        return @intToPtr(*HeapRegion, address - used_header_size);
    }

    fn get_previous(self: *HeapRegion) ?*HeapRegion
    {
        if (self.previous != 0)
        {
            const previous_region = @intToPtr(*HeapRegion, @ptrToInt(self) - self.previous);
            return previous_region;
        }
        else return null;
    }
};

pub const Heap = struct
{
    const Self = @This();

    regions: [12]?*HeapRegion,
    allocation_count: u64,
    size: u64,
    blocks: [16]*HeapRegion, // these are pointers
    block_count: u64,

    const large_allocation_threshold = 0x8000;

    const AllocateError = error
    {
        size_is_zero,
        region_allocation_failed
    };

    pub fn allocate(self: *Self, asked_size: u64, zero_memory: bool) AllocateError!u64
    {
        if (asked_size == 0) return AllocateError.size_is_zero;

        var size = asked_size;
        size += HeapRegion.used_header_size;

        size = (size + 0x1f) & ~@as(u64, 0x1f);

        if (size > large_allocation_threshold)
        {
            Kernel.Arch.CPU_stop();
        }

        // @Spinlock

        self.validate();

        var region = blk:
        {
            var i = calculate_index(size);
            while (i < 12) : (i += 1)
            {
                if (self.regions[i] == null) continue;
                const heap_region = self.regions[i].?;
                if (heap_region.union1.size < size) continue;

                remove_free_region(heap_region);
                break :blk heap_region;
            }

            const allocation_result = standard_allocate(&Kernel.core_memory_space, 0x10000, 1 << @enumToInt(Region.Flags.fixed), null, null) catch
            {
                // @Spinlock
                return AllocateError.region_allocation_failed;
            };
            var result = @intToPtr(*HeapRegion, @ptrToInt(allocation_result.ptr));
            if (self.block_count < 16) self.blocks[self.block_count] = result
            else Kernel.Arch.CPU_stop();
            self.block_count += 1;

            result.union1.size = 0x10000 - 0x20;

            // prevent heapfree to trying to merge off the end of the block
            const end_region = result.next();
            end_region.used = HeapRegion.used_magic;
            end_region.offset = 0x10000 - 0x20;
            end_region.union1.next = 0x20;
            @intToPtr(**Heap, end_region.data()).* = self;

            break :blk result;
        };

        if (region.used != 0 or region.union1.size < size)
        {
            Kernel.Arch.CPU_stop();
        }

        self.allocation_count += 1;

        // @TODO: think of a better atomic order
        self.increase_size(size);

        if (region.union1.size == size)
        {
            Kernel.Arch.CPU_stop();
        }

        // split the region into 2 parts

        const allocated_region = region;
        const old_size = allocated_region.union1.size;
        allocated_region.union1.size = @intCast(u16, size);
        allocated_region.used = HeapRegion.used_magic;

        const free_region = allocated_region.next();
        free_region.union1.size = @intCast(u16, old_size - size);
        free_region.previous = @intCast(u16, size);
        free_region.offset = allocated_region.offset + @intCast(u16, size);
        free_region.used = 0;

        self.add_free_region(free_region);

        const next_region = free_region.next();
        next_region.previous = free_region.union1.size;

        self.validate();

        region.union2.allocation_size = asked_size;

        // @Spinlock

        const address = region.data();
        const slice = @intToPtr([*]u8, address)[0..asked_size];
        if (zero_memory) std.mem.set(u8, slice, 0)
        else Kernel.Arch.CPU_stop();

        // memory leak detector
        return address;
    }

    pub fn free(self: *Self, address: u64, maybe_expected_size: ?u64) void
    {
        _ = self;
        const expected_size = maybe_expected_size orelse 0;
        if (address == 0)
        {
            if (expected_size != 0) Kernel.Arch.CPU_stop();
            return;
        }

        // memory leak detector remove
        
     
        var region = HeapRegion.header(address);
        if (region.used != HeapRegion.used_magic) Kernel.Arch.CPU_stop();
        if (expected_size != 0 and region.union2.allocation_size != expected_size) Kernel.Arch.CPU_stop();

        if (region.union1.size == 0)
        {
            // the region was allocated by itself
            // figure out better atomic model
            self.decrease_size(region.union2.allocation_size);
            // this can be buggy
            Kernel.Memory.free(&Kernel.kernel_memory_space, @ptrToInt(region), null, null) catch unreachable;
            return;
        }

        // @TODO: debug build

        const heap_address = @intToPtr(**Heap, @intToPtr(*HeapRegion, @ptrToInt(region) - region.offset + 0x10000 - 0x20).data()).*;
        if (heap_address != self)
        {
            Kernel.Arch.CPU_stop();
        }

        // @Spinlock
        self.validate();

        region.used = 0;

        if (region.offset < region.previous) Kernel.Arch.CPU_stop();

        self.allocation_count -= 1;
        self.decrease_size(region.union2.allocation_size);

        // Attempt to merge with the next region
        const next_region = region.next();
        if (next_region.used == 0)
        {
            remove_free_region(next_region);

            region.union1.size += next_region.union1.size;
            next_region.next().previous = region.union1.size;
        }

        // Attempt to merge with the previous region
        if (region.get_previous()) |previous_region|
        {
            if (previous_region.used == 0)
            {
                remove_free_region(previous_region);
                previous_region.union1.size += region.union1.size;
                region.next().previous = previous_region.union1.size;
                region = previous_region;
            }
        }

        if (region.union1.size == 0x10000 - 0x20)
        {
            if (region.offset != 0) Kernel.Arch.CPU_stop();
            self.block_count -= 1;

            // @TODO: validation

            // @TODO: @WARNING: this is broken for userspace
            Kernel.Memory.free(&Kernel.kernel_memory_space, @ptrToInt(region), null, null) catch unreachable;
            // @Spinlock
        }
        else
        {
            self.add_free_region(region);
            self.validate();
            // @Spinlock
        }
    }

    fn increase_size(self: *Heap, size: u64) callconv(.Inline) void
    {
        _ = @atomicRmw(@TypeOf(self.size), &self.size, .Add, size, .SeqCst);
    }

    fn decrease_size(self: *Heap, size: u64) callconv(.Inline) void
    {
        _ = @atomicRmw(@TypeOf(self.size), &self.size, .Sub, size, .SeqCst);
    }

    fn add_free_region(self: *Self, region: *HeapRegion) void
    {
        if (region.used != 0 or region.union1.size < 0x20) Kernel.Arch.CPU_stop();

        const index = calculate_index(region.union1.size);
        const heap_region = self.regions[index];
        region.union2.region_list_next = heap_region;
        if (region.union2.region_list_next) |region_list_next|
        {
            region_list_next.region_list = &region.union2.region_list_next;
        }
        self.regions[index] = region;
        region.region_list = &self.regions[index];
    }

    fn remove_free_region(region: *HeapRegion) void
    {
        if (region.region_list == null or region.used != 0)
        {
            Kernel.Arch.CPU_stop();
        }

        region.region_list.?.* = region.union2.region_list_next;

        if (region.union2.region_list_next) |region_list_next|
            region_list_next.region_list = region.region_list;

        region.region_list = null;
    }

    fn calculate_index(size: u64) u64
    {
        const clz = @clz(@TypeOf(size), size);
        const msb = @sizeOf(@TypeOf(size)) * 8 - clz - 1;
        const result = msb - 4;
        return result;
    }

    fn validate(self: *Self) void
    {
        _ = self;
        //if (self.cannot_validate) return;

        //for (blocks) |*block|
        //{
            //var region = block;
            //var end = @intToPtr(*HeapRegion, @ptrToInt(block) + 0x10000);

            //while (@ptrToInt(region) < @ptrToInt(end))
            //{

            //}
        //}
    }
};

const StandardAllocateError = error
{
    reserve_failed,
    commit_range,
};

fn standard_allocate(memory_space: *Memory.Space, byte_count: u64, flags: u32, maybe_base_address: ?u64, maybe_commit_all: ?bool) ![]u8
{
    const base_address = maybe_base_address orelse 0;
    const commit_all = maybe_commit_all orelse true;
    //@Spinlock

    var region = Memory.reserve(memory_space, byte_count, flags | 1 << @enumToInt(Region.Flags.normal), base_address, true) orelse return StandardAllocateError.reserve_failed;

    if (commit_all)
    {
        Kernel.physical_memory_allocator.commit_range(memory_space, region, 0, region.page_count) catch
        {
            unreserve(memory_space, region, false, null);
            return StandardAllocateError.commit_range;
        };
    }

    return @intToPtr([*]u8, region.base_address)[0..region.page_count * Kernel.Arch.Page.size];
}

fn pm_zero(asked_pages: [*]u64, asked_page_count: u64, contiguous: bool) void
{
    // @Spinlock

    var page_count = asked_page_count;
    var pages = asked_pages;

    while (true)
    {
        const do_count = if (page_count > Physical.manipulation_region_page_count) Physical.manipulation_region_page_count else page_count;
        page_count -= do_count;

        var address_space = &Kernel.core_memory_space;
        const region = Kernel.physical_memory_allocator.manipulation_region;

        var it: u64 = 0;
        while (it < do_count) : (it += 1)
        {
            Kernel.Arch.Page.map(address_space, if (contiguous) pages[0] + (it << Kernel.Arch.Page.bit_count) else pages[it], region + Kernel.Arch.Page.size * it, 1 << @enumToInt(Kernel.Arch.Page.MapFlags.overwrite) | 1 << @enumToInt(Kernel.Arch.Page.MapFlags.no_new_tables)) catch unreachable;
        }

        // @Spinlock

        it = 0;
        while (it < do_count) : (it += 1)
        {
            const page = region + it * Kernel.Arch.Page.size;
            Kernel.Arch.invalidate_page(page);
        }

        std.mem.set(u8, @intToPtr([*]u8, region)[0..do_count * Kernel.Arch.Page.size], 0);
        // @Spinlock

        if (page_count != 0)
        {
            if (!contiguous) pages = @intToPtr([*]u64, @ptrToInt(pages) + (Physical.manipulation_region_page_count * @sizeOf(u64)));
        }
        else
        {
            break;
        }
    }

    // @Spinlock
}

const FreeError = error
{
    region_not_found,
    attempt_to_free_non_user_region,
    incorrect_base_address,
    incorrect_free_size,
};

pub fn free(memory_space: *Memory.Space, address: u64, maybe_expected_size: ?u64, maybe_user_only: ?bool) FreeError!void
{
    const expected_size = maybe_expected_size orelse 0;
    const user_only = maybe_user_only orelse false;
    // @Spinlock

    const region = find_region(memory_space, address) orelse return FreeError.region_not_found;

    if (user_only and (~region.flags & (1 << @enumToInt(Region.Flags.user)) != 0))
    {
        return FreeError.attempt_to_free_non_user_region;
    }

    // @Spinlock check
    
    var unmap_pages = true;

    if (region.base_address != address and (~region.flags & (1 << @enumToInt(Region.Flags.physical)) != 0))
    {
        return FreeError.incorrect_base_address;
    }

    if (expected_size > 0 and (expected_size + Kernel.Arch.Page.size - 1) / Kernel.Arch.Page.size != region.page_count)
    {
        return FreeError.incorrect_free_size;
    }

    if (region.flags & (1 << @enumToInt(Region.Flags.normal)) != 0)
    {
        Kernel.Arch.CPU_stop();
    }
    else if (region.flags & (1 << @enumToInt(Region.Flags.normal)) != 0)
    {
        Kernel.Arch.CPU_stop();
    }
    else if (region.flags & (1 << @enumToInt(Region.Flags.file)) != 0)
    {
        Kernel.Arch.CPU_stop();
    }
    else if (region.flags & (1 << @enumToInt(Region.Flags.guard)) != 0)
    {
        Kernel.Arch.CPU_stop();
    }
    else if (region.flags & (1 << @enumToInt(Region.Flags.physical)) != 0)
    { 
        // do nothing
    }
    else
    {
        Kernel.Arch.CPU_stop();
    }

    unreserve(memory_space, region, unmap_pages, null);

    // @TODO: sharedregiontofree
    // @TODO: nodetofree and filehandleflags
}
