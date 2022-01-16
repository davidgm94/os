const kernel = @import("kernel.zig");

const TODO = kernel.TODO;
const panic_raw = kernel.panic_raw;

const Volatile = kernel.Volatile;
const VolatilePointer = kernel.VolatilePointer;

const Bitflag = kernel.Bitflag;
const AVLTree = kernel.AVLTree;
const LinkedList= kernel.LinkedList;
const Bitset = kernel.Bitset;
const Range = kernel.Range;

const Mutex = kernel.sync.Mutex;
const Spinlock = kernel.sync.Spinlock;
const Event = kernel.sync.Event;
const WriterLock = kernel.sync.WriterLock;

const Thread = kernel.Scheduler.Thread;
const Process = kernel.Scheduler.Process;

const page_size = kernel.Arch.page_size;
const page_bit_count = kernel.Arch.page_bit_count;
const fake_timer_interrupt = kernel.Arch.fake_timer_interrupt;
const get_current_thread = kernel.Arch.get_current_thread;
const translate_address = kernel.Arch.translate_address;
const kernel_address_space_start = kernel.Arch.kernel_address_space_start;
const kernel_address_space_size = kernel.Arch.kernel_address_space_size;

const std = @import("std");
const assert = std.debug.assert;

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

pub const SharedRegion = struct
{
};

pub const Region = struct
{
    descriptor: Region.Descriptor,
    flags: Region.Flags,
    data: struct
    {
        u: extern union
        {
            physical: struct
            {
                offset: u64,
            },
            shared: struct
            {
                region: ?*SharedRegion,
                offset: u64,
            },
            file: struct
            {
            },
            normal: struct
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
        item: struct
        {
            base: AVLTree(Region).Item,
            u: extern union
            {
                size: AVLTree(Region).Item,
                non_guard: LinkedList(Region).Item,
            },
        },
        core: struct
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

pub const AddressSpace = struct
{
    arch: kernel.Arch.AddressSpace,

    free_region_base: AVLTree(Region),
    free_region_size: AVLTree(Region),
    used_regions: AVLTree(Region),
    used_regions_non_guard: LinkedList(Region),

    reserve_mutex: Mutex,

    reference_count: Volatile(i32),
    user: bool,
    commit_count: u64,
    reserve_count: u64,
    // async_task
    //
    pub fn handle_page_fault(self: *@This(), fault_address: u64, flags: HandlePageFaultFlags) bool
    {
        const address = fault_address & ~@as(u64, page_size - 1);

        const lock_acquired = flags.contains(.lock_acquired);
        if (!lock_acquired and kernel.physical_allocator.get_available_page_count() < Physical.Allocator.critical_available_page_threshold and get_current_thread() != null and !get_current_thread().?.is_page_generator)
        {
            TODO();
        }

        var region: *Region = undefined;
        {
            if (!lock_acquired) _ = self.reserve_mutex.acquire()
            else self.reserve_mutex.assert_locked();
            defer if (!lock_acquired) self.reserve_mutex.release();

            if (self.find_region(address)) |result|
            {
                if (!result.data.pin.take_extended(WriterLock.shared, true)) return false;
                region = result;
            }
            else
            {
                return false;
            }
        }

        defer region.data.pin.return_lock(WriterLock.shared);
        _ = region.data.map_mutex.acquire();
        defer region.data.map_mutex.release();

        // Spurious page fault
        if (kernel.arch.translate_address(address, flags.contains(.write)) != 0)
        {
            return true;
        }

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
        var map_page_flags: MapPageFlags = MapPageFlags.empty();

        if (self.user)
        {
            physical_allocation_flags = physical_allocation_flags.or_flag(.zeroed);
            zero_page = false;
            map_page_flags = map_page_flags.or_flag(.user);
        }

        if (region.flags.contains(.not_cacheable)) map_page_flags = map_page_flags.or_flag(.not_cacheable);
        if (region.flags.contains(.write_combining)) map_page_flags = map_page_flags.or_flag(.write_combining);
        if (!mark_modified and !region.flags.contains(.fixed) and region.flags.contains(.file)) map_page_flags = map_page_flags.or_flag(.read_only);

        if (region.flags.contains(.physical))
        {
            TODO();
        }
        else if (region.flags.contains(.shared))
        {
            TODO();
        }
        else if (region.flags.contains(.file))
        {
            TODO();
        }
        else if (region.flags.contains(.normal))
        {
            if (!region.flags.contains(.no_commit_tracking) and !region.data.u.normal.commit.contains(offset_into_region >> page_bit_count))
            {
                return false;
            }

            const physical_address = kernel.physical_allocator.allocate_with_flags(physical_allocation_flags);
            _ = kernel.arch.map_page(self, physical_address, address, map_page_flags);
            if (zero_page) std.mem.set(u8, @intToPtr([*]u8, address)[0..page_size], 0);
            return true;
        }
        else if (region.flags.contains(.guard))
        {
            TODO();
        }
        else
        {
            TODO();
        }
    }

    pub fn find_region(self: *@This(), address: u64) ?*Region
    {
        self.reserve_mutex.assert_locked();

        if (self == &kernel.core.address_space)
        {
            const regions = kernel.core.regions;
            for (regions) |*region|
            {
                if (region.u.core.used and
                    region.descriptor.base_address <= address and
                    region.descriptor.base_address + (region.descriptor.page_count * page_size) > address)
                {
                    return region;
                }
            }
        }
        else
        {
            if (self.used_regions.find(address, .largest_below_or_equal)) |item|
            {
                const region = item.value.?;
                if (region.descriptor.base_address > address) panic_raw("broken used_regions use\n");
                if (region.descriptor.base_address + region.descriptor.page_count * page_size > address)
                {
                    return region;
                }
            }
        }

        return null;
    }

    pub fn reserve(self: *@This(), byte_count: u64, flags: Region.Flags) ?*Region
    {
        return self.reserve_extended(byte_count, flags, 0);
    }

    pub fn reserve_extended(self: *@This(), byte_count: u64, flags: Region.Flags, forced_address: u64) ?*Region
    {
        const needed_page_count = ((byte_count + page_size - 1) & ~@as(u64, page_size - 1)) / page_size;

        if (needed_page_count == 0) return null;

        self.reserve_mutex.assert_locked();

        const region = blk:
        {
            if (self == &kernel.core.address_space)
            {
                if (kernel.core.regions.len == kernel.Arch.core_memory_region_count) return null;

                if (forced_address != 0) panic_raw("Using a forced address in core address space\n");

                {
                    const new_region_count = kernel.core.regions.len + 1;
                    const needed_commit_page_count = new_region_count * @sizeOf(Region) / page_size;

                    while (kernel.core.region_commit_count < needed_commit_page_count) : (kernel.core.region_commit_count += 1)
                    {
                        if (!kernel.physical_allocator.commit(page_size, true)) return null;
                    }
                }

                for (kernel.core.regions) |*region|
                {
                    if (!region.u.core.used and region.descriptor.page_count >= needed_page_count)
                    {
                        if (region.descriptor.page_count > needed_page_count)
                        {
                            const last = kernel.core.regions.len;
                            kernel.core.regions.len += 1;
                            var split = &kernel.core.regions[last];
                            split.* = region.*;
                            split.descriptor.base_address += needed_page_count * page_size;
                            split.descriptor.page_count -= needed_page_count;
                        }

                        region.u.core.used = true;
                        region.descriptor.page_count = needed_page_count;
                        region.flags = flags;
                        // @WARNING: this is not working and may cause problem with the kernel
                        // region.data = std.mem.zeroes(@TypeOf(region.data));
                        region.zero_data_field();
                        assert(region.data.u.normal.commit.ranges.items.len == 0);

                        break :blk region;
                    }
                }

                return null;
            }
            else if (forced_address != 0)
            {
                TODO();
            }
            else
            {
                // @TODO: implement guard pages?
                
                if (self.free_region_size.find(needed_page_count, .smallest_above_or_equal)) |item|
                {
                    const region = item.value.?;
                    self.free_region_base.remove(&region.u.item.base);
                    self.free_region_size.remove(&region.u.item.u.size);

                    if (region.descriptor.page_count > needed_page_count)
                    {
                        const split = kernel.core.heap.allocateT(Region, true).?;
                        split.* = region.*;

                        split.descriptor.base_address += needed_page_count * page_size;
                        split.descriptor.page_count -= needed_page_count;

                        _ = self.free_region_base.insert(&split.u.item.base, split, split.descriptor.base_address, .panic);
                        _ = self.free_region_size.insert(&split.u.item.u.size, split, split.descriptor.page_count, .allow);
                    }

                    region.zero_data_field();
                    region.descriptor.page_count = needed_page_count;
                    region.flags = flags;
                    
                    // @TODO: if guard pages needed
                    _ = self.used_regions.insert(&region.u.item.base, region, region.descriptor.base_address, .panic);
                    break :blk region;
                }
                else
                {
                    return null;
                }
            }
        };

        if (!kernel.arch.commit_page_tables(self, region))
        {
            self.unreserve(region, false);
            return null;
        }

        if (self != &kernel.core.address_space)
        {
            region.u.item.u.non_guard = std.mem.zeroes(@TypeOf(region.u.item.u.non_guard));
            region.u.item.u.non_guard.this = region;
            TODO();
        }

        self.reserve_count += needed_page_count;

        return region;
    }

    pub fn unreserve(self: *@This(), region_to_remove: *Region, unmap_pages: bool) void
    {
        _ = self;
        _ = region_to_remove;
        _ = unmap_pages;
        TODO();
    }

    pub fn standard_allocate(self: *@This(), byte_count: u64, flags: Region.Flags) u64
    {
        return self.standard_allocate_extended(byte_count, flags, 0, true);
    }

    pub fn standard_allocate_extended(self: *@This(), byte_count: u64, flags: Region.Flags, base_address: u64, commit_all: bool) u64
    {
        _ = self.reserve_mutex.acquire();
        defer self.reserve_mutex.release();

        if (self.reserve_extended(byte_count, flags.or_flag(.normal), base_address)) |region|
        {
            if (commit_all and !self.commit_range(region, 0, region.descriptor.page_count))
            {
                self.unreserve(region, false);
                return 0;
            }

            return region.descriptor.base_address;
        }
        else
        {
            return 0;
        }
    }

    fn commit_range(self: *@This(), region: *Region, page_offset: u64, page_count: u64) bool
    {
        self.reserve_mutex.assert_locked();
        
        if (region.flags.contains(.no_commit_tracking))
        {
            panic_raw("region does not support commit tracking");
        }

        if (page_offset >= region.descriptor.page_count or page_count > region.descriptor.page_count - page_offset)
        {
            panic_raw("invalid region offset and page count");
        }

        if (!region.flags.contains(.normal))
        {
            panic_raw("cannot commit into non-normal region");
        }

        var delta_s: i64 = 0;

        _ = region.data.u.normal.commit.set(page_offset, page_offset + page_count, &delta_s, false);

        if (delta_s < 0)
        {
            panic_raw("commit range invalid delta calculation");
        }
        
        const delta = @intCast(u64, delta_s);

        if (delta == 0) return true;

        {
            const commit_byte_count = delta * page_size;
            if (!kernel.physical_allocator.commit(commit_byte_count, region.flags.contains(.fixed))) return false;

            region.data.u.normal.commit_page_count += delta;
            self.commit_count += delta;

            if (region.data.u.normal.commit_page_count > region.descriptor.page_count)
            {
                panic_raw("invalid delta calculation increases region commit past page count");
            }
        }

        if (!region.data.u.normal.commit.set(page_offset, page_offset + page_count, null, true))
        {
            TODO();
        }

        if (region.flags.contains(.fixed))
        {
            var i: u64 = page_offset;
            while (i < page_offset + page_count) : (i += 1)
            {
                if (!self.handle_page_fault(region.descriptor.base_address + i * page_size, HandlePageFaultFlags.new_from_flag(.lock_acquired)))
                {
                    panic_raw("unable to fix pages\n");
                }
            }
        }

        return true;
    }
};


pub const PageFrame = struct
{
    state: Volatile(PageFrame.State),
    flags: Volatile(u8),
    cache_reference: VolatilePointer(u64),
    data: extern union
    {
        list: struct
        {
            next: Volatile(u64),
            previous: Volatile(?*u64),
        },

        active: struct
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

var early_zero_buffer: [page_size]u8 align(page_size) = undefined;

pub const Physical = struct
{
    pub const Allocator = struct
    {
        pageframes: []PageFrame,

        first_free_page: u64,
        first_zeroed_page: u64,
        first_standby_page: u64,
        last_standby_page: u64,

        free_or_zeroed_page_bitset: Bitset,

        zeroed_page_count: u64,
        free_page_count: u64,
        standby_page_count: u64,
        active_page_count: u64,

        commit_fixed: u64,
        commit_pageable: u64,
        commit_fixed_limit: u64,
        commit_limit: u64,

        commit_mutex: Mutex,
        pageframe_mutex: Mutex,

        manipulation_lock: Mutex,
        manipulation_processor_lock: Spinlock,
        manipulation_region: ?*Region,

        zero_page_thread: ?*Thread,
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

        pub fn allocate_with_flags(self: *@This(), flags: Physical.Flags) u64
        {
            return self.allocate_extended(flags, 1, 1, 0);
        }

        pub fn allocate_extended(self: *@This(), flags: Physical.Flags, count: u64, alignment: u64, below: u64) u64
        {
            const mutex_already_acquired = flags.contains(.lock_acquired);
            if (!mutex_already_acquired) _ = self.pageframe_mutex.acquire() else self.pageframe_mutex.assert_locked();
            defer if (!mutex_already_acquired) self.pageframe_mutex.release();

            const commit_now = blk:
            {
                if (flags.contains(.commit_now))
                {
                    const result = count * page_size;
                    if (!self.commit(result, true)) return 0;
                    break :blk result;
                }
                else
                {
                    break :blk 0;
                }
            };
            _ = commit_now;

            const simple = count == 1 and alignment == 1 and below == 0;

            if (self.pageframes.len == 0)
            {
                if (!simple)
                {
                    panic_raw("non-simple allocation before page frame initialization\n");
                }

                const page = kernel.arch.early_allocate_page();

                if (flags.contains(.zeroed))
                {
                    // @TODO: hack
                    _ = kernel.arch.map_page(&kernel.core.address_space, page, @ptrToInt(&early_zero_buffer), MapPageFlags.new(.{.overwrite, .no_new_tables, .frame_lock_acquired}));
                    std.mem.set(u8, early_zero_buffer[0..], 0);
                }

                return page;
            }
            else if (!simple)
            {
                TODO();
            }
            else
            {
                TODO();
            }
        }

        pub fn commit(self: *@This(), byte_count: u64, fixed: bool) bool
        {
            if (byte_count & (page_size - 1) != 0) panic_raw("expected multiple of page size\n");

            const needed_page_count = byte_count / page_size;

            _ = self.commit_mutex.acquire();
            defer self.commit_mutex.release();

            // If not true: we haven't started tracking commit counts yet
            if (self.commit_limit != 0)
            {
                if (fixed)
                {
                    if (needed_page_count > self.commit_fixed_limit - self.commit_fixed)
                    {
                        return false;
                    }

                    if (self.get_available_page_count() - needed_page_count < critical_available_page_threshold and !get_current_thread().?.is_page_generator)
                    {
                        return false;
                    }

                    self.commit_fixed += needed_page_count;
                }
                else
                {
                    if (needed_page_count > self.get_remaining_commit() - if (get_current_thread().?.is_page_generator) @as(u64, 0) else @as(u64, critical_remaining_commit_threshold))
                    {
                        return false;
                    }

                    self.commit_pageable += needed_page_count;
                }

                if (self.should_trim_object_cache())
                {
                    TODO();
                }
            }
        
            return true;
        }

        fn get_available_page_count(self: @This()) callconv(.Inline) u64
        {
            return self.zeroed_page_count + self.free_page_count + self.standby_page_count;
        }

        fn get_remaining_commit(self: @This()) callconv(.Inline) u64
        {
            return self.commit_limit - self.commit_pageable - self.commit_fixed;
        }

        fn should_trim_object_cache(self: @This()) callconv(.Inline) bool
        {
            return self.approximate_total_object_cache_byte_count / page_size > self.get_object_cache_maximum_cache_page_count();
        }

        fn get_object_cache_maximum_cache_page_count(self: @This()) callconv(.Inline) u64
        {
            return (self.commit_limit - self.get_non_cache_memory_page_count()) / 2;
        }

        fn get_non_cache_memory_page_count(self: @This()) callconv(.Inline) u64
        {
            return self.commit_fixed - self.commit_pageable - self.approximate_total_object_cache_byte_count / page_size;
        }

        const critical_available_page_threshold = 1048576 / page_size;
        const critical_remaining_commit_threshold = 1048576 / page_size;
    };

    pub const Flags = Bitflag(enum(u32)
        {
            can_fail = 0,
            commit_now = 1,
            zeroed = 2,
            lock_acquired = 3,
        });

    pub const memory_manipulation_region_page_count = 0x10;
};

pub const ObjectCache = struct
{
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
        if (self.region_list_reference == null or self.used != 0) panic_raw("heap panic\n");

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

pub const Heap = struct
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
        _ = zero_memory;
        _ = self;
        if (@bitCast(i64, asked_size) < 0) panic_raw("heap panic");

        const size = (asked_size + HeapRegion.used_header_size + 0x1f) & ~@as(u64, 0x1f);

        if (size >= large_allocation_threshold)
        {
            TODO();
        }

        _ = self.mutex.acquire();

        self.validate();

        const region = blk:
        {
            var heap_index = heap_calculate_index(size);
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

        if (region.used != 0 or region.u1.size < size) panic_raw("heap panic\n");

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

    fn allocateT(self: *@This(), comptime T: type, zero_memory: bool) callconv(.Inline) ?*T
    {
        return @intToPtr(?*T, self.allocate(@sizeOf(T), zero_memory));
    }

    fn add_free_region(self: *@This(), region: *HeapRegion) void
    {
        if (region.used != 0 or region.u1.size < 32)
        {
            panic_raw("heap panic\n");
        }

        const index = heap_calculate_index(region.u1.size);
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
        if (self == &kernel.core.heap)
        {
            return kernel.core.address_space.standard_allocate(size, Region.Flags.new_from_flag(.fixed));
        }
        else
        {
            return kernel.process.address_space.standard_allocate(size, Region.Flags.new_from_flag(.fixed));
        }
    }

    fn free_call(self: *@This(), region: *HeapRegion) void
    {
        if (self == &kernel.core.heap)
        {
            return kernel.core.address_space.free(@ptrToInt(region));
        }
        else
        {
            return kernel.process.address_space.free(@ptrToInt(region));
        }
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
                            panic_raw("heap panic\n");
                        }
                    }
                    else
                    {
                        if (region.previous != 0) panic_raw("heap panic\n");
                    }

                    if (region.u1.size & 31 != 0) panic_raw("heap panic");

                    if (@ptrToInt(region) - @ptrToInt(start) != region.offset)
                    {
                        panic_raw("heap panic\n");
                    }

                    if (region.used != HeapRegion.used_magic and region.used != 0)
                    {
                        panic_raw("heap panic");
                    }

                    if (region.used == 0 and region.region_list_reference == null)
                    {
                        panic_raw("heap panic\n");
                    }

                    if (region.used == 0 and region.u2.region_list_next != null and region.u2.region_list_next.?.region_list_reference != &region.u2.region_list_next)
                    {
                        panic_raw("heap panic");
                    }

                    maybe_previous = region;
                    region = region.get_next().?;
                }

                if (region != end)
                {
                    panic_raw("heap panic");
                }
            }
        }
    }

    // @TODO: this may be relying on C undefined behavior and might be causing different results than expected
    // @TODO: make this a zig function
    extern fn heap_calculate_index(size: u64) callconv(.C) u64;
    comptime
    {
        asm(
        \\.intel_syntax noprefix
        \\.global heap_calculate_index
        \\heap_calculate_index:
        \\bsr eax, edi
        \\xor eax, -32
        \\add eax, 33
        \\add rax, -5
        \\ret
        );
    }

    const large_allocation_threshold = 32768;
};

pub fn init() void
{
    // Initialize the core and the kernel address spaces
    {
        kernel.core.regions = @intToPtr([*]Region, kernel.Arch.core_memory_region_start)[0..1];
        var first_core_region = &kernel.core.regions[0];
        first_core_region.u.core.used = false;
        first_core_region.descriptor.base_address = kernel.Arch.core_address_space_start;
        first_core_region.descriptor.page_count = kernel.Arch.core_address_space_size / page_size;

        kernel.Arch.memory_init();
        const region = kernel.core.heap.allocateT(Region, true).?;
        region.descriptor.base_address = kernel_address_space_start;
        region.descriptor.page_count = kernel_address_space_size / page_size;
        _ = kernel.process.address_space.free_region_base.insert(&region.u.item.base, region, region.descriptor.base_address, .panic);
        _ = kernel.process.address_space.free_region_size.insert(&region.u.item.u.size, region, region.descriptor.page_count, .allow);
    }

    // Initialize the physical memory management
    {
        _ = kernel.process.address_space.reserve_mutex.acquire();
        kernel.physical_allocator.manipulation_region = kernel.process.address_space.reserve(Physical.memory_manipulation_region_page_count * page_size, Region.Flags.empty());
        kernel.process.address_space.reserve_mutex.release();

        const pageframe_count = (kernel.arch.physical_memory.highest + (page_size << 3)) >> page_bit_count;
        kernel.physical_allocator.pageframes.ptr = @intToPtr([*]PageFrame, kernel.process.address_space.standard_allocate(pageframe_count * @sizeOf(PageFrame), Region.Flags.new_from_flag(.fixed)));
        kernel.physical_allocator.free_or_zeroed_page_bitset.init(pageframe_count, true);
        kernel.physical_allocator.pageframes.len = pageframe_count;
        TODO();
    }

    TODO();
}
