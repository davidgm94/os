const std = @import("std");
const Kernel = @import("kernel.zig");

const Memory = @This();

pub const Space = struct
{
    virtual_address_space: Kernel.Arch.VirtualAddressSpace,
    user: bool,
};

pub fn init() void
{
    Kernel.Arch.VirtualAddressSpace.init();
}

const critical_available_page_count_threshold = 0x100000 / Kernel.Arch.Page.size;

pub extern var physical_memory_regions: [*]PhysicalRegion;
pub extern var physical_memory_region_count: u64;
pub extern var physical_memory_region_page_count: u64;
pub extern var physical_memory_original_page_count: u64;
pub extern var physical_memory_region_index: u64;
pub extern var physical_memory_highest: u64;



pub var core_regions = @intToPtr([*]Memory.Region, Kernel.Arch.memory_map_core_region_start);
pub var core_region_count: u64 = 0;
pub var core_region_array_commit: u64 = 0;

pub const Region = struct
{
    base_address: u64,
    page_count: u64,
    flags: u32,

    const Flags = enum(u8)
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

    // TODO: (...)
};

pub const PhysicalRegion = struct
{
    base: u64,
    page_count: u64,
};

pub const Physical = struct
{

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

            if (physical_memory_region_page_count > 0)
            {
                if (!simple)
                {
                    Kernel.Arch.CPU_stop();
                }

                var index = physical_memory_region_index;
                var found = false;
                while (index < physical_memory_region_count) : (index += 1)
                {
                    found = physical_memory_regions[index].page_count > 0;
                    if (found) break;
                }

                if (!found) Kernel.Arch.CPU_stop();
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
                        const current_thread = Kernel.Arch.thread_get_current();
                        if (!current_thread.is_page_generator)
                        {
                            // fail
                            return CommitError.FixedCommitThresholdCrossed;
                        }
                    }

                    self.commit_fixed += page_count;
                }
                else
                {
                    const remaining_commit = self.get_remaining_commit();
                    const sub_value: u64 = if (Kernel.Arch.thread_get_current().is_page_generator) 0 else critical_available_page_count_threshold;

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
        const address = fault_address & (Kernel.Arch.Page.size - 1);

        // @TODO: @Spinlock
        const lock_acquired = fault_flags & @enumToInt(Flags.lock_acquired) != 0;
        if (!lock_acquired and Kernel.physical_memory_allocator.get_available_page_count() < critical_available_page_count_threshold and !Kernel.Arch.thread_get_current().is_page_generator)
        {
            Kernel.Arch.CPU_stop();
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
            Kernel.Arch.CPU_stop();
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

pub fn find_region(memory_space: *Memory.Space, address: u64) ?*Region
{
    _ = address;
    // @Spinlock
    //

    if (@ptrToInt(memory_space) == @ptrToInt(&Kernel.core_memory_space))
    {
        for (core_regions[0..core_region_count]) |*core_region|
        {
            _ = core_region;

            Kernel.Arch.CPU_stop();
        }
    }
    else
    {
        Kernel.Arch.CPU_stop();
    }

    return null;
}
