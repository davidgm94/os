const kernel = @import("kernel.zig");

const LinkedList = kernel.LinkedList;
const SimpleList = kernel.SimpleList;
const AVLTree = kernel.AVLTree;
const Bitset = kernel.Bitset;
const Range = kernel.Range;
const Volatile = kernel.Volatile;
const Bitflag = kernel.Bitflag;
const EsMemoryZero = kernel.EsMemoryZero;
const EsMemoryCopy = kernel.EsMemoryCopy;
const TODO = kernel.TODO;
const zeroes = kernel.zeroes;

const arch = kernel.arch;
const page_size = arch.page_size;
const page_bit_count = arch.page_bit_count;

const object = kernel.object;

const AsyncTask = kernel.scheduling.AsyncTask;
const Thread = kernel.scheduling.Thread;
const Process = kernel.scheduling.Process;

const Spinlock = kernel.sync.Spinlock;
const Mutex = kernel.sync.Mutex;
const WriterLock = kernel.sync.WriterLock;
const Event = kernel.sync.Event;


const std = @import("std");
const assert = std.debug.assert;

export fn EsHeapAllocate(size: u64, zero_memory: bool, heap: *Heap) callconv(.C) u64
{
    return heap.allocate(size, zero_memory);
}

export fn EsHeapFree(address: u64, expected_size: u64, heap: *Heap) callconv(.C) void
{
    heap.free(address, expected_size);
}


// @TODO: investigate why we should cast to u32
export fn HeapCalculateIndex(size: u64) callconv(.C) u64
{
    assert(size != 0 or size != std.math.maxInt(u32));
    const clz = @clz(u32, @intCast(u32, size));
    const msb = @sizeOf(u32) * 8 - clz - 1;
    return msb - 4;
}

pub const Heap = extern struct
{
    mutex: Mutex,
    regions: [12]?*HeapRegion,
    allocation_count: Volatile(u64),
    size: Volatile(u64),
    block_count: Volatile(u64),
    blocks: [16]?*HeapRegion,
    cannot_validate: bool,

    pub fn allocate(self: *@This(), asked_size: u64, zero_memory: bool) u64
    {
        if (@bitCast(i64, asked_size) < 0) kernel.panicf("heap panic", .{});

        const size = (asked_size + HeapRegion.used_header_size + 0x1f) & ~@as(u64, 0x1f);

        if (size >= large_allocation_threshold)
        {
            if (@intToPtr(?*HeapRegion, self.allocate_call(size))) |region|
            {
                region.used = HeapRegion.used_magic;
                region.u1.size = 0;
                region.u2.allocation_size = asked_size;
                _ = self.size.atomic_fetch_add(asked_size);
                return region.get_data();
            }
            else
            {
                return 0;
            }
        }

        _ = self.mutex.acquire();

        self.validate();

        const region = blk:
        {
            var heap_index = HeapCalculateIndex(size);
            if (heap_index < self.regions.len)
            {
                for (self.regions[heap_index..]) |maybe_heap_region|
                {
                    if (maybe_heap_region) |heap_region|
                    {
                        if (heap_region.u1.size >= size)
                        {
                            const result = heap_region;
                            result.remove_free();
                            break :blk result;
                        }
                    }
                }
            }

            const allocation = @intToPtr(?*HeapRegion, self.allocate_call(65536));
            if (self.block_count.read_volatile() < 16)
            {
                self.blocks[self.block_count.read_volatile()] = allocation;
            }
            else
            {
                self.cannot_validate = true;
            }
            self.block_count.increment();

            if (allocation) |result|
            {
                result.u1.size = 65536 - 32;
                const end_region = result.get_next().?;
                end_region.used = HeapRegion.used_magic;
                end_region.offset = 65536 - 32;
                end_region.u1.next = 32;
                @intToPtr(?*?*Heap, end_region.get_data()).?.* = self;

                break :blk result;
            }
            else
            {
                // it failed
                self.mutex.release();
                return 0;
            }
        };

        if (region.used != 0 or region.u1.size < size) kernel.panicf("heap panic\n", .{});

        self.allocation_count.increment();
        _ = self.size.atomic_fetch_add(size);

        if (region.u1.size != size)
        {
            const old_size = region.u1.size;
            assert(size <= std.math.maxInt(u16));
            const truncated_size = @intCast(u16, size);
            region.u1.size = truncated_size;
            region.used = HeapRegion.used_magic;

            const free_region = region.get_next().?;
            free_region.u1.size = old_size - truncated_size;
            free_region.previous = truncated_size;
            free_region.offset = region.offset + truncated_size;
            free_region.used = 0;
            self.add_free_region(free_region);

            const next_region = free_region.get_next().?;
            next_region.previous = free_region.u1.size;

            self.validate();
        }

        region.used = HeapRegion.used_magic;
        region.u2.allocation_size = asked_size;
        self.mutex.release();

        const address = region.get_data();
        const memory = @intToPtr([*]u8, address)[0..asked_size];
        if (zero_memory)
        {
            std.mem.set(u8, memory, 0);
        }
        else
        {
            std.mem.set(u8, memory, 0xa1);
        }

        return address;
    }

    fn add_free_region(self: *@This(), region: *HeapRegion) void
    {
        if (region.used != 0 or region.u1.size < 32)
        {
            kernel.panicf("heap panic\n", .{});
        }

        const index = HeapCalculateIndex(region.u1.size);
        assert(index < std.math.maxInt(u32));
        region.u2.region_list_next = self.regions[index];
        if (region.u2.region_list_next) |region_list_next|
        {
            region_list_next.region_list_reference = &region.u2.region_list_next;
        }
        self.regions[index] = region;
        region.region_list_reference = &self.regions[index];
    }

    fn allocate_call(self: *@This(), size: u64) u64
    {
        if (self == &kernel.heapCore)
        {
            return kernel.core_address_space.allocate_standard(size, Region.Flags.from_flag(.fixed), 0, true);
        }
        else
        {
            return kernel.address_space.allocate_standard(size, Region.Flags.from_flag(.fixed), 0, true);
        }
    }

    fn free_call(self: *@This(), region: *HeapRegion) void
    {
        if (self == &kernel.heapCore)
        {
            _ = kernel.core_address_space.free(@ptrToInt(region), 0, false);
        }
        else
        {
            _ = kernel.address_space.free(@ptrToInt(region), 0, false);
        }
    }

    pub fn free(self: *@This(), address: u64, expected_size: u64) void
    {
        if (address == 0 and expected_size != 0) kernel.panicf("heap panic", .{});
        if (address == 0) return;

        var region = @intToPtr(*HeapRegion, address).get_header().?;
        if (region.used != HeapRegion.used_magic) kernel.panicf("heap panic", .{});
        if (expected_size != 0 and region.u2.allocation_size != expected_size) kernel.panicf("heap panic", .{});

        if (region.u1.size == 0)
        {
            _ = self.size.atomic_fetch_sub(region.u2.allocation_size);
            self.free_call(region);
            return;
        }

        {
            const first_region = @intToPtr(*HeapRegion, @ptrToInt(region) - region.offset + 65536 - 32);
            if (@intToPtr(**Heap, first_region.get_data()).* != self) kernel.panicf("heap panic", .{});
        }

        _ = self.mutex.acquire();

        self.validate();

        region.used = 0;

        if (region.offset < region.previous) kernel.panicf("heap panic", .{});

        self.allocation_count.decrement();
        _ = self.size.atomic_fetch_sub(region.u1.size);

        if (region.get_next()) |next_region|
        {
            if (next_region.used == 0)
            {
                next_region.remove_free();
                region.u1.size += next_region.u1.size;
                next_region.get_next().?.previous = region.u1.size;
            }
        }

        if (region.get_previous()) |previous_region|
        {
            if (previous_region.used == 0)
            {
                previous_region.remove_free();

                previous_region.u1.size += region.u1.size;
                region.get_next().?.previous = previous_region.u1.size;
                region = previous_region;
            }
        }

        if (region.u1.size == 65536 - 32)
        {
            if (region.offset != 0) kernel.panicf("heap panic", .{});

            self.block_count.decrement();

            if (!self.cannot_validate)
            {
                var found = false;
                for (self.blocks[0..self.block_count.read_volatile() + 1]) |*heap_region|
                {
                    if (heap_region.* == region)
                    {
                        heap_region.* = self.blocks[self.block_count.read_volatile()];
                        found = true;
                        break;
                    }
                }

                assert(found);
            }

            self.free_call(region);
            self.mutex.release();
            return;
        }

        self.add_free_region(region);
        self.validate();
        self.mutex.release();
    }

    fn validate(self: *@This()) void
    {
        if (self.cannot_validate) return;

        for (self.blocks[0..self.block_count.read_volatile()]) |maybe_start, i|
        {
            if (maybe_start) |start|
            {
                const end = @intToPtr(*HeapRegion, @ptrToInt(self.blocks[i]) + 65536);
                var maybe_previous: ?* HeapRegion = null;
                var region = start;

                while (@ptrToInt(region) < @ptrToInt(end))
                {
                    if (maybe_previous) |previous|
                    {
                        if (@ptrToInt(previous) != @ptrToInt(region.get_previous()))
                        {
                            kernel.panicf("heap panic\n", .{});
                        }
                    }
                    else
                    {
                        if (region.previous != 0) kernel.panicf("heap panic\n", .{});
                    }

                    if (region.u1.size & 31 != 0) kernel.panicf("heap panic", .{});

                    if (@ptrToInt(region) - @ptrToInt(start) != region.offset)
                    {
                        kernel.panicf("heap panic\n", .{});
                    }

                    if (region.used != HeapRegion.used_magic and region.used != 0)
                    {
                        kernel.panicf("heap panic", .{});
                    }

                    if (region.used == 0 and region.region_list_reference == null)
                    {
                        kernel.panicf("heap panic\n", .{});
                    }

                    if (region.used == 0 and region.u2.region_list_next != null and region.u2.region_list_next.?.region_list_reference != &region.u2.region_list_next)
                    {
                        kernel.panicf("heap panic", .{});
                    }

                    maybe_previous = region;
                    region = region.get_next().?;
                }

                if (region != end)
                {
                    kernel.panicf("heap panic", .{});
                }
            }
        }
    }

    const large_allocation_threshold = 32768;
};

pub const HeapRegion = extern struct
{
    u1: extern union
    {
        next: u16,
        size: u16,
    },

    previous: u16,
    offset: u16,
    used: u16,

    u2: extern union
    {
        allocation_size: u64,
        region_list_next: ?*HeapRegion,
    },

    region_list_reference: ?*?*@This(),

    const used_header_size = @sizeOf(HeapRegion) - @sizeOf(?*?*HeapRegion);
    const free_header_size = @sizeOf(HeapRegion);
    const used_magic = 0xabcd;

    fn remove_free(self: *@This()) void
    {
        if (self.region_list_reference == null or self.used != 0) kernel.panicf("heap panic\n", .{});

        self.region_list_reference.?.* = self.u2.region_list_next;

        if (self.u2.region_list_next) |region_list_next|
        {
            region_list_next.region_list_reference = self.region_list_reference;
        }
        self.region_list_reference = null;
    }

    fn get_header(self: *@This()) ?*HeapRegion
    {
        return @intToPtr(?*HeapRegion, @ptrToInt(self) - used_header_size);
    }

    fn get_data(self: *@This()) u64
    {
        return @ptrToInt(self) + used_header_size;
    }

    fn get_next(self: *@This()) ?*HeapRegion
    {
        return @intToPtr(?*HeapRegion, @ptrToInt(self) + self.u1.next);
    }

    fn get_previous(self: *@This()) ?*HeapRegion
    {
        if (self.previous != 0)
        {
            return @intToPtr(?*HeapRegion, @ptrToInt(self) - self.previous);
        }
        else
        {
            return null;
        }
    }
};

pub const AddressSpace = extern struct
{
    arch: arch.AddressSpace,

    free_region_base: AVLTree(Region),
    free_region_size: AVLTree(Region),
    used_regions: AVLTree(Region),
    used_regions_non_guard: LinkedList(Region),

    reserve_mutex: Mutex,

    reference_count: Volatile(i32),
    user: bool,
    commit_count: u64,
    reserve_count: u64,
    remove_async_task: AsyncTask,

    pub fn find_region(self: *AddressSpace, address: u64) ?*Region
    {
        self.reserve_mutex.assert_locked();

        if (self == &kernel.core_address_space)
        {
            for (kernel.mmCoreRegions[0..kernel.mmCoreRegionCount]) |*region|
            {
                const matched = region.u.core.used and region.descriptor.base_address <= address and region.descriptor.base_address + region.descriptor.page_count * page_size > address;
                if (matched)
                {
                    return region;
                }
            }
            return null;
        }
        else
        {
            const item = self.used_regions.find(address, .largest_below_or_equal) orelse return null;
            const region = item.value.?;
            if (region.descriptor.base_address > address) kernel.panicf("broken used regions tree", .{});
            if (region.descriptor.base_address + region.descriptor.page_count * page_size <= address) return null;
            return region;
        }
    }

    pub fn unreserve(space: *AddressSpace, region: *Region, unmap_pages: bool, guard_region: bool) callconv(.C) void
    {
        space.reserve_mutex.assert_locked();

        if (kernel.pmm.next_region_to_balance == region)
        {
            kernel.pmm.next_region_to_balance = if (region.u.item.u.non_guard.next) |next| next.value else null;
            kernel.pmm.balance_resume_position = 0;
        }

        if (region.flags.contains(.normal))
        {
            if (region.data.u.normal.guard_before) |before| space.unreserve(before, false, true);
            if (region.data.u.normal.guard_after) |after| space.unreserve(after, false, true);
        }
        else if (region.flags.contains(.guard) and !guard_region)
        {
            // log error
            return;
        }

        if (region.u.item.u.non_guard.list != null and !guard_region)
        {
            region.u.item.u.non_guard.remove_from_list();
        }

        if (unmap_pages)
        {
            _ = arch.unmap_pages(space, region.descriptor.base_address, region.descriptor.page_count, UnmapPagesFlags.empty(), 0, null);
        }

        space.reserve_count += region.descriptor.page_count;

        if (space == &kernel.core_address_space)
        {
            region.u.core.used = false;

            var remove1: i64 = -1;
            var remove2: i64 = -1;

            for (kernel.mmCoreRegions[0..kernel.mmCoreRegionCount]) |*r, i|
            {
                if (!(remove1 != -1 or remove2 != 1)) break;
                if (r.u.core.used) continue;
                if (r == region) continue;

                if (r.descriptor.base_address == region.descriptor.base_address + (region.descriptor.page_count << page_bit_count))
                {
                    region.descriptor.page_count += r.descriptor.page_count;
                    remove1 = @intCast(i64, i);
                }
                else if (region.descriptor.base_address == r.descriptor.base_address + (r.descriptor.page_count << page_bit_count))
                {
                    region.descriptor.page_count += r.descriptor.page_count;
                    region.descriptor.base_address = r.descriptor.base_address;
                    remove2 = @intCast(i64, i);
                }
            }

            if (remove1 != -1)
            {
                kernel.mmCoreRegionCount -= 1;
                kernel.mmCoreRegions[@intCast(u64, remove1)] = kernel.mmCoreRegions[kernel.mmCoreRegionCount];
                if (remove2 == @intCast(i64, kernel.mmCoreRegionCount)) remove2 = remove1;
            }

            if (remove2 != -1)
            {
                kernel.mmCoreRegionCount -= 1;
                kernel.mmCoreRegions[@intCast(u64, remove2)] = kernel.mmCoreRegions[kernel.mmCoreRegionCount];
            }
        }
        else
        {
            space.used_regions.remove(&region.u.item.base);
            const address = region.descriptor.base_address;

            if (space.free_region_base.find(address, .largest_below_or_equal)) |before|
            {
                if (before.value.?.descriptor.base_address + before.value.?.descriptor.page_count * page_size == region.descriptor.base_address)
                {
                    region.descriptor.base_address = before.value.?.descriptor.base_address;
                    region.descriptor.page_count += before.value.?.descriptor.page_count;
                    space.free_region_base.remove(before);
                    space.free_region_size.remove(&before.value.?.u.item.u.size);
                    EsHeapFree(@ptrToInt(before.value), @sizeOf(Region), &kernel.heapCore);
                }
            }

            if (space.free_region_base.find(address, .smallest_above_or_equal)) |after|
            {
                if (region.descriptor.base_address + region.descriptor.page_count * page_size == after.value.?.descriptor.base_address)
                {
                    region.descriptor.page_count += after.value.?.descriptor.page_count;
                    space.free_region_base.remove(after);
                    space.free_region_size.remove(&after.value.?.u.item.u.size);
                    EsHeapFree(@ptrToInt(after.value), @sizeOf(Region), &kernel.heapCore);
                }
            }

            _ = space.free_region_base.insert(&region.u.item.base, region, region.descriptor.base_address, .panic);
            _ = space.free_region_size.insert(&region.u.item.u.size, region, region.descriptor.page_count, .allow);
        }
    }

    pub fn free(space: *AddressSpace, address: u64, expected_size: u64, user_only: bool) callconv(.C) bool
    {
        {
            _ = space.reserve_mutex.acquire();
            defer space.reserve_mutex.release();

            const region = space.find_region(address) orelse return false;

            if (user_only and !region.flags.contains(.user)) return false;
            if (!region.data.pin.take_extended(WriterLock.exclusive, true)) return false;
            if (region.descriptor.base_address != address and !region.flags.contains(.physical)) return false;
            if (expected_size != 0 and (expected_size + page_size - 1) / page_size != region.descriptor.page_count) return false;

            var unmap_pages = true;

            if (region.flags.contains(.normal))
            {
                if (!space.decommit_range(region, 0, region.descriptor.page_count)) kernel.panicf("Could not decommit the entere region", .{});
                if (region.data.u.normal.commit_page_count != 0) kernel.panicf("After decommiting range covering the entere region, some pages were still commited", .{});
                region.data.u.normal.commit.ranges.free();
                unmap_pages = false;
            }
            else if (region.flags.contains(.shared))
            {
                object.close_handle(region.data.u.shared.region, 0);
            }
            else if (region.flags.contains(.file))
            {
                TODO(@src());
            }
            else if (region.flags.contains(.physical)) { } // do nothing
            else if (region.flags.contains(.guard)) return false
            else kernel.panicf("unsupported region type", .{});
            return true;
        }
    }
    pub fn open_reference(space: *AddressSpace) callconv(.C) void
    {
        if (space != &kernel.address_space)
        {
            if (space.reference_count.read_volatile() < 1) kernel.panicf("space has invalid reference count", .{});
            _ = space.reference_count.atomic_fetch_add(1);
        }
    }

    pub fn destroy(space: *AddressSpace) callconv(.C) void
    {
        var maybe_item = space.used_regions_non_guard.first;
        while (maybe_item) |item|
        {
            const region = item.value.?;
            maybe_item = item.next;
            _ = space.free(region.descriptor.base_address, 0, false);
        }

        while (space.free_region_base.find(0, .smallest_above_or_equal)) |item|
        {
            space.free_region_base.remove(&item.value.?.u.item.base);
            space.free_region_size.remove(&item.value.?.u.item.u.size);
            EsHeapFree(@ptrToInt(item.value), @sizeOf(Region), &kernel.heapCore);
        }

        arch.free_address_space(space);
    }

    pub fn find_and_pin_region(space: *AddressSpace, address: u64, size: u64) callconv(.C) ?*Region
    {
        {
            var overflow_result: u64 = 0;
            if (@addWithOverflow(u64, address, size, &overflow_result))
            {
                return null;
            }
        }

        _ = space.reserve_mutex.acquire();
        defer space.reserve_mutex.release();

        const region = space.find_region(address) orelse return null;

        if (region.descriptor.base_address > address) return null;
        if (region.descriptor.base_address + region.descriptor.page_count * page_size < address + size) return null;
        if (!region.data.pin.take_extended(WriterLock.shared, true)) return null;

        return region;
    }

    pub fn commit_range(space: *AddressSpace, region: *Region, page_offset: u64, page_count: u64) callconv(.C) bool
    {
        space.reserve_mutex.assert_locked();

        if (region.flags.contains(.no_commit_tracking)) kernel.panicf("region does not support commit tracking", .{});
        if (page_offset >= region.descriptor.page_count or page_count > region.descriptor.page_count - page_offset) kernel.panicf("invalid region offset and page count", .{});
        if (!region.flags.contains(.normal)) kernel.panicf("cannot commit into non-normal region", .{});

        var delta: i64 = 0;
        _ = region.data.u.normal.commit.set(page_offset, page_offset + page_count, &delta, false);

        if (delta < 0) kernel.panicf("Invalid delta calculation", .{});
        if (delta == 0) return true;

        const delta_u = @intCast(u64, delta);

        if (!commit(delta_u * page_size, region.flags.contains(.fixed))) return false;
        region.data.u.normal.commit_page_count += delta_u;
        space.commit_count += delta_u;

        if (region.data.u.normal.commit_page_count > region.descriptor.page_count) kernel.panicf("invalid delta calculation increases region commit past page count", .{});

        if (!region.data.u.normal.commit.set(page_offset, page_offset + page_count, null, true))
        {
            decommit(delta_u * page_size, region.flags.contains(.fixed));
            region.data.u.normal.commit_page_count -= delta_u;
            space.commit_count -= delta_u;
            return false;
        }

        if (region.flags.contains(.fixed))
        {
            var i = page_offset;
            while (i < page_offset + page_count) : (i += 1)
            {
                if (!space.handle_page_fault(region.descriptor.base_address + i * page_size, HandlePageFaultFlags.from_flag(.lock_acquired))) kernel.panicf("unable to fix pages", .{});
            }
        }

        return true;
    }

    pub fn reserve(space: *AddressSpace, byte_count: u64, flags: Region.Flags, forced_address: u64) callconv(.C) ?*Region
    {
        const needed_page_count = ((byte_count + page_size - 1) & ~@as(u64, page_size - 1)) / page_size;

        if (needed_page_count == 0) return null;

        space.reserve_mutex.assert_locked();

        const region = blk:
        {
            if (space == &kernel.core_address_space)
            {
                if (kernel.mmCoreRegionCount == arch.core_memory_region_count) return null;

                if (forced_address != 0) kernel.panicf("Using a forced address in core address space\n", .{});

                {
                    const new_region_count = kernel.mmCoreRegionCount + 1;
                    const needed_commit_page_count = new_region_count * @sizeOf(Region) / page_size;

                    while (kernel.mmCoreRegionArrayCommit < needed_commit_page_count) : (kernel.mmCoreRegionArrayCommit += 1)
                    {
                        if (!commit(page_size, true)) return null;
                    }
                }

                for (kernel.mmCoreRegions[0..kernel.mmCoreRegionCount]) |*region|
                {
                    if (!region.u.core.used and region.descriptor.page_count >= needed_page_count)
                    {
                        if (region.descriptor.page_count > needed_page_count)
                        {
                            const last = kernel.mmCoreRegionCount;
                            kernel.mmCoreRegionCount += 1;
                            var split = &kernel.mmCoreRegions[last];
                            split.* = region.*;
                            split.descriptor.base_address += needed_page_count * page_size;
                            split.descriptor.page_count -= needed_page_count;
                        }

                        region.u.core.used = true;
                        region.descriptor.page_count = needed_page_count;
                        region.flags = flags;
                        region.data = zeroes(@TypeOf(region.data));
                        assert(region.data.u.normal.commit.ranges.length() == 0);

                        break :blk region;
                    }
                }

                return null;
            }
            else if (forced_address != 0)
            {
                if (space.used_regions.find(forced_address, .exact)) |_| return null;

                if (space.used_regions.find(forced_address, .smallest_above_or_equal)) |item|
                {
                    if (item.value.?.descriptor.base_address < forced_address + needed_page_count * page_size) return null;
                }

                if (space.used_regions.find(forced_address + needed_page_count * page_size - 1, .largest_below_or_equal)) |item|
                {
                    if (item.value.?.descriptor.base_address + item.value.?.descriptor.page_count * page_size > forced_address) return null;
                }

                if (space.free_region_base.find(forced_address, .exact)) |_| return null;

                if (space.free_region_base.find(forced_address, .smallest_above_or_equal)) |item|
                {
                    if (item.value.?.descriptor.base_address < forced_address + needed_page_count * page_size) return null;
                }

                if (space.free_region_base.find(forced_address + needed_page_count * page_size - 1, .largest_below_or_equal)) |item|
                {
                    if (item.value.?.descriptor.base_address + item.value.?.descriptor.page_count * page_size > forced_address) return null;
                }

                const region = @intToPtr(?*Region, EsHeapAllocate(@sizeOf(Region), true, &kernel.heapCore)) orelse unreachable;
                region.descriptor.base_address = forced_address;
                region.descriptor.page_count = needed_page_count;
                region.flags = flags;

                _ = space.used_regions.insert(&region.u.item.base, region, region.descriptor.base_address, .panic);

                region.data = zeroes(@TypeOf(region.data));
                break :blk region;
            }
            else
            {
                // @TODO: implement guard pages?

                if (space.free_region_size.find(needed_page_count, .smallest_above_or_equal)) |item|
                {
                    const region = item.value.?;
                    space.free_region_base.remove(&region.u.item.base);
                    space.free_region_size.remove(&region.u.item.u.size);

                    if (region.descriptor.page_count > needed_page_count)
                    {
                        const split = @intToPtr(?*Region, EsHeapAllocate(@sizeOf(Region), true, &kernel.heapCore)) orelse unreachable;
                        split.* = region.*;

                        split.descriptor.base_address += needed_page_count * page_size;
                        split.descriptor.page_count -= needed_page_count;

                        _ = space.free_region_base.insert(&split.u.item.base, split, split.descriptor.base_address, .panic);
                        _ = space.free_region_size.insert(&split.u.item.u.size, split, split.descriptor.page_count, .allow);
                    }

                    region.data = zeroes(@TypeOf(region.data));
                    region.descriptor.page_count = needed_page_count;
                    region.flags = flags;

                    // @TODO: if guard pages needed
                    _ = space.used_regions.insert(&region.u.item.base, region, region.descriptor.base_address, .panic);
                    break :blk region;
                }
                else
                {
                    return null;
                }
            }
        };

        if (!arch.commit_page_tables(space, region))
        {
            space.unreserve(region, false, false);
            return null;
        }

        if (space != &kernel.core_address_space)
        {
            region.u.item.u.non_guard = zeroes(@TypeOf(region.u.item.u.non_guard));
            region.u.item.u.non_guard.value = region;
            space.used_regions_non_guard.insert_at_end(&region.u.item.u.non_guard);
        }

        space.reserve_count += needed_page_count;

        return region;
    }

    pub fn allocate_standard(space: *AddressSpace, byte_count: u64, flags: Region.Flags, base_address: u64, commit_all: bool) callconv(.C) u64
    {
        _ = space.reserve_mutex.acquire();
        defer space.reserve_mutex.release();

        const region = space.reserve(byte_count, flags.or_flag(.normal), base_address) orelse return 0;

        if (commit_all)
        {
            if (!space.commit_range(region, 0, region.descriptor.page_count))
            {
                space.unreserve(region, false, false);
                return 0;
            }
        }

        return region.descriptor.base_address;
    }

    pub fn decommit_range(space: *AddressSpace, region: *Region, page_offset: u64, page_count: u64) callconv(.C) bool
    {
        space.reserve_mutex.assert_locked();

        if (region.flags.contains(.no_commit_tracking)) kernel.panicf("Region does not support commit tracking", .{});
        if (page_offset >= region.descriptor.page_count or page_count > region.descriptor.page_count - page_offset) kernel.panicf("invalid region offset and page count", .{});
        if (!region.flags.contains(.normal)) kernel.panicf("Cannot decommit from non-normal region", .{});

        var delta: i64 = 0;

        if (!region.data.u.normal.commit.clear(page_offset, page_offset + page_count, &delta, true)) return false;

        if (delta > 0) kernel.panicf("invalid delta calculation", .{});
        const delta_u = @intCast(u64, -delta);

        if (region.data.u.normal.commit_page_count < delta_u) kernel.panicf("invalid delta calculation", .{});

        decommit(delta_u * page_size, region.flags.contains(.fixed));
        space.commit_count -= delta_u;
        region.data.u.normal.commit_page_count -= delta_u;
        arch.unmap_pages(space, region.descriptor.base_address + page_offset * page_size, page_count, UnmapPagesFlags.from_flag(.free), 0, null);

        return true;
    }

    pub fn handle_page_fault(space: *AddressSpace, asked_address: u64, flags: HandlePageFaultFlags) callconv(.C) bool
    {
        const address = asked_address & ~@as(u64, page_size - 1);
        const lock_acquired = flags.contains(.lock_acquired);

        var region = blk:
        {
            if (lock_acquired)
            {
                space.reserve_mutex.assert_locked();
                const result = space.find_region(asked_address) orelse return false;
                if (!result.data.pin.take_extended(WriterLock.shared, true)) return false;
                break :blk result;
            }
            else
            {
                if (kernel.pmm.get_available_page_count() < Physical.Allocator.critical_available_page_threshold and arch.get_current_thread() != null and !arch.get_current_thread().?.is_page_generator)
                {
                    _ = kernel.pmm.available_not_critical_event.wait();
                }
                _ = space.reserve_mutex.acquire();
                defer space.reserve_mutex.release();

                const result = space.find_region(asked_address) orelse return false;
                if (!result.data.pin.take_extended(WriterLock.shared, true)) return false;
                break :blk result;
            }
        };

        defer region.data.pin.return_lock(WriterLock.shared);
        _ = region.data.map_mutex.acquire();
        defer region.data.map_mutex.release();

        if (arch.translate_address(address, flags.contains(.write)) != 0) return true;

        var copy_on_write = false;
        var mark_modified = false;

        if (flags.contains(.write))
        {
            if (region.flags.contains(.copy_on_write)) copy_on_write = true
            else if (region.flags.contains(.read_only)) return false
            else mark_modified = true;
        }

        const offset_into_region = address - region.descriptor.base_address;
        _ = offset_into_region;
        var physical_allocation_flags = Physical.Flags.empty();
        var zero_page = true;

        if (space.user)
        {
            physical_allocation_flags = physical_allocation_flags.or_flag(.zeroed);
            zero_page = false;
        }

        var map_page_flags = MapPageFlags.empty();
        if (space.user) map_page_flags = map_page_flags.or_flag(.user);
        if (region.flags.contains(.not_cacheable)) map_page_flags = map_page_flags.or_flag(.not_cacheable);
        if (region.flags.contains(.write_combining)) map_page_flags = map_page_flags.or_flag(.write_combining);
        if (!mark_modified and !region.flags.contains(.fixed) and region.flags.contains(.file)) map_page_flags = map_page_flags.or_flag(.read_only);

        if (region.flags.contains(.physical))
        {
            _ = arch.map_page(space, region.data.u.physical.offset + address - region.descriptor.base_address, address, map_page_flags);
            return true;
        }
        else if (region.flags.contains(.shared))
        {
            const shared_region = region.data.u.shared.region.?;
            if (shared_region.handle_count.read_volatile() == 0) kernel.panicf("Shared region has no handles", .{});
            _ = shared_region.mutex.acquire();

            const offset = address - region.descriptor.base_address + region.data.u.shared.offset;

            if (offset >= shared_region.size)
            {
                shared_region.mutex.release();
                return false;
            }

            const entry = @intToPtr(*u64, shared_region.address + (offset / page_size * @sizeOf(u64)));

            // @TODO SHARED_ENTRY_PRESENT
            if (entry.* & 1 != 0) zero_page = false
            else entry.* = physical_allocate_with_flags(physical_allocation_flags) | 1;

            _ = arch.map_page(space, entry.* & ~@as(u64, page_size - 1), address, map_page_flags);
            if (zero_page) EsMemoryZero(address, page_size);
            shared_region.mutex.release();
            return true;
        }
        else if (region.flags.contains(.file))
        {
            TODO(@src());
        }
        else if (region.flags.contains(.normal))
        {
            if (!region.flags.contains(.no_commit_tracking))
            {
                if (!region.data.u.normal.commit.contains(offset_into_region >> page_bit_count))
                {
                    return false;
                }
            }

            _ = arch.map_page(space, physical_allocate_with_flags(physical_allocation_flags), address, map_page_flags);
            if (zero_page) EsMemoryZero(address, page_size);
            return true;
        }
        else if (region.flags.contains(.guard))
        {
            TODO(@src());
        }
        else
        {
            return false;
        }
    }

    pub fn close_reference(space: *AddressSpace) callconv(.C) void
    {
        if (space == &kernel.address_space) return;
        if (space.reference_count.read_volatile() < 1) kernel.panicf("space has invalid reference count", .{});
        if (space.reference_count.atomic_fetch_sub(1) > 1) return;

        space.remove_async_task.register(CloseReferenceTask);
    }
    pub fn map_physical(space: *AddressSpace, asked_offset: u64, asked_byte_count: u64, caching: Region.Flags) callconv(.C) u64
    {
        const offset2 = asked_offset & (page_size - 1);
        const offset = asked_offset - offset2;
        const byte_count = if (offset2 != 0) asked_byte_count + page_size else asked_byte_count;

        const region = blk:
        {
            _ = space.reserve_mutex.acquire();
            defer space.reserve_mutex.release();

            const result = space.reserve(byte_count, caching.or_flag(.fixed).or_flag(.physical), 0) orelse return 0;
            result.data.u.physical.offset = offset;
            break :blk result;
        };

        var i: u64 = 0;
        while (i < region.descriptor.page_count) : (i += 1)
        {
            _ = space.handle_page_fault(region.descriptor.base_address + i * page_size, HandlePageFaultFlags.empty());
        }

        return region.descriptor.base_address + offset2;
    }

    pub fn map_shared(space: *AddressSpace, shared_region: *SharedRegion, offset: u64, asked_byte_count: u64, flags: Region.Flags, base_address: u64) callconv(.C) u64
    {
        _ = object.open_handle(shared_region, 0);
        _ = space.reserve_mutex.acquire();
        defer space.reserve_mutex.release();

        const byte_count: u64 = if (offset & (page_size - 1) != 0) asked_byte_count + (offset & (page_size - 1)) else asked_byte_count;
        if (shared_region.size <= offset or shared_region.size < offset + byte_count)
        {
            object.close_handle(@ptrToInt(shared_region), 0);
            return 0;
        }
        const region = space.reserve(byte_count, flags.or_flag(.shared), base_address) orelse
        {
            object.close_handle(@ptrToInt(shared_region), 0);
            return 0;
        };

        if (!region.flags.contains(.shared)) kernel.panicf("cannot commit into non-shared region", .{});
        if (region.data.u.shared.region != null) kernel.panicf("a shared region has already been bound", .{});

        region.data.u.shared.region = shared_region;
        region.data.u.shared.offset = offset & ~@as(u64, page_size - 1);
        return region.descriptor.base_address + (offset & (page_size - 1));
    }

    pub fn init(space: *AddressSpace) callconv(.C) bool
    {
        space.user = true;

        const region = @intToPtr(?*Region, EsHeapAllocate(@sizeOf(Region), true, &kernel.heapCore)) orelse return false;

        if (!arch.initialize_user_space(space, region))
        {
            EsHeapFree(@ptrToInt(region), @sizeOf(Region), &kernel.heapCore);
            return false;
        }

        _ = space.free_region_base.insert(&region.u.item.base, region, region.descriptor.base_address, .panic);
        _ = space.free_region_size.insert(&region.u.item.u.size, region, region.descriptor.page_count, .allow);

        return true;
    }

    pub fn unpin_region(space: *AddressSpace, region: *Region) callconv(.C) void
    {
        _ = space.reserve_mutex.acquire();
        region.data.pin.return_lock(WriterLock.shared);
        space.reserve_mutex.release();
    }
};

pub const SharedRegion = extern struct
{
    size: u64,
    handle_count: Volatile(u64),
    mutex: Mutex,
    address: u64,
};

pub const Region = extern struct
{
    descriptor: Region.Descriptor,
    flags: Region.Flags,
    data: extern struct
    {
        u: extern union
        {
            physical: extern struct
            {
                offset: u64,
            },
            shared: extern struct
            {
                region: ?*SharedRegion,
                offset: u64,
            },
            file: extern struct
            {
                node: ?*anyopaque, // @TODO: do right
                offset: u64,
                zeroed_bytes: u64,
                file_handle_flags: u64,
            },
            normal: extern struct
            {
                commit: Range.Set,
                commit_page_count: u64,
                guard_before: ?*Region,
                guard_after: ?*Region,
            },
        },
        pin: WriterLock,
        map_mutex: Mutex,
    },
    u: extern union
    {
        item: extern struct
        {
            base: AVLTree(Region).Item,
            u: extern union
            {
                size: AVLTree(Region).Item,
                non_guard: LinkedList(Region).Item,
            },
        },
        core: extern struct
        {
            used: bool,
        },
    },

    pub const Descriptor = extern struct
    {
        base_address: u64,
        page_count: u64,
    };

    pub const Flags = Bitflag(enum(u32)
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
        });

    pub fn zero_data_field(self: *@This()) void
    {
        std.mem.set(u8, @ptrCast([*]u8, &self.data)[0..@sizeOf(@TypeOf(self.data))], 0);
    }
};


pub fn init() void
{
    {
        kernel.mmCoreRegions = @intToPtr([*]Region, arch.core_memory_region_start);
        kernel.mmCoreRegions[0].u.core.used = false;
        kernel.mmCoreRegionCount = 1;
        arch.memory_init();

        const region = @intToPtr(?*Region, EsHeapAllocate(@sizeOf(Region), true, &kernel.heapCore)) orelse unreachable;
        region.descriptor.base_address = arch.kernel_address_space_start;
        region.descriptor.page_count = arch.kernel_address_space_size / page_size;
        _ = kernel.address_space.free_region_base.insert(&region.u.item.base, region, region.descriptor.base_address, .panic);
        _ = kernel.address_space.free_region_size.insert(&region.u.item.u.size, region, region.descriptor.page_count, .allow);
    }

    {
        _ = kernel.address_space.reserve_mutex.acquire();
        kernel.pmm.manipulation_region = @intToPtr(?*Region, (kernel.address_space.reserve(Physical.memory_manipulation_region_page_count * page_size, Region.Flags.empty(), 0) orelse unreachable).descriptor.base_address) orelse unreachable;
        kernel.address_space.reserve_mutex.release();

        const pageframe_database_count = (arch.physicalMemoryHighest + (page_size << 3)) >> page_bit_count;
        kernel.pmm.pageframes = @intToPtr(?[*]PageFrame, kernel.address_space.allocate_standard(pageframe_database_count * @sizeOf(PageFrame), Region.Flags.from_flag(.fixed), 0, true)) orelse unreachable;
        _ = kernel.pmm.free_or_zeroed_page_bitset.init(pageframe_database_count, true);
        kernel.pmm.pageframeDatabaseCount = pageframe_database_count;

        MMPhysicalInsertFreePagesStart();
        const commit_limit = arch.populate_pageframe_database();
        MMPhysicalInsertFreePagesEnd();
        kernel.pmm.pageframeDatabaseInitialised = true;

        kernel.pmm.commit_limit = @intCast(i64, commit_limit);
        kernel.pmm.commit_fixed_limit = kernel.pmm.commit_limit;
        // @Log
    }

    {
    }

    {
        kernel.pmm.zero_page_event.auto_reset.write_volatile(true);
        _ = commit(Physical.memory_manipulation_region_page_count * page_size, true);
        kernel.pmm.zero_page_thread = Thread.spawn("zero_page_thread", arch.GetMMZeroPageThreadAddress(), 0, Thread.Flags.from_flag(.low_priority), null, 0) orelse kernel.panicf("Unable to spawn zero page thread", .{});
        Thread.spawn("mm_balance_thread", arch.GetMMBalanceThreadAddress(), 0, Thread.Flags.empty(), null, 0).?.is_page_generator = true;
    }

    {
        kernel.mmGlobalDataRegion = MMSharedCreateRegion(@sizeOf(kernel.GlobalData), false, 0) orelse unreachable;
        kernel.globalData = @intToPtr(?*kernel.GlobalData, kernel.address_space.map_shared(kernel.mmGlobalDataRegion, 0, @sizeOf(kernel.GlobalData), Region.Flags.from_flag(.fixed), 0)) orelse unreachable;
        _ = MMFaultRange(@ptrToInt(kernel.globalData), @sizeOf(kernel.GlobalData), HandlePageFaultFlags.from_flag(.for_supervisor));
    }
}


pub const PageFrame = extern struct
{
    state: Volatile(PageFrame.State),
    flags: Volatile(u8),
    cache_reference: ?*volatile u64,
    u: extern union
    {
        list: extern struct
        {
            next: Volatile(u64),
            previous: ?*volatile u64,
        },

        active: extern struct
        {
            references: Volatile(u64),
        },
    },

    pub const State = enum(i8)
    {
        unusable,
        bad,
        zeroed,
        free,
        standby,
        active,
    };
};

const ObjectCache = extern struct
{
    lock: Spinlock,
    items: SimpleList,
    count: u64,
    trim: fn (cache: *ObjectCache) callconv(.C) bool,
    trim_lock: WriterLock,
    item: LinkedList(ObjectCache).Item,
    average_object_bytes: u64,

    const trim_group_count = 1024;
};

pub const Physical = extern struct
{
    pub const Allocator = extern struct
    {
        pageframes: [*]PageFrame,
        pageframeDatabaseInitialised: bool,
        pageframeDatabaseCount: u64,

        first_free_page: u64,
        first_zeroed_page: u64,
        first_standby_page: u64,
        last_standby_page: u64,

        free_or_zeroed_page_bitset: Bitset,

        zeroed_page_count: u64,
        free_page_count: u64,
        standby_page_count: u64,
        active_page_count: u64,

        commit_fixed: i64,
        commit_pageable: i64,
        commit_fixed_limit: i64,
        commit_limit: i64,

        commit_mutex: Mutex,
        pageframe_mutex: Mutex,

        manipulation_lock: Mutex,
        manipulation_processor_lock: Spinlock,
        manipulation_region: ?*Region,

        zero_page_thread: *Thread,
        zero_page_event: Event,

        object_cache_list: LinkedList(ObjectCache),
        object_cache_list_mutex: Mutex,

        available_critical_event: Event,
        available_low_event: Event,
        available_not_critical_event: Event,

        approximate_total_object_cache_byte_count: u64,
        trim_object_cache_event: Event,

        next_process_to_balance: ?*Process,
        next_region_to_balance: ?*Region,
        balance_resume_position: u64,

        fn get_available_page_count(self: @This()) callconv(.Inline) u64
        {
            return self.zeroed_page_count + self.free_page_count + self.standby_page_count;
        }

        fn get_remaining_commit(self: @This()) callconv(.Inline) i64
        {
            return self.commit_limit - self.commit_pageable - self.commit_fixed;
        }

        fn should_trim_object_cache(self: @This()) callconv(.Inline) bool
        {
            return self.approximate_total_object_cache_byte_count / page_size > self.get_object_cache_maximum_cache_page_count();
        }

        fn get_object_cache_maximum_cache_page_count(self: @This()) callconv(.Inline) i64
        {
            return @divTrunc(self.commit_limit - self.get_non_cache_memory_page_count(), 2);
        }

        fn get_non_cache_memory_page_count(self: @This()) callconv(.Inline) i64
        {
            return @divTrunc(self.commit_fixed - self.commit_pageable - @intCast(i64, self.approximate_total_object_cache_byte_count), page_size);
        }

        fn start_insert_free_pages(self: *@This()) void
        {
            _ = self;
        }

        fn end_insert_free_pages(self: *@This()) void
        {
            if (self.free_page_count > zero_page_threshold)
            {
                _ = self.zero_page_event.set(true);
            }

            self.update_available_page_count(true);
        }

        fn update_available_page_count(self: *@This(), increase: bool) void
        {
            if (self.get_available_page_count() >= critical_available_page_threshold)
            {
                _ = self.available_not_critical_event.set(true);
                self.available_not_critical_event.reset();
            }
            else
            {
                self.available_not_critical_event.reset();
                _ = self.available_critical_event.set(true);

                if (!increase)
                {
                    // @Log
                }
            }

            if (self.get_available_page_count() >= low_available_page_threshold) self.available_low_event.reset()
            else _ = self.available_low_event.set(true);
        }

        const zero_page_threshold = 16;
        const low_available_page_threshold = 16777216 / page_size;
        const critical_available_page_threshold = 1048576 / page_size;
        const critical_remaining_commit_threshold = 1048576 / page_size;
        const page_count_to_find_balance = 4194304 / page_size;
    };

    pub const MemoryRegion = Region.Descriptor;

    pub const Flags = Bitflag(enum(u32)
        {
            can_fail = 0,
            commit_now = 1,
            zeroed = 2,
            lock_acquired = 3,
        });

    pub const memory_manipulation_region_page_count = 0x10;
};

pub fn decommit(byte_count: u64, fixed: bool) callconv(.C) void
{
    if (byte_count & (page_size - 1) != 0) kernel.panicf("byte count not page-aligned", .{});

    const needed_page_count = @intCast(i64, byte_count / page_size);
    _ = kernel.pmm.commit_mutex.acquire();
    defer kernel.pmm.commit_mutex.release();

    if (fixed)
    {
        if (kernel.pmm.commit_fixed < needed_page_count) kernel.panicf("decommited too many pages", .{});
        kernel.pmm.commit_fixed -= needed_page_count;
    }
    else
    {
        if (kernel.pmm.commit_pageable < needed_page_count) kernel.panicf("decommited too many pages", .{});
        kernel.pmm.commit_pageable -= needed_page_count;
    }
}


pub const HandlePageFaultFlags = Bitflag(enum(u32)
    {
        write = 0,
        lock_acquired = 1,
        for_supervisor = 2,
    }
);

pub const MapPageFlags = Bitflag(enum(u32)
    {
        not_cacheable = 0,
        user = 1,
        overwrite = 2,
        commit_tables_now = 3,
        read_only = 4,
        copied = 5,
        no_new_tables = 6,
        frame_lock_acquired = 7,
        write_combining = 8,
        ignore_if_mapped = 9,
    }
);

pub const UnmapPagesFlags = Bitflag(enum(u32)
    {
        free = 0,
        free_copied = 1,
        balance_file = 2,
    }
);

pub fn physical_allocate_with_flags(flags: Physical.Flags) u64
{
    return physical_allocate(flags, 1, 1, 0);
}


export fn MMUpdateAvailablePageCount(increase: bool) callconv(.C) void
{
    if (kernel.pmm.get_available_page_count() >= Physical.Allocator.critical_available_page_threshold)
    {
        _ = kernel.pmm.available_not_critical_event.set(true);
        kernel.pmm.available_critical_event.reset();
    }
    else
    {
        kernel.pmm.available_not_critical_event.reset();
        _ = kernel.pmm.available_critical_event.set(true);

        if (!increase)
        {
            // log error
        }
    }

    if (kernel.pmm.get_available_page_count() >= Physical.Allocator.low_available_page_threshold)
    {
        kernel.pmm.available_low_event.reset();
    }
    else
    {
        _ = kernel.pmm.available_low_event.set(true);
    }
}

export fn MMPhysicalActivatePages(pages: u64, count: u64) callconv(.C) void
{
    kernel.pmm.pageframe_mutex.assert_locked();

    for (kernel.pmm.pageframes[pages..pages+count]) |*frame, i|
    {
        switch (frame.state.read_volatile())
        {
            .free => kernel.pmm.free_page_count -= 1,
            .zeroed => kernel.pmm.zeroed_page_count -= 1,
            .standby =>
            {
                kernel.pmm.standby_page_count -= 1;

                if (kernel.pmm.last_standby_page == pages + i)
                {
                    if (frame.u.list.previous == &kernel.pmm.first_standby_page)
                    {
                        kernel.pmm.last_standby_page = 0;
                    }
                    else
                    {
                        kernel.pmm.last_standby_page = (@ptrToInt(frame.u.list.previous) - @ptrToInt(kernel.pmm.pageframes)) / @sizeOf(PageFrame);
                    }
                }
            },
            else => kernel.panicf("Corrupt page frame database", .{}),
        }

        frame.u.list.previous.?.* = frame.u.list.next.read_volatile();

        if (frame.u.list.next.read_volatile() != 0)
        {
            kernel.pmm.pageframes[frame.u.list.next.read_volatile()].u.list.previous = frame.u.list.previous;
        }
        EsMemoryZero(@ptrToInt(frame), @sizeOf(PageFrame));
        frame.state.write_volatile(.active);
    }

    kernel.pmm.active_page_count += count;
    MMUpdateAvailablePageCount(false);
}

pub export fn commit(byte_count: u64, fixed: bool) callconv(.C) bool
{
    if (byte_count & (page_size - 1) != 0) kernel.panicf("Bytes should be page-aligned", .{});

    const needed_page_count = @intCast(i64, byte_count / page_size);

    _  = kernel.pmm.commit_mutex.acquire();
    defer kernel.pmm.commit_mutex.release();

    // Else we haven't started tracking commit counts yet
    if (kernel.pmm.commit_limit != 0)
    {
        if (fixed)
        {
            if (needed_page_count > kernel.pmm.commit_fixed_limit - kernel.pmm.commit_fixed) return false;
            if (@intCast(i64, kernel.pmm.get_available_page_count()) - needed_page_count < Physical.Allocator.critical_available_page_threshold and !arch.get_current_thread().?.is_page_generator) return false;
            kernel.pmm.commit_fixed += needed_page_count;
        }
        else
        {
            if (needed_page_count > kernel.pmm.get_remaining_commit() - if (arch.get_current_thread().?.is_page_generator) @as(i64, 0) else @as(i64, Physical.Allocator.critical_remaining_commit_threshold)) return false;
            kernel.pmm.commit_pageable += needed_page_count;
        }

        if (kernel.pmm.should_trim_object_cache()) _ = kernel.pmm.trim_object_cache_event.set(true);
    }

    return true;
}

export fn MMSharedResizeRegion(region: *SharedRegion, asked_size: u64) callconv(.C) bool
{
    _ = region.mutex.acquire();
    defer region.mutex.release();

    const size = (asked_size + page_size - 1) & ~@as(u64, page_size - 1);
    const page_count = size / page_size;
    const old_page_count = region.size / page_size;
    const old_address = region.address;

    const new_address = EsHeapAllocate(page_count * @sizeOf(u64), true, &kernel.heapCore);
    if (new_address == 0 and page_count != 0) return false;

    if (old_page_count > page_count)
    {
        decommit(page_size * (old_page_count - page_count), true);
    }
    else if (page_count > old_page_count)
    {
        if (!commit(page_size * (page_count - old_page_count), true))
        {
            EsHeapFree(new_address, page_count * @sizeOf(u64), &kernel.heapCore);
            return false;
        }
    }

    region.size = size;
    region.address = new_address;

    if (old_address == 0) return true;

    if (old_page_count > page_count)
    {
        var i = page_count;
        while (i < old_page_count) : (i += 1)
        {
            // @TODO
            const addresses = @intToPtr([*]u64, old_address);
            const address = addresses[i];
            // MM_SHARED_ENTRY_PRESENT
            if (address & 1 != 0) _ = physical_free(address, false, 1);
        }
    }

    const copy = if (old_page_count > page_count) page_count else old_page_count;
    EsMemoryCopy(region.address, old_address, @sizeOf(u64) * copy);
    EsHeapFree(old_address, old_page_count * @sizeOf(u64), &kernel.heapCore);
    return true;
}

export fn MMSharedDestroyRegion(region: *SharedRegion) callconv(.C) void
{
    _ = MMSharedResizeRegion(region, 0);
    EsHeapFree(@ptrToInt(region), 0, &kernel.heapCore);
}

export fn MMSharedCreateRegion(size: u64, fixed: bool, below: u64) callconv(.C) ?*SharedRegion
{
    if (size == 0) return null;

    const region = @intToPtr(?*SharedRegion, EsHeapAllocate(@sizeOf(SharedRegion), true, &kernel.heapCore)) orelse return null;

    region.handle_count.write_volatile(1);

    if (!MMSharedResizeRegion(region, size))
    {
        EsHeapFree(@ptrToInt(region), 0, &kernel.heapCore);
        return null;
    }

    if (fixed)
    {
        var i: u64 = 0;
        while (i < region.size >> page_bit_count) : (i += 1)
        {
            @intToPtr([*]u64, region.address)[i] = physical_allocate(Physical.Flags.from_flag(.zeroed), 1, 1, below) | 1; // MM_SHARED_ENTRY_PRESENT
        }
    }

    return region;
}


export fn MMPhysicalInsertFreePagesStart() callconv(.C) void
{
}

export fn MMPhysicalInsertFreePagesEnd() callconv(.C) void
{
    if (kernel.pmm.free_page_count > Physical.Allocator.zero_page_threshold) _ = kernel.pmm.zero_page_event.set(true);
    MMUpdateAvailablePageCount(true);
}

export fn PMZero(asked_page_ptr: [*]u64, asked_page_count: u64, contiguous: bool) callconv(.C) void
{
    _ = kernel.pmm.manipulation_lock.acquire();

    var page_count = asked_page_count;
    var pages = asked_page_ptr;

    while (true)
    {
        const do_count = if (page_count > Physical.memory_manipulation_region_page_count) Physical.memory_manipulation_region_page_count else page_count;
        page_count -= do_count;

        const region = @ptrToInt(kernel.pmm.manipulation_region);
        var i: u64 = 0;
        while (i < do_count) : (i += 1)
        {
            _ = arch.map_page(&kernel.core_address_space, if (contiguous) pages[0] + (i << page_bit_count) else pages[i], region + page_size * i, MapPageFlags.from_flags(.{ .overwrite, .no_new_tables }));
        }

        kernel.pmm.manipulation_processor_lock.acquire();

        i = 0;
        while (i < do_count) : (i += 1)
        {
            arch.invalidate_page(region + i * page_size);
        }

        EsMemoryZero(region, do_count * page_size);
        kernel.pmm.manipulation_processor_lock.release();

        if (page_count != 0)
        {
            if (!contiguous) pages = @intToPtr([*]u64, @ptrToInt(pages) + Physical.memory_manipulation_region_page_count);
        }
        else break;
    }

    kernel.pmm.manipulation_lock.release();
}

export var earlyZeroBuffer: [page_size]u8 align(page_size) = undefined;

export fn physical_allocate(flags: Physical.Flags, count: u64, alignment: u64, below: u64) callconv(.C) u64
{
    const mutex_already_acquired = flags.contains(.lock_acquired);
    if (!mutex_already_acquired) _ = kernel.pmm.pageframe_mutex.acquire()
    else kernel.pmm.pageframe_mutex.assert_locked();
    defer if (!mutex_already_acquired) kernel.pmm.pageframe_mutex.release();

    var commit_now = @intCast(i64, count * page_size);

    if (flags.contains(.commit_now))
    {
        if (!commit(@intCast(u64, commit_now), true)) return 0;
    }
    else commit_now = 0;

    const simple = count == 1 and alignment == 1 and below == 0;

    if (!kernel.pmm.pageframeDatabaseInitialised)
    {
        if (!simple) kernel.panicf("non-simple allocation before initialization of the pageframe database", .{});
        const page = arch.EarlyAllocatePage();
        if (flags.contains(.zeroed))
        {
            _ = arch.map_page(&kernel.core_address_space, page, @ptrToInt(&earlyZeroBuffer), MapPageFlags.from_flags(.{ .overwrite, .no_new_tables, .frame_lock_acquired }));
            earlyZeroBuffer = zeroes(@TypeOf(earlyZeroBuffer));
        }

        return page;
    }
    else if (!simple)
    {
        const pages = kernel.pmm.free_or_zeroed_page_bitset.get(count, alignment, below);
        if (pages != std.math.maxInt(u64))
        {
            MMPhysicalActivatePages(pages, count);
            var address = pages << page_bit_count;
            if (flags.contains(.zeroed)) PMZero(@ptrCast([*]u64, &address), count, true);
            return address;
        }
        // else error
    }
    else
    {
        var not_zeroed = false;
        var page = kernel.pmm.first_zeroed_page;

        if (page == 0)
        {
            page = kernel.pmm.first_free_page;
            not_zeroed = true;
        }

        if (page == 0)
        {
            page = kernel.pmm.last_standby_page;
            not_zeroed = true;
        }

        if (page != 0)
        {
            const frame = &kernel.pmm.pageframes[page];

            switch (frame.state.read_volatile())
            {
                .active => kernel.panicf("corrupt page frame database", .{}),
                .standby =>
                {
                    if (frame.cache_reference.?.* != ((page << page_bit_count) | 1)) // MM_SHARED_ENTRY_PRESENT
                    {
                        kernel.panicf("corrupt shared reference back pointer in frame", .{});
                    }

                    frame.cache_reference.?.* = 0;
                },
                else =>
                {
                    kernel.pmm.free_or_zeroed_page_bitset.take(page);
                }
            }

            MMPhysicalActivatePages(page, 1);

            var address = page << page_bit_count;
            if (not_zeroed and flags.contains(.zeroed)) PMZero(@ptrCast([*]u64, &address), 1, false);

            return address;
        }
        // else fail
    }

    // failed
    if (!flags.contains(.can_fail))
    {
        kernel.panicf("out of memory", .{});
    }

    decommit(@intCast(u64, commit_now), true);
    return 0;
}


pub export fn physical_allocate_and_map(asked_size: u64, asked_alignment: u64, maximum_bits: u64, zeroed: bool, flags: Region.Flags, p_virtual_address: *u64, p_physical_address: *u64) callconv(.C) bool
{
    const size = if (asked_size == 0) @as(u64, 1) else asked_size;
    const alignment = if (asked_alignment == 0) @as(u64, 1) else asked_alignment;

    const no_below = maximum_bits == 0 or maximum_bits >= 64;

    const size_in_pages = (size + page_size - 1) >> page_bit_count;
    const physical_address = physical_allocate(Physical.Flags.from_flags(.{ .can_fail, .commit_now }), size_in_pages, (alignment + page_size - 1) >> page_bit_count, if (no_below) 0 else @as(u64, 1) << @truncate(u6, maximum_bits));
    if (physical_address == 0) return false;

    const virtual_address = kernel.address_space.map_physical(physical_address, size, flags);
    if (virtual_address == 0)
    {
        physical_free(physical_address, false, size_in_pages);
        return false;
    }

    if (zeroed) EsMemoryZero(virtual_address, size);

    p_virtual_address.* = virtual_address;
    p_physical_address.* = physical_address;

    return true;
}

export fn MMPhysicalInsertZeroedPage(page: u64) callconv(.C) void
{
    if (arch.get_current_thread() != kernel.pmm.zero_page_thread) kernel.panicf("inserting a zeroed page not on the mmzeropagethread", .{});

    const frame = &kernel.pmm.pageframes[page];
    frame.state.write_volatile(.zeroed);

    frame.u.list.next.write_volatile(kernel.pmm.first_zeroed_page);
    frame.u.list.previous = &kernel.pmm.first_zeroed_page;
    if (kernel.pmm.first_zeroed_page != 0) kernel.pmm.pageframes[kernel.pmm.first_zeroed_page].u.list.previous = &frame.u.list.next.value;
    kernel.pmm.first_zeroed_page = page;

    kernel.pmm.zeroed_page_count += 1;
    kernel.pmm.free_or_zeroed_page_bitset.put(page);
    MMUpdateAvailablePageCount(true);
}

export fn MMZeroPageThread() callconv(.C) void
{
    while (true)
    {
        _ = kernel.pmm.zero_page_event.wait();
        _ = kernel.pmm.available_not_critical_event.wait();

        var done = false;

        while (!done)
        {
            var pages: [Physical.memory_manipulation_region_page_count]u64 = undefined;

            var i = blk:
            {
                _ = kernel.pmm.pageframe_mutex.acquire();
                defer kernel.pmm.pageframe_mutex.release();

                for (pages) |*page, page_i|
                {
                    if (kernel.pmm.first_free_page != 0)
                    {
                        page.* = kernel.pmm.first_free_page;
                        MMPhysicalActivatePages(page.*, 1);
                    }
                    else
                    {
                        done = true;
                        break :blk page_i;
                    }

                    const frame = &kernel.pmm.pageframes[page.*];
                    frame.state.write_volatile(.active);
                    kernel.pmm.free_or_zeroed_page_bitset.take(pages[page_i]);
                }

                break :blk pages.len;
            };

            var j: u64 = 0;
            while (j < i) : (j += 1)
            {
                pages[j] <<= page_bit_count;
            }

            if (i != 0) PMZero(&pages, i, false);

            _ = kernel.pmm.pageframe_mutex.acquire();
            kernel.pmm.active_page_count -= i;

            while (true)
            {
                const breaker = i;
                i -= 1;
                if (breaker == 0) break;
                MMPhysicalInsertZeroedPage(pages[i] >> page_bit_count);
            }

            kernel.pmm.pageframe_mutex.release();
        }
    }
}

export fn MMBalanceThread() callconv(.C) void
{
    var target_available_pages: u64 = 0;

    while (true)
    {
        if (kernel.pmm.get_available_page_count() >= target_available_pages)
        {
            _ = kernel.pmm.available_low_event.wait();
            target_available_pages = Physical.Allocator.low_available_page_threshold + Physical.Allocator.page_count_to_find_balance;
        }

        _ = kernel.scheduler.all_processes_mutex.acquire();
        const process = if (kernel.pmm.next_process_to_balance) |p| p else kernel.scheduler.all_processes.first.?.value.?;
        kernel.pmm.next_process_to_balance = if (process.all_item.next) |next| next.value else null;
        _ = object.open_handle(process, 0);
        kernel.scheduler.all_processes_mutex.release();

        const space = process.address_space;
        Thread.SetTemporaryAddressSpace(space);
        _ = space.reserve_mutex.acquire();
        var maybe_item = if (kernel.pmm.next_region_to_balance) |r| &r.u.item.u.non_guard else space.used_regions_non_guard.first;

        while (maybe_item != null and kernel.pmm.get_available_page_count() < target_available_pages)
        {
            const item = maybe_item.?;
            const region = item.value.?;

            _ = region.data.map_mutex.acquire();

            var can_resume = false;

            if (region.flags.contains(.file))
            {
                TODO(@src());
            }
            else if (region.flags.contains(.cache))
            {
                TODO(@src());
                //_ = activeSectionManager.mutex.acquire();

                //var maybe_item2 = activeSectionManager.LRU_list.first;
                //while (maybe_item2 != null and kernel.pmm.get_available_page_count() < target_available_pages)
                //{
                    //const item2 = maybe_item2.?;
                    //const section = item2.value.?;
                    //if (section.cache != null and section.referenced_page_count != 0) 
                    //{
                        //TODO(@src());
                        //// CCDereferenceActiveSection(section, 0);
                    //}
                    //maybe_item2 = item2.next;
                //}

                //activeSectionManager.mutex.release();
            }

            region.data.map_mutex.release();

            if (kernel.pmm.get_available_page_count() >= target_available_pages and can_resume) break;

            maybe_item = item.next;
            kernel.pmm.balance_resume_position = 0;
        }


        if (maybe_item) |item|
        {
            kernel.pmm.next_region_to_balance = item.value;
            kernel.pmm.next_process_to_balance = process;
        }
        else
        {
            kernel.pmm.next_region_to_balance = null;
            kernel.pmm.balance_resume_position = 0;
        }

        space.reserve_mutex.release();
        Thread.SetTemporaryAddressSpace(null);
        object.close_handle(process, 0);
    }
}


export fn MMFaultRange(address: u64, byte_count: u64, flags: HandlePageFaultFlags) callconv(.C) bool
{
    const start = address & ~@as(u64, page_size - 1);
    const end = (address + byte_count - 1) & ~@as(u64, page_size - 1);
    var page = start;

    while (page <= end) : (page += page_size)
    {
        if (!arch.handle_page_fault(page, flags)) return false;
    }

    return true;
}

// @TODO: MMInitialise


fn CloseReferenceTask(task: *AsyncTask) void
{
    const space = @fieldParentPtr(AddressSpace, "remove_async_task", task);
    arch.finalize_address_space(space);
    kernel.scheduler.address_space_pool.remove(@ptrToInt(space));
}
pub fn physical_insert_free_pages_next(page: u64) callconv(.C) void
{
    const frame = &kernel.pmm.pageframes[page];
    frame.state.write_volatile(.free);

    frame.u.list.next.write_volatile(kernel.pmm.first_free_page);
    frame.u.list.previous = &kernel.pmm.first_free_page;
    if (kernel.pmm.first_free_page != 0) kernel.pmm.pageframes[kernel.pmm.first_free_page].u.list.previous = &frame.u.list.next.value;
    kernel.pmm.first_free_page = page;

    kernel.pmm.free_or_zeroed_page_bitset.put(page);
    kernel.pmm.free_page_count += 1;
}

pub fn physical_free(asked_page: u64, mutex_already_acquired: bool, count: u64) callconv(.C) void
{
    if (asked_page == 0) kernel.panicf("invalid page", .{});
    if (mutex_already_acquired) kernel.pmm.pageframe_mutex.assert_locked()
    else _ = kernel.pmm.pageframe_mutex.acquire();
    if (!kernel.pmm.pageframeDatabaseInitialised) kernel.panicf("PMM not yet initialized", .{});

    const page = asked_page >> page_bit_count;

    MMPhysicalInsertFreePagesStart();

    for (kernel.pmm.pageframes[0..count]) |*frame|
    {
        if (frame.state.read_volatile() == .free) kernel.panicf("attempting to free a free page", .{});
        if (kernel.pmm.commit_fixed_limit != 0) kernel.pmm.active_page_count -= 1;
        physical_insert_free_pages_next(page);
    }

    MMPhysicalInsertFreePagesEnd();

    if (!mutex_already_acquired) kernel.pmm.pageframe_mutex.release();
}

pub export fn check_unusable(physical_start: u64, byte_count: u64) callconv(.C) void
{
    var i = physical_start / page_size;
    while (i < (physical_start + byte_count + page_size - 1) / page_size and i < kernel.pmm.pageframeDatabaseCount) : (i += 1)
    {
        if (kernel.pmm.pageframes[i].state.read_volatile() != .unusable) kernel.panicf("Pageframe at address should be unusable", .{});
    }
}

