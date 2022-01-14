const kernel = @import("kernel.zig");

const TODO = kernel.TODO;
const panic_raw = kernel.panic_raw;

const Volatile = kernel.Volatile;
const VolatilePointer = kernel.VolatilePointer;

const Bitflag = kernel.Bitflag;
const AVLTree = kernel.AVLTree;
const LinkedList= kernel.LinkedList;
const Bitset = kernel.Bitset;
const RangeSet = kernel.RangeSet;

const Mutex = kernel.sync.Mutex;
const Spinlock = kernel.sync.Spinlock;
const Event = kernel.sync.Event;
const WriterLock = kernel.sync.WriterLock;

const Thread = kernel.Scheduler.Thread;
const Process = kernel.Scheduler.Process;

const page_size = kernel.Arch.page_size;
const fake_timer_interrupt = kernel.Arch.fake_timer_interrupt;

const std = @import("std");

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
                commit: RangeSet,
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
};

pub const AddressSpace = struct
{
    arch: kernel.Arch.AddressSpace,

    free_region_base: AVLTree(Region).Item,
    free_region_size: AVLTree(Region).Item,
    used_regions: AVLTree(Region).Item,
    used_regions_non_guard: LinkedList(Region),

    reserve_mutex: Mutex,

    reference_count: Volatile(i32),
    user: bool,
    commit_count: u64,
    reserve_count: u64,
    // async_task
    //
    pub fn handle_page_fault(self: *@This(), address: u64, flags: HandlePageFaultFlags) bool
    {
        _ = self;
        _ = address;
        _ = flags;
        TODO();
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
                        region.data = std.mem.zeroes(@TypeOf(region.data));

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
                TODO();
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

        fixed_commit: u64,
        pageable_commit: u64,
        fixed_limit_commit: u64,
        commit_limit: u64,

        commit_mutex: Mutex,
        pageframe_mutex: Mutex,

        manipulation_lock: Mutex,
        manipulation_processor_lock: Spinlock,
        manipulation_region: u64,

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
            _ = self; _ = byte_count; _ = fixed;
            TODO();
        }

    };

    pub const Flags = Bitflag(enum(u32)
        {
            can_fail = 0,
            commit_now = 1,
            zeroed = 2,
            lock_acquired = 3,
        });
};

pub const ObjectCache = struct
{
};

pub const Heap = struct
{
};

pub fn init() void
{
    kernel.core.regions = @intToPtr([*]Region, kernel.Arch.core_memory_region_start)[0..1];
    kernel.core.regions[0].u.core.used = false;
    kernel.core.regions[0].descriptor.base_address = kernel.Arch.core_address_space_start;
    kernel.core.regions[0].descriptor.page_count = kernel.Arch.core_address_space_size / page_size;

    kernel.Arch.memory_init();
}
