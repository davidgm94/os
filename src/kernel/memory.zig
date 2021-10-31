const std = @import("std");
const Kernel = @import("kernel.zig");
const Array = @import("array.zig").Array;
const AVLTree = @import("avl_tree.zig").Short;

const Memory = @This();

pub fn init() void
{
    core_regions[0].more.core.used = false;
    core_region_count = 1;
    Kernel.Arch.Memory.init();

    const region = @intToPtr(*Region, Kernel.core_heap.allocate(@sizeOf(Region), true) catch unreachable);
    region.base_address = Kernel.Arch.Memory.kernel_space_start;
    region.page_count = Kernel.Arch.Memory.kernel_space_size / Kernel.Arch.Page.size;

    Kernel.kernel_memory_space.free_regions_base.insert(&region.more.non_core.item_base, region, region.base_address, .panic) catch unreachable;
    Kernel.kernel_memory_space.free_regions_size.insert(&region.more.non_core.item.size, region, region.page_count, .allow) catch unreachable;
    Kernel.Arch.CPU_stop();
}

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

pub extern var physical_memory_regions: PhysicalRegions;

pub const PhysicalRegions = extern struct
{
    ptr: [*]PhysicalRegion,
    count: u64,
    page_count: u64,
    original_page_count: u64,
    index: u64,
    highest: u64,
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

        const Self = @This();
    };
};

pub const PhysicalRegion = struct
{
    base_address: u64,
    page_count: u64,
};

pub const Physical = struct
{
    pub const Page = struct
    {
        state: State,
        flags: u8,
        cache_reference: u64,

        const State = enum(u8)
        {
            unusable,
            bad,
            zeroed,
            free,
            standby,
            active,
        };
    };

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
        commit_fixed: u64,
        commit_pageable: u64,
        commit_fixed_limit: u64,
        commit_limit: u64,

        zeroed_page_count: u64,
        free_page_count: u64,
        standby_page_count: u64,

        next_region_to_balance: ?*Region,

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
                Kernel.Arch.CPU_stop();
            }

            Kernel.Arch.CPU_stop();
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

            _ = memory_space;

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
                    if (page_count > self.commit_fixed_limit - self.commit_limit)
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
    };
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

        _ = flags;
        _ = zero_page;
        _ = region_offset;

        if (region.flags & (1 << @enumToInt(Memory.Region.Flags.physical)) != 0)
        {
            Kernel.Arch.CPU_stop();
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
                // if (region.data.normal.commit.contains(
            }

            Kernel.Arch.Page.map(memory_space, Kernel.physical_memory_allocator.allocate_lockfree(need_zero_pages, null, null, null), address, Kernel.Arch.Page.size) catch unreachable;
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

        return;
    }
};

pub fn find_region(memory_space: *Memory.Space, address: u64) ?*Region
{
    _ = address;
    // @Spinlock
    //

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
        Kernel.Arch.CPU_stop();
    }

    return null;
}

pub fn reserve(memory_space: *Memory.Space, byte_count: u64, flags: u32, maybe_forced_address: ?u64, maybe_generate_guard_pages: ?bool) ?*Region
{
    const forced_address = maybe_forced_address orelse 0;
    const generate_guard_pages = maybe_generate_guard_pages orelse false;
    _ = generate_guard_pages;
    _ = flags;

    const needed_page_count = ((byte_count + Kernel.Arch.Page.size - 1) & ~@as(u64, Kernel.Arch.Page.size - 1)) / Kernel.Arch.Page.size;
    if (needed_page_count == 0) return null;

    // @Spinlock
   
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

                return core_region;
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
        Kernel.Arch.CPU_stop();
    }
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
        Kernel.Arch.CPU_stop();
    }
    else if (region_to_remove.flags & (1 << @enumToInt(Region.Flags.guard)) != 0 and !guard_region)
    {
        Kernel.Arch.CPU_stop();
    }

    // @TODO: guard
    //

    if (unmap_pages)
    {
        Kernel.Arch.CPU_stop();
        //Kernel.Arch.unmap_pages();
    }

    Kernel.Arch.CPU_stop();
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

    region_list: **HeapRegion,

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
        _ = zero_memory;
        _ = self;

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

                if (true) Kernel.Arch.CPU_stop();
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
        _ = @atomicRmw(@TypeOf(self.size), &self.size, .Add, size, .SeqCst);

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

    fn add_free_region(self: *Self, region: *HeapRegion) void
    {
        if (region.used != 0 or region.union1.size < 0x20) Kernel.Arch.CPU_stop();

        const index = calculate_index(region.union1.size);
        const heap_region = self.regions[index];
        region.union2.region_list_next = heap_region;
        if (region.union2.region_list_next) |region_list_next|
        {
            region_list_next.region_list = &region.union2.region_list_next.?;
        }
        self.regions[index] = region;
        region.region_list = &self.regions[index].?;
    }

    fn remove_free_region(self: *Self, region: *Region) void
    {
        _ = self; _ = region;
        Kernel.Arch.CPU_stop();
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
