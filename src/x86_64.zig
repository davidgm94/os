// Members of the arch-specific kernel structure
physical_memory: PhysicalMemory,
timestamp_ticks_per_ms: u64,
timestamp_counter_synchronization_value: Volatile(u64),

const kernel = @import("kernel.zig");

const SimpleList = kernel.SimpleList;
const TODO = kernel.TODO;
const panic_raw = kernel.panic_raw;
const sum_bytes = kernel.sum_bytes;
const Volatile = kernel.Volatile;

const memory = kernel.memory;

const Thread = kernel.Scheduler.Thread;

const Mutex = kernel.sync.Mutex;

const RootSystemDescriptorPointer = kernel.ACPI.RootSystemDescriptorPointer;

const std = @import("std");
const assert = std.debug.assert;
const zeroes = std.mem.zeroes;

pub const page_bit_count = 12;
pub const page_size = 0x1000;

pub const entry_per_page_table_count = 512;
pub const entry_per_page_table_bit_count = 9;

const unused_delay = Port(0x0080);

pub fn handle_page_fault(self: *@This(), fault_address: u64, flags: memory.HandlePageFaultFlags) bool
{
    _ = self;
    const virtual_address = fault_address & ~@as(u64, page_size - 1);
    const for_supervisor = flags.contains(.for_supervisor);

    if (!Interrupt.are_enabled())
    {
        kernel.panic_raw("Page fault with interrupts disabled\n");
    }

    const fault_in_very_low_memory = virtual_address < page_size;
    if (!fault_in_very_low_memory)
    {
        if (virtual_address >= low_memory_map_start and virtual_address < low_memory_map_start + low_memory_limit and for_supervisor)
        {
            const physical_address = virtual_address - low_memory_map_start;
            const map_page_flags = memory.MapPageFlags.from_flag(.commit_tables_now);
            _ = self.map_page(&kernel.process.address_space, physical_address, virtual_address, map_page_flags);
            return true;
        }
        else if (virtual_address >= core_memory_region_start and virtual_address < core_memory_region_start + core_memory_region_count * @sizeOf(memory.Region) and for_supervisor)
        {
            const physical_allocation_flags = memory.Physical.Flags.from_flag(.zeroed);
            const physical_address = kernel.physical_allocator.allocate_with_flags(physical_allocation_flags);
            const map_page_flags = memory.MapPageFlags.from_flag(.commit_tables_now);
            _ = self.map_page(&kernel.process.address_space, physical_address, virtual_address, map_page_flags);
            return true;
        }
        else if (virtual_address >= core_address_space_start and virtual_address < core_address_space_start + core_address_space_size and for_supervisor)
        {
            return kernel.core.address_space.handle_page_fault(virtual_address, flags);
        }
        else if (virtual_address >= kernel_address_space_start and virtual_address < kernel_address_space_start + kernel_address_space_size and for_supervisor)
        {
            return kernel.process.address_space.handle_page_fault(virtual_address, flags);
        }
        else if (virtual_address >= modules_start and virtual_address < modules_start + modules_size and for_supervisor)
        {
            return kernel.process.address_space.handle_page_fault(virtual_address, flags);
        }
        else
        {
            // @Unsafe
            if (get_current_thread()) |current_thread|
            {
                if (current_thread.temporary_address_space) |temporary_address_space| return @ptrCast(*memory.AddressSpace, temporary_address_space).handle_page_fault(virtual_address, flags)
                else return current_thread.process.?.address_space.handle_page_fault(virtual_address, flags);
            }
            else
            {
                panic_raw("unreachable path\n");
            }
        }
    }

    return false;
}

pub fn map_page(self: *@This(), space: *memory.AddressSpace, asked_physical_address: u64, asked_virtual_address: u64, flags: memory.MapPageFlags) bool
{
    // @TODO: look to refactor this?
    _ = self;
    // @TODO: use the no-execute bit

    if ((asked_virtual_address | asked_physical_address) & (page_size - 1) != 0)
    {
        kernel.panic_raw("Mapping pages that are not aligned\n");
    }

    if (kernel.physical_allocator.pageframes.len != 0 and (asked_physical_address >> page_bit_count) < kernel.physical_allocator.pageframes.len)
    {
        const frame_state = kernel.physical_allocator.pageframes[asked_physical_address >> page_bit_count].state.read_volatile();
        if (frame_state != .active and frame_state != .unusable)
        {
            kernel.panic_raw("Physical pageframe not marked as active or unusable\n");
        }
    }

    if (asked_physical_address == 0) kernel.panic_raw("Attempt to map physical page 0\n");
    if (asked_virtual_address == 0) kernel.panic_raw("Attempt to map virtual page 0\n");

    if (asked_virtual_address < 0xFFFF800000000000 and CR3.read() != space.arch.cr3)
    {
        kernel.panic_raw("Attempt to map page into another address space\n");
    }

    const acquire_framelock = !(flags.contains(.no_new_tables) and flags.contains(.frame_lock_acquired));
    if (acquire_framelock) _ = kernel.physical_allocator.pageframe_mutex.acquire();
    defer if (acquire_framelock) kernel.physical_allocator.pageframe_mutex.release();

    const acquire_spacelock = !flags.contains(.no_new_tables);
    if (acquire_spacelock) _ = space.arch.mutex.acquire();
    defer if (acquire_spacelock) space.arch.mutex.release();

    const physical_address = asked_physical_address & 0xFFFFFFFFFFFFF000;
    const virtual_address = asked_virtual_address & 0x0000FFFFFFFFF000;

    const indices = PageTables.compute_indices(virtual_address);

    if (space != &kernel.core.address_space and space != &kernel.process.address_space)
    {
        const index_L4 = indices[@enumToInt(PageTables.Level.level4)];
        if (space.arch.commit.L3[index_L4 >> 3] & (@as(u8, 1) << @truncate(u3, index_L4 & 0b111)) == 0) panic_raw("attempt to map using uncommited L3 page table\n");

        const index_L3 = indices[@enumToInt(PageTables.Level.level3)];
        if (space.arch.commit.L2[index_L3 >> 3] & (@as(u8, 1) << @truncate(u3, index_L3 & 0b111)) == 0) panic_raw("attempt to map using uncommited L3 page table\n");

        const index_L2 = indices[@enumToInt(PageTables.Level.level2)];
        if (space.arch.commit.L1[index_L2 >> 3] & (@as(u8, 1) << @truncate(u3, index_L2 & 0b111)) == 0) panic_raw("attempt to map using uncommited L3 page table\n");
    }

    space.arch.handle_missing_page_table(.level4, indices, flags);
    space.arch.handle_missing_page_table(.level3, indices, flags);
    space.arch.handle_missing_page_table(.level2, indices, flags);

    const old_value = PageTables.read(.level1, indices);
    var value = physical_address | 0b11;

    if (flags.contains(.write_combining)) value |= 16;
    if (flags.contains(.not_cacheable)) value |= 24;
    if (flags.contains(.user)) value |= 7 else value |= 1 << 8;
    if (flags.contains(.read_only)) value &= ~@as(u64, 2);
    if (flags.contains(.copied)) value |= 1 << 9;

    value |= (1 << 5);
    value |= (1 << 6);

    if (old_value & 1 != 0 and !flags.contains(.overwrite))
    {
        if (flags.contains(.ignore_if_mapped))
        {
            return false;
        }

        if (old_value & ~@as(u64, page_size - 1) != physical_address)
        {
            panic_raw("attempt to map page tha has already been mapped\n");
        }

        if (old_value == value)
        {
            panic_raw("attempt to rewrite page translation\n");
        }
        else
        {
            const page_become_writable = old_value & 2 == 0 and value & 2 != 0;
            if (!page_become_writable)
            {
                panic_raw("attempt to change flags mapping address\n");
            }
        }
    }

    PageTables.write(.level1, indices, value);

    invalidate_page(asked_virtual_address);

    return true;
}

pub fn translate_address(self: *@This(), virtual_address: u64, write_access: bool) u64
{
    // @TODO: refactor?
    _ = self;

    // TODO This mutex will be necessary if we ever remove page tables.
    // space->data.mutex.Acquire();
    // EsDefer(space->data.mutex.Release());

    const address = virtual_address & 0x0000FFFFFFFFF000;
    const indices = PageTables.compute_indices(address);
    if (PageTables.read(.level4, indices) & 1 == 0) return 0;
    if (PageTables.read(.level3, indices) & 1 == 0) return 0;
    if (PageTables.read(.level2, indices) & 1 == 0) return 0;

    const physical_address = PageTables.read(.level1, indices);

    if (write_access and physical_address & 2 == 0) return 0;
    if (physical_address & 1 == 0) return 0;
    return physical_address & 0x0000FFFFFFFFF000;
}

pub fn initialize_thread(kernel_stack: u64, kernel_stack_size: u64, thread: *Thread, start_address: u64, argument1: u64, argument2: u64, userland: bool, user_stack: u64, user_stack_size: u64) *Interrupt.Context
{
    const thread_kernel_stack = kernel_stack + kernel_stack_size - 8;
    const context = @intToPtr(*Interrupt.Context, thread_kernel_stack - @sizeOf(Interrupt.Context));
    thread.kernel_stack = thread_kernel_stack;

    // Terminate the thread when the outermost function exists
    @intToPtr(*u64, thread_kernel_stack).* = @ptrToInt(_thread_terminate);

    context.fx_save[32] = 0x80;
    context.fx_save[33] = 0x1f;

    if (userland)
    {
        context.cs = 0x5b;
        context.ds = 0x63;
        context.ss = 0x63;
    }
    else
    {
        context.cs = 0x48;
        context.ds = 0x50;
        context.ss = 0x50;
    }

    context._check = 0x123456789ABCDEF; // stack corruption detection
    context.flags = 1 << 9; // interrupt flag
    context.rip = start_address;
    context.rsp = user_stack + user_stack_size - 8;
    context.rdi = argument1;
    context.rsi = argument2;

    return context;
}

pub fn _thread_terminate() callconv(.Naked) noreturn
{
    asm volatile(
        \\.intel_syntax noprefix
        \\sub rsp, 8
        \\jmp thread_terminate
    );
    unreachable;
}

export fn thread_terminate() callconv(.C) void
{
    TODO();
}

pub const CPU = struct
{
    processor_ID: u8,
    kernel_processor_ID: u8,
    APIC_ID: u8,
    boot_processor: bool,
    kernel_stack: *align(1) u64,
    local_storage: *LocalStorage,
};

pub fn find_RSDP() u64
{
    const UEFI_RSDP = @intToPtr(*u64, low_memory_map_start + bootloader_information_offset + 0x7fe8).*;
    if (UEFI_RSDP != 0) return UEFI_RSDP;

    var search_regions: [2]memory.Region.Descriptor = undefined;
    search_regions[0].base_address = (@as(u64, @intToPtr([*]u16, low_memory_map_start)[0x40e]) << 4) + low_memory_map_start;
    search_regions[0].page_count = 0x400;
    search_regions[1].base_address = 0xe0000 + low_memory_map_start;
    search_regions[1].page_count = 0x20000;

    for (search_regions) |search_region|
    {
        var address = search_region.base_address;
        while (address < search_region.base_address + search_region.page_count) : (address += 16)
        {
            const rsdp = @intToPtr(*RootSystemDescriptorPointer, address);

            if (rsdp.signature != RootSystemDescriptorPointer.signature)
            {
                continue;
            }

            if (rsdp.revision == 0)
            {
                if (sum_bytes(@ptrCast([*]u8, rsdp)[0..20]) != 0) continue;

                return @ptrToInt(rsdp) - low_memory_map_start;
            }
            else if (rsdp.revision == 2)
            {
                if (sum_bytes(@ptrCast([*]u8, rsdp)[0..@sizeOf(RootSystemDescriptorPointer)]) != 0) continue;
                return @ptrToInt(rsdp) - low_memory_map_start;
            }
        }
    }

    return 0;
}

/// Architecture-specific memory initialization
pub fn memory_init() void
{
    const cr3 = CR3.read();
    kernel.core.address_space.arch.cr3 = cr3;
    kernel.process.address_space.arch.cr3 = cr3;

    var page_i: u64 = 0x100;
    while (page_i < 0x200) : (page_i += 1)
    {
        if (PageTables.read_at_index(.level4, page_i) == 0)
        {
            const physical_address = kernel.physical_allocator.allocate_with_flags(memory.Physical.Flags.empty());
            PageTables.write_at_index(.level4, page_i, physical_address | 0b11);
            const page = @intToPtr([*]u8, PageTables.take_address_of_element(.level3, page_i * 0x200))[0..page_size];
            std.mem.set(u8, page, 0);
        }
    }

    kernel.core.address_space.arch.commit.L1 = @ptrCast([*]u8, &AddressSpace.core_L1_commit);

    _ = kernel.core.address_space.reserve_mutex.acquire();
    defer kernel.core.address_space.reserve_mutex.release();
    const kernel_address_space_L1_flags = memory.Region.Flags.from_flags(.{ .normal, .no_commit_tracking, .fixed });
    const kernel_address_space_L1 = @intToPtr([*]u8, kernel.core.address_space.reserve(AddressSpace.L1_commit_size, kernel_address_space_L1_flags).?.descriptor.base_address);
    kernel.process.address_space.arch.commit.L1 = kernel_address_space_L1;
}


pub fn commit_page_tables(self: *@This(), space: *memory.AddressSpace, region: *memory.Region) bool
{
    // @TODO: refactor?
    _  = self;
    space.reserve_mutex.assert_locked();

    const base = (region.descriptor.base_address - @as(u64, if (space == &kernel.core.address_space) core_address_space_start else 0)) & 0x7FFFFFFFF000;
    const end = base + (region.descriptor.page_count << page_bit_count);
    var needed: u64 = 0;

    var i = base;
    while (i < end)
    {
        const shifter: u64 = page_bit_count + entry_per_page_table_bit_count * 3;
        const index = i >> shifter;
        const increment = space.arch.commit.L3[index >> 3] & (@as(u8, 1) << @truncate(u3, index & 0b111)) == 0;
        needed += @boolToInt(increment);
        i = (index << shifter) + (1 << shifter);
    }

    i = base;
    while (i < end)
    {
        const shifter: u64 = page_bit_count + entry_per_page_table_bit_count * 2;
        const index = i >> shifter;
        const increment = space.arch.commit.L2[index >> 3] & (@as(u8, 1) << @truncate(u3, index & 0b111)) == 0;
        needed += @boolToInt(increment);
        i = (index << shifter) + (1 << shifter);
    }

    var previous_index_l2i: u64 = std.math.maxInt(u64);
    i = base;
    while (i < end)
    {
        const shifter: u64 = page_bit_count + entry_per_page_table_bit_count;
        const index = i >> shifter;
        const index_l2i = index >> 15;

        if (space.arch.commit.commit_L1[index_l2i >> 3] & (@as(u8, 1) << @truncate(u3, index_l2i & 0b111)) == 0)
        {
            if (previous_index_l2i != index_l2i)
            {
                needed += 2;
            }
            else
            {
                needed += 1;
            }
        }
        else
        {
            const increment = space.arch.commit.L1[index >> 3] & (@as(u8, 1) << @truncate(u3, index & 0b111)) == 0;
            needed += @boolToInt(increment);
        }

        previous_index_l2i = index_l2i;
        i = index << shifter;
        i += 1 << shifter;
    }

    if (needed != 0)
    {
        if (!kernel.physical_allocator.commit(needed * page_size, true))
        {
            return false;
        }
        space.arch.commited_page_table_count += needed;
    }

    i = base;
    while (i < end)
    {
        const shifter: u64 = page_bit_count + entry_per_page_table_bit_count * 3;
        const index = i >> shifter;
        space.arch.commit.L3[index >> 3] |= @as(u8, 1) << @truncate(u3, index & 0b111);
        i = index << shifter;
        i += 1 << shifter;
    }

    i = base;
    while (i < end)
    {
        const shifter: u64 = page_bit_count + entry_per_page_table_bit_count * 2;
        const index = i >> shifter;
        space.arch.commit.L2[index >> 3] |= @as(u8, 1) << @truncate(u3, index & 0b111);
        i = index << shifter;
        i += 1 << shifter;
    }

    i = base;
    while (i < end)
    {
        const shifter: u64 = page_bit_count + entry_per_page_table_bit_count;
        const index = i >> shifter;
        const index_L2i = index >> 15;
        space.arch.commit.commit_L1[index_L2i >> 3] |= @as(u8, 1) << @truncate(u3, index_L2i & 0b111);
        space.arch.commit.L1[index >> 3] |= @as(u8, 1) << @truncate(u3, index & 0b111);
        i = index << shifter;
        i += 1 << shifter;
    }

    return true;
}

pub fn early_allocate_page(self: *@This()) u64
{
    const index = blk:
    {

        for (self.physical_memory.regions[self.physical_memory.region_index..]) |*region, region_i|
        {
            if (region.page_count != 0)
            {
                break :blk self.physical_memory.region_index + region_i;
            }
        }

        panic_raw("Unable to early allocate a page\n");
    };

    const region = &self.physical_memory.regions[index];
    const page = region.base_address;

    region.base_address += page_size;
    region.page_count -= 1;
    self.physical_memory.page_count -= 1;
    self.physical_memory.region_index = index;

    return page;
}

pub fn populate_pageframes(self: *@This()) u64
{
    var commit_limit: u64 = 0;

    for (self.physical_memory.regions) |region|
    {
        const base = region.base_address >> page_bit_count;
        const count = region.page_count;
        commit_limit += count;

        var page_i: u64 = 0;
        while (page_i < count) : (page_i += 1)
        {
            const page = base + page_i;
            kernel.physical_allocator.insert_free_pages_next(page);
        }
    }

    self.physical_memory.page_count = 0;
    return commit_limit;
}
pub fn unmap_pages(self: *@This(), space: *memory.AddressSpace, virtual_address_start: u64, page_count: u64, flags: memory.UnmapPagesFlags) void
{
    self.unmap_pages_extended(space, virtual_address_start, page_count, flags, 0, null);
}

pub fn unmap_pages_extended(self: *@This(), space: *memory.AddressSpace, virtual_address_start: u64, page_count: u64, flags: memory.UnmapPagesFlags, unmap_maximum: u64, resume_position: ?*u64) void
{
    // @TODO: refactor?
    _ = self;

    _ = kernel.physical_allocator.pageframe_mutex.acquire();
    defer kernel.physical_allocator.pageframe_mutex.release();

    _ = space.arch.mutex.acquire();
    defer space.arch.mutex.release();

    const table_base = virtual_address_start & 0x0000FFFFFFFFF000;
    const start = if (resume_position) |rp| rp.* else 0;

    var page = start;
    while (page < page_count) : (page += 1)
    {
        const virtual_address = table_base + (page << page_bit_count);
        const indices = PageTables.compute_indices(virtual_address);

        comptime var level: PageTables.Level = .level4;
        if (PageTables.read(level, indices) & 1 == 0)
        {
            page -= (virtual_address >> page_bit_count) % (1 << (entry_per_page_table_bit_count * @enumToInt(level)));
            page += 1 << (entry_per_page_table_bit_count * @enumToInt(level));
            continue;
        }

        level = .level3;
        if (PageTables.read(level, indices) & 1 == 0)
        {
            page -= (virtual_address >> page_bit_count) % (1 << (entry_per_page_table_bit_count * @enumToInt(level)));
            page += 1 << (entry_per_page_table_bit_count * @enumToInt(level));
            continue;
        }

        level = .level2;
        if (PageTables.read(level, indices) & 1 == 0)
        {
            page -= (virtual_address >> page_bit_count) % (1 << (entry_per_page_table_bit_count * @enumToInt(level)));
            page += 1 << (entry_per_page_table_bit_count * @enumToInt(level));
            continue;
        }

        const translation = PageTables.read(.level1, indices);

        if (translation & 1 == 0) continue; // the page wasnt mapped

        const copy = (translation & (1 << 9)) != 0;

        if (copy and flags.contains(.balance_file) and !flags.contains(.free_copied)) continue; // Ignore copied pages when balancing file mappings

        if ((~translation & (1 << 5) != 0) or (~translation & (1 << 6) != 0))
        {
            panic_raw("page found without accessed or dirty bit set");
        }

        PageTables.write(.level1, indices, 0);
        const physical_address = translation & 0x0000FFFFFFFFF000;

        if (flags.contains(.free) or (flags.contains(.free_copied) and copy))
        {
            kernel.physical_allocator.free_extended(physical_address, true, 1);
        }
        else if (flags.contains(.balance_file))
        {
            _ = unmap_maximum;
            TODO();
        }
    }

    invalidate_pages(virtual_address_start, page_count);
}

var get_time_from_PIT_ms_started = false;
var get_time_from_PIT_ms_cumulative: u64 = 0;
var get_time_from_PIT_ms_last: u64 = 0;
pub fn get_time_from_PIT_ms() u64
{
    // @TODO: this is not working on real hardware but early delay ms is?
    // askjdkjaskd
    //
    if (!get_time_from_PIT_ms_started)
    {
        TODO();
    }
    else
    {
        TODO();
    }
}

pub fn get_time_ms(self: *@This()) u64
{
    self.timestamp_counter_synchronization_value.write_volatile(((self.timestamp_counter_synchronization_value.read_volatile() & 0x8000000000000000) ^ 0x8000000000000000) | read_timestamp());
    if (kernel.acpi.HPET_base_address != null and kernel.acpi.HPET_period != 0)
    {
        const fs_to_ms = 1000000000000;
        const reading: u128 = @ptrToInt(kernel.acpi.HPET_base_address.?);
        return @intCast(u64, reading * kernel.acpi.HPET_period / fs_to_ms);
    }

    return get_time_from_PIT_ms();
}

pub fn invalidate_pages(virtual_address_start: u64, page_count: u64) void
{
    _ = virtual_address_start; _ = page_count;
}

pub fn invalidate_page(page: u64) callconv(.Inline) void
{
    asm volatile(
        \\invlpg (%[virtual_address])
        :
        : [virtual_address] "r" (page)
        : "memory"
    );
}

const PageTables = struct
{
    const levels = [4][*]volatile u64
    {
        @intToPtr([*]volatile u64, 0xFFFFFF0000000000),
        @intToPtr([*]volatile u64, 0xFFFFFF7F80000000),
        @intToPtr([*]volatile u64, 0xFFFFFF7FBFC00000),
        @intToPtr([*]volatile u64, 0xFFFFFF7FBFDFE000),
    };
    fn read(level: Level, indices: Indices) u64
    {
        return read_at_index(level, indices[@enumToInt(level)]);
    }

    fn read_at_index(level: Level, index: u64) u64
    {
        return levels[@enumToInt(level)][index];
    }

    fn write(level: Level, indices: Indices, value: u64) void
    {
        write_at_index(level, indices[@enumToInt(level)], value);
    }

    fn write_at_index(level: Level, index: u64, value: u64) void
    {
        levels[@enumToInt(level)][index] = value;
    }

    fn take_address_of_element(level: Level, index: u64) u64
    {
        return @ptrToInt(&levels[@enumToInt(level)][index]);
    }

    fn new(comptime address: u64) @This()
    {
        return @This()
        {
            .ptr = @intToPtr([*]volatile u64, address),
        };
    }

    const Indices = [PageTables.Level.count]u64;
    fn compute_indices(virtual_address: u64) callconv(.Inline) Indices
    {
        var indices: Indices = undefined;
        inline for (comptime std.enums.values(PageTables.Level)) |value|
        {
            indices[@enumToInt(value)] = virtual_address >> (page_bit_count + entry_per_page_table_bit_count * @enumToInt(value));
        }

        return indices;
    }
    const Level = enum(u8)
    {
        level1 = 0,
        level2 = 1,
        level3 = 2,
        level4 = 3,


        const count = std.enums.values(PageTables.Level).len;
    };
};

pub fn fake_timer_interrupt() callconv(.Inline) void
{
    asm volatile(
        \\.intel_syntax noprefix
        \\int 0x40
    );
}

/// Architecture-specific part of address space struct
pub const AddressSpace = struct
{
    cr3: u64,
    commit: struct
    {
        L1: [*]u8,
        commit_L1: [L1_commit_commit_size]u8,
        L2: [L2_commit_size]u8,
        L3: [L3_commit_size]u8,
    },
    commited_page_table_count: u64,
    active_page_table_count: u64,
    mutex: Mutex,

    const L1_commit_size = 1 << 23;
    const L1_commit_commit_size = 1 << 8;
    const L2_commit_size = 1 << 14;
    const L3_commit_size = 1 << 5;

    var core_L1_commit: [(0xFFFF800200000000 - 0xFFFF800100000000) >> (entry_per_page_table_bit_count + page_bit_count + 3)]u8 = undefined;

    fn handle_missing_page_table(self: *@This(), comptime level: PageTables.Level, indices: PageTables.Indices, flags: memory.MapPageFlags) callconv(.Inline) void
    {
        assert(level != .level1);

        if (PageTables.read(level, indices) & 1 == 0)
        {
            if (flags.contains(.no_new_tables)) panic_raw("no new tables flag set but a table was missing\n");

            const physical_allocation_flags = memory.Physical.Flags.from_flag(.lock_acquired);
            const physical_allocation = kernel.physical_allocator.allocate_with_flags(physical_allocation_flags) | 0b111;
            PageTables.write(level, indices, physical_allocation);
            const previous_level = @intToEnum(PageTables.Level, @enumToInt(level) - 1);

            const page = PageTables.take_address_of_element(previous_level, indices[@enumToInt(previous_level)]);
            invalidate_page(page);
            const page_slice = @intToPtr([*]u8, page & ~@as(u64, page_size - 1))[0..page_size];
            std.mem.set(u8, page_slice, 0);
            self.active_page_table_count += 1;
        }
    }
};


fn Port(comptime port: u16) type
{
    return struct
    {
        const Self = @This();

        fn read(comptime T: type) callconv(.Inline) T
        {
            return switch(T)
            {
                u8 => in8(port),
                u16 => in16(port),
                u32 => in32(port),
                else => @compileError("type not supported"),
            };
        }

        fn write(comptime T: type, value: T) callconv(.Inline) void
        {
            switch(T)
            {
                u8 => out8(port, value),
                u16 => out16(port, value),
                u32 => out32(port, value),
                else => @compileError("type not supported"),
            }
        }

        fn write_delayed(comptime T: type, value: T) callconv(.Inline) void
        {
            switch(T)
            {
                u8  => { out8(port, value);  _ = unused_delay.read(u8); },
                u16 => { out16(port, value); _ = unused_delay.read(u8); },
                u32 => { out32(port, value); _ = unused_delay.read(u8); },
                else => @compileError("type not supported"),
            }
        }
    };
}

fn in8(comptime port: u16) callconv(.Inline) u8
{
    return asm volatile(
        "inb %[port], %[result]"
        : [result] "={al}" (-> u8)
        : [port] "N{dx}" (port)
    );
}

fn out8(comptime port: u16, value: u8) callconv(.Inline) void
{
    asm volatile(
        "outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port]  "N{dx}" (port)
    );
}

fn in16(comptime port: u16) callconv(.Inline) u16
{
    _ = port;
    unreachable;
    //return asm volatile(
        //"inb %[port], %[result]"
        //: [result] "={al}" (-> u8)
        //: [port] "N{dx}" (port)
    //);
}

fn out16(comptime port: u16, value: u16) callconv(.Inline) void
{
    _ = port; _ = value;
    unreachable;
    //asm volatile(
        //"outb %[value], %[port]"
        //:
        //: [value] "{al}" (value),
          //[port]  "N{dx}" (port)
    //);
}

fn in32(comptime port: u16) callconv(.Inline) u32
{
    _ = port;
    unreachable;
    //return asm volatile(
        //"inb %[port], %[result]"
        //: [result] "={al}" (-> u8)
        //: [port] "N{dx}" (port)
    //);
}

fn out32(comptime port: u16, value: u32) callconv(.Inline) void
{
    _ = port; _ = value;
    unreachable;
    //asm volatile(
        //"outb %[value], %[port]"
        //:
        //: [value] "{al}" (value),
          //[port]  "N{dx}" (port)
    //);
}

const PIC1_command = Port(0x20);
const PIC1_data = Port(0x21);
const PIC2_command = Port(0xa0);
const PIC2_data = Port(0xa1);

export fn PIC_disable() callconv(.C) void
{
    PIC1_command.write_delayed(u8, 0x11);
    PIC2_command.write_delayed(u8, 0x11);
    PIC1_data.write_delayed(u8, 0x20);
    PIC2_data.write_delayed(u8, 0x28);
    PIC1_data.write_delayed(u8, 0x04);
    PIC2_data.write_delayed(u8, 0x02);
    PIC1_data.write_delayed(u8, 0x01);
    PIC2_data.write_delayed(u8, 0x01);

    PIC1_data.write_delayed(u8, 0xff);
    PIC2_data.write_delayed(u8, 0xff);
}

pub const PIT_data = Port(0x40);
pub const PIT_command = Port(0x43);

pub const core_memory_region_start = 0xFFFF8001F0000000;
pub const core_memory_region_count = (0xFFFF800200000000 - 0xFFFF8001F0000000) / @sizeOf(memory.Region);

pub const kernel_address_space_start = 0xFFFF900000000000;
pub const kernel_address_space_size = 0xFFFFF00000000000 - 0xFFFF900000000000;

pub const modules_start = 0xFFFFFFFF90000000;
pub const modules_size = 0xFFFFFFFFC0000000 - 0xFFFFFFFF90000000;

pub const core_address_space_start = 0xFFFF800100000000;
pub const core_address_space_size = 0xFFFF8001F0000000 - 0xFFFF800100000000;

pub const user_space_start = 0x100000000000;
pub const user_space_size = 0xF00000000000 - 0x100000000000;

pub const low_memory_map_start = 0xFFFFFE0000000000;
pub const low_memory_limit = 0x100000000; // The first 4GB is mapped here.

const idt_entry_count = 0x1000 / @sizeOf(IDTEntry);

export var _stack: [0x4000]u8 align(0x1000) linksection(".bss") = zeroes([0x4000]u8);
export var _idt_data: [idt_entry_count]IDTEntry align(0x1000) linksection(".bss") = zeroes([idt_entry_count]IDTEntry);
export var _cpu_local_storage: [0x2000]u8 align(0x1000) linksection(".bss") = zeroes([0x2000]u8);

const DescriptorTable = packed struct 
{
    limit: u16,
    base: u64,
};

const IDTEntry = packed struct
{
    foo1: u16,
    foo2: u16,
    foo3: u16,
    foo4: u16,
    masked_handler: u64,
};

comptime { assert(@sizeOf(IDTEntry) == 0x10); }

export var idt_descriptor: DescriptorTable linksection(".data") = undefined;
export var gdt_descriptor: u128 align(0x10) linksection(".data")  = undefined;
export var installation_ID: u128 linksection(".data") = 0;
export var bootloader_ID: u64 linksection(".data") = 0;
export var bootloader_information_offset: u64 linksection(".data") = 0;
export var _cpu_local_storage_index: u64 linksection(".data") = 0;
export var kernel_size: u32 linksection(".data") = 0;

export var pagingNXESupport: u32 linksection(".data") = 1;
export var pagingPCIDSupport: u32 linksection(".data") = 1;
export var pagingSMEPSupport: u32 linksection(".data") = 1;
export var pagingTCESupport: u32 linksection(".data") = 1;
export var simdSSE3Support: u32 linksection(".data") = 1;
export var simdSSSE3Support: u32 linksection(".data") = 1;

export var global_descriptor_table: GDT.WithDescriptor align(0x10) linksection(".data") = GDT.WithDescriptor
{
    .gdt = GDT
    {
        .null_entry = GDT.Entry.new(0, 0, 0, 0),
        .code_entry = GDT.Entry.new(0xffff, 0, 0xcf9a, 0),
        .data_entry = GDT.Entry.new(0xffff, 0, 0xcf92, 0),
        .code_entry16 = GDT.Entry.new(0xffff, 0, 0x0f9a, 0),
        .data_entry16 = GDT.Entry.new(0xffff, 0, 0x0f92, 0),
        .user_code = GDT.Entry.new(0xffff, 0, 0xcffa, 0),
        .user_data = GDT.Entry.new(0xffff, 0, 0xcff2, 0),
        .tss = TSS { .foo1 = 0x68, .foo2 = 0, .foo3 = 0xe9, .foo4 = 0, .foo5 = 0 },
        .code_entry64 = GDT.Entry.new(0xffff, 0, 0xaf9a, 0),
        .data_entry64 = GDT.Entry.new(0xffff, 0, 0xaf92, 0),
        .user_code64 = GDT.Entry.new(0xffff, 0, 0xaffa, 0),
        .user_data64 = GDT.Entry.new(0xffff, 0, 0xaff2, 0),
        .user_code64c = GDT.Entry.new(0xffff, 0, 0xaffa, 0),
    },
    .descriptor = GDT.Descriptor
    {
        .limit = @sizeOf(GDT) - 1,
        .base = 0x11000,
    },
};

export fn _start() callconv(.Naked) noreturn
{
    @setRuntimeSafety(false);
    asm volatile(
        \\.intel_syntax noprefix
        \\mov rax, OFFSET kernel_size
        \\mov [rax], edx
        \\xor rdx, rdx

        \\mov rax, 0x63
        \\mov fs, ax
        \\mov gs, ax

        \\// save bootloader id
        \\mov rax, OFFSET bootloader_ID
        \\mov [rax], rsi

        \\cmp rdi, 0
        \\jne .standard_acpi
        \\mov rax, 0x7fe8
        \\mov [rax], rdi
        \\.standard_acpi:

        \\mov rax, OFFSET bootloader_information_offset
        \\mov [rax], rdi

        // Stack size: 0x4000 
        \\mov rsp, OFFSET _stack + 0x4000
        \\
        \\mov rbx, OFFSET installation_ID
        \\mov rax, [rdi + 0x7ff0]
        \\mov [rbx], rax
        \\mov rax, [rdi + 0x7ff8]
        \\mov [rbx + 8], rax

        \\// unmap the identity paging the bootloader used
        \\mov rax, 0xFFFFFF7FBFDFE000
        \\mov qword ptr [rax], 0
        \\mov rax, cr3
        \\mov cr3, rax

        \\call PIC_disable
        \\call memory_region_setup
        \\call install_interrupt_handlers
        \\
        \\mov rcx, OFFSET gdt_descriptor
        \\sgdt [rcx]
        \\
        \\call CPU_setup_1
        \\
        \\and rsp, ~0xf
        \\call init

        \\jmp CPU_ready
    );
    unreachable;
}

export fn syscall_entry() callconv(.Naked) noreturn
{
    unreachable;
}

export fn CPU_setup_1() callconv(.Naked) void
{
    @setRuntimeSafety(false);
    asm volatile(
        \\.intel_syntax noprefix
        // Enable no-execute support, if available
\\mov eax, 0x80000001
\\cpuid
\\and edx,1 << 20
\\shr edx,20
\\mov rax, OFFSET pagingNXESupport
\\and [rax],edx
\\cmp edx,0
\\je .no_paging_nxe_support
\\mov ecx,0xC0000080
\\rdmsr
\\or eax,1 << 11
\\wrmsr
\\.no_paging_nxe_support:

// x87 FPU
\\fninit
\\mov rax, OFFSET .cw
\\fldcw [rax]
\\jmp .cwa
\\.cw: .short 0x037a
\\.cwa:

// Enable SMEP support, if available
// This prevents the kernel from executing userland pages
// TODO Test this: neither Bochs or Qemu seem to support it?
\\xor eax,eax
\\cpuid
\\cmp eax,7
\\jb .no_smep_support
\\mov eax,7
\\xor ecx,ecx
\\cpuid
\\and ebx,1 << 7
\\shr ebx,7
\\mov rax, OFFSET pagingSMEPSupport
\\and [rax],ebx
\\cmp ebx,0
\\je .no_smep_support
\\mov word ptr [rax],2
\\mov rax,cr4
\\or rax,1 << 20
\\mov cr4,rax
\\.no_smep_support:

// Enable PCID support, if available
\\mov eax,1
\\xor ecx,ecx
\\cpuid
\\and ecx,1 << 17
\\shr ecx,17
\\mov rax, OFFSET pagingPCIDSupport
\\and [rax],ecx
\\cmp ecx,0
\\je .no_pcid_support
\\mov rax,cr4
\\or rax,1 << 17
\\mov cr4,rax
\\.no_pcid_support:

// Enable global pages
\\mov rax,cr4
\\or rax,1 << 7
\\mov cr4,rax

// Enable TCE support, if available
\\mov eax,0x80000001
\\xor ecx,ecx
\\cpuid
\\and ecx,1 << 17
\\shr ecx,17
\\mov rax, OFFSET pagingTCESupport
\\and [rax],ecx
\\cmp ecx,0
\\je .no_tce_support
\\mov ecx,0xC0000080
\\rdmsr
\\or eax,1 << 15
\\wrmsr
\\.no_tce_support:

// Enable write protect, so copy-on-write works in the kernel, and MMArchSafeCopy will page fault in read-only regions.
\\mov rax,cr0
\\or rax,1 << 16
\\mov cr0,rax

// Enable MMX, SSE and SSE2
// These features are all guaranteed to be present on a x86_64 CPU
\\mov rax,cr0
\\mov rbx,cr4
\\and rax,~4
\\or rax,2
\\or rbx,512 + 1024
\\mov cr0,rax
\\mov cr4,rbx

// Detect SSE3 and SSSE3, if available.
\\mov eax,1
\\cpuid
\\test ecx,1 << 0
\\jnz .has_sse3
\\mov rax, OFFSET simdSSE3Support
\\and byte ptr [rax],0
\\.has_sse3:
\\test ecx,1 << 9
\\jnz .has_ssse3
\\mov rax, OFFSET simdSSSE3Support
\\and byte ptr [rax],0
\\.has_ssse3:

// Enable system-call extensions (SYSCALL and SYSRET).
\\mov ecx,0xC0000080
\\rdmsr
\\or eax,1
\\wrmsr
\\add ecx,1
\\rdmsr
\\mov edx,0x005B0048
\\wrmsr
\\add ecx,1
\\mov rdx, OFFSET syscall_entry
\\mov rax,rdx
\\shr rdx,32
\\wrmsr
\\add ecx,2
\\rdmsr
// Clear direction and interrupt flag when we enter ring 0.
\\mov eax,(1 << 10) | (1 << 9) 
\\wrmsr

// Assign PAT2 to WC.
\\mov ecx,0x277
\\xor rax,rax
\\xor rdx,rdx
\\rdmsr
\\and eax,0xFFF8FFFF
\\or eax,0x00010000
\\wrmsr

\\.setup_cpu_local_storage:
\\mov ecx,0xC0000101
\\mov rax, OFFSET _cpu_local_storage
\\mov rdx, OFFSET _cpu_local_storage
\\shr rdx,32
\\mov rdi, OFFSET _cpu_local_storage_index
\\add rax,[rdi]
// Space for 4 8-byte values at gs:0 - gs:31
\\add qword ptr [rdi],32 
\\wrmsr

\\.load_idtr:
// Load the IDTR
\\mov rax, OFFSET idt_descriptor
\\mov word ptr [rax], 0x1000
\\mov qword ptr [rax + 2], OFFSET _idt_data
\\lidt [rax]
\\sti

\\.enable_apic:
// Enable the APIC!
// Since we're on AMD64, we know that the APIC will be present.
\\mov ecx,0x1B
\\rdmsr
\\or eax,0x800
\\wrmsr
\\and eax,~0xFFF
\\mov edi,eax

// Set the spurious interrupt vector to 0xFF
// LOW_MEMORY_MAP_START + 0xF0
\\mov rax,0xFFFFFE00000000F0 
\\add rax,rdi
\\mov ebx,[rax]
\\or ebx,0x1FF
\\mov [rax],ebx

// Use the flat processor addressing model
// LOW_MEMORY_MAP_START + 0xE0
\\mov rax,0xFFFFFE00000000E0 
\\add rax,rdi
\\mov dword ptr [rax],0xFFFFFFFF

// Make sure that no external interrupts are masked
\\xor rax,rax
\\mov cr8,rax

\\ret
);

    unreachable;
}

pub fn next_timer(ms: u64) callconv(.C) void
{
    while (!kernel.scheduler.started.read_volatile()) {}
    LocalStorage.get().?.scheduler_ready = true;
    LAPIC.next_timer(ms);
}

export fn CPU_ready() callconv(.C) noreturn
{
    next_timer(1);
    asm volatile("jmp CPU_idle");
    unreachable;
}

export fn CPU_idle() callconv(.C) noreturn
{
    while (true)
    {
        asm volatile(
        \\sti
        \\hlt
        );
    }
}

pub export fn CPU_stop() callconv(.C) noreturn
{
    while (true)
    {
        asm volatile(
            \\cli
            \\hlt
        );
    }
}

export fn memory_region_setup() callconv(.C) void
{
    kernel.arch.physical_memory.setup();
}

export fn install_interrupt_handlers() callconv(.C) void
{
    comptime var interrupt_number: u64 = 0;
    inline while (interrupt_number < 256) : (interrupt_number += 1)
    {
        const has_error_code_pushed = comptime switch (interrupt_number)
        {
            8, 10, 11, 12, 13, 14, 17 => true,
            else => false,
        };
        var handler_address = @ptrToInt(InterruptHandler(interrupt_number, has_error_code_pushed).routine);

        _idt_data[interrupt_number].foo1 = @truncate(u16, handler_address);
        _idt_data[interrupt_number].foo2 = 0x48;
        _idt_data[interrupt_number].foo3 = 0x8e00;
        handler_address >>= 16;
        _idt_data[interrupt_number].foo4 = @truncate(u16, handler_address);
        handler_address >>= 16;
        _idt_data[interrupt_number].masked_handler = handler_address;
    }
}

pub export fn return_from_interrupt_handler() callconv(.Naked) void
{
    asm volatile(
        \\.intel_syntax noprefix
        \\add rsp, 8
        \\pop rbx
        \\mov ds, bx
        \\mov es, bx
        \\add rsp, 512 + 16
        \\mov rbx, rsp
        \\and rbx, ~0xf
        \\fxrstor [rbx - 512]
        \\
        \\cmp al, 0
        \\je .old_thread
        \\fninit
        \\.old_thread:
        \\
        \\pop rax
        \\mov rbx, 0x123456789ABCDEF
        \\cmp rax, rbx
        \\.loop:
        \\jne .loop
        \\
        \\cli
        \\pop rax
        \\mov cr8, rax
        \\pop r15
        \\pop r14
        \\pop r13
        \\pop r12
        \\pop r11
        \\pop r10
        \\pop r9
        \\pop r8
        \\pop rbp
        \\pop rdi
        \\pop rsi
        \\pop rdx
        \\pop rcx
        \\pop rbx
        \\pop rax
        \\
        \\add rsp, 16
        \\iretq
    );
    unreachable;
}

const interrupt_vector_MSI_start = 0x70;
const interrupt_vector_MSI_count = 0x40;
const interrupt_vector_MSI_end = interrupt_vector_MSI_start + interrupt_vector_MSI_count;

export fn interrupt_handler(context: *Interrupt.Context) callconv(.C) void
{
    if (kernel.scheduler.panic.read_volatile() and context.interrupt_number != 2) return;

    if (Interrupt.are_enabled())
    {
        kernel.panic_raw("Interrupts were enabled at the start of an interrupt handler\n");
    }

    const interrupt_number = context.interrupt_number;
    var maybe_local_storage = LocalStorage.get();
    // @TODO: @ERROR: @HERE Something is happening here
    if (maybe_local_storage) |local_storage|
    {
        if (local_storage.current_thread) |local_current_thread|
        {
            local_current_thread.last_interrupt_timestamp = read_timestamp();
        }

        if (local_storage.spinlock_count > 0 and context.cr8 != 0xe)
        {
            kernel.panic("local spinlock count {} but interrupts were enabled\n", .{local_storage.spinlock_count});
        }
    }

    switch (interrupt_number)
    {
        0x00...0x1f =>
        {
            if (interrupt_number == 2)
            {
                assert(maybe_local_storage != null);
                maybe_local_storage.?.panic_context = context;
                CPU_stop();
            }

            const supervisor = context.cs & 3 == 0;
            const maybe_current_thread = get_current_thread();
            _ = maybe_current_thread;

            if (!supervisor)
            {
                TODO();
            }
            else
            {
                if (context.cs != 0x48)
                    kernel.panic("unexpected value of CS: {}\n", .{context.cs});

                if (interrupt_number == 0xe)
                {
                    if (context.error_code & (1 << 3) != 0)
                    {
                        kernel.panic_raw("reserved write page fault: unreachable\n");
                    }

                    if (maybe_local_storage) |local_storage|
                    {
                        if (local_storage.spinlock_count != 0 and
                            ((context.cr2 >= 0xFFFF900000000000 and context.cr2 < 0xFFFFF00000000000) or context.cr2 < 0x8000000000000000))
                        {
                            kernel.panic_raw("Page fault occurred with spinlocks active\n");
                        }
                    }

                    if (context.flags & 0x200 != 0 and context.cr8 != 0xe)
                    {
                        Interrupt.enable();
                        maybe_local_storage = null;
                    }

                    if (!kernel.arch.handle_page_fault(context.cr2,
                            blk: {
                                var flags = memory.HandlePageFaultFlags.from_flags(.{.for_supervisor});
                                if (context.error_code & 2 != 0)
                                {
                                    flags = flags.or_flag(.write);
                                }

                                break :blk flags;
                            }))
                    {
                        if (maybe_current_thread) |current_thread|
                        {
                            if (current_thread.in_safe_copy and context.cr2 < 0x8000000000000000)
                            {
                                context.rip = context.r8;
                            }
                            else
                            {
                                panic_raw("unreachable\n");
                            }
                        }
                        else
                        {
                            panic_raw("unreachable path\n");
                        }
                    }

                    Interrupt.disable();
                }
                else
                {
                    kernel.panic("Interrupt is not a page fault: 0x{x}\n", .{interrupt_number});
                }
            }
        },
        0x20...0x2f =>
        {
            TODO();
        },
        0xf0...0xfd =>
        {
            TODO();
        },
        0xff =>
        {
            TODO();
        },
        interrupt_vector_MSI_start...interrupt_vector_MSI_end - 1 =>
        {
            if (maybe_local_storage) |_|
            {
                TODO();
            }
        },
        else =>
        {
            if (maybe_local_storage) |local|
            {
                local.IRQ_switch_thread = false;

                if (interrupt_number == timer_interrupt)
                {
                    local.IRQ_switch_thread = true;
                }
                else if (interrupt_number == yield_IPI)
                {
                    local.IRQ_switch_thread = true;
                    get_current_thread().?.received_yield_IPI.write_volatile(true);
                }
                else if (interrupt_number >= IRQ_base and interrupt_number < IRQ_base + 0x20)
                {
                    TODO();
                }

                if (local.IRQ_switch_thread and kernel.scheduler.started.read_volatile() and local.scheduler_ready)
                {
                    kernel.scheduler.yield(context);
                }
                else
                {
                    LAPIC.end_of_interrupt();
                }
            }
        },
    }

    context.sanity_check();

    if (Interrupt.are_enabled())
    {
        kernel.panic_raw("interrupts were enabled while returning from an interrupt handler\n");
    }
}

fn get_eflags() callconv(.Inline) u64
{
    return asm volatile(
        \\pushf
        \\pop %[flags]
        : [flags] "=r" (-> u64)
    );
}

fn ControlRegister(comptime cr: []const u8) type
{
    return struct
    {
        fn read() callconv(.Inline) u64
        {
            return asm volatile(
                "mov %%" ++ cr ++ ", %[out]"
                : [out] "=r" (-> u64)
            );
        }

        fn write(value: u64) callconv(.Inline) void
        {
            asm volatile ("mov %[in], %%" ++ cr
                :
                : [in] "r" (value)
            );
        }
    };
}

const CR0 = ControlRegister("cr0");
const CR1 = ControlRegister("cr1");
const CR2 = ControlRegister("cr2");
const CR3 = ControlRegister("cr3");
const CR4 = ControlRegister("cr4");
const CR5 = ControlRegister("cr5");
const CR6 = ControlRegister("cr6");
const CR7 = ControlRegister("cr7");
const CR8 = ControlRegister("cr8");


pub const LocalStorage = struct
{
    current_thread: ?*Thread,
    idle_thread: ?*Thread,
    async_task_thread: ?*Thread,
    panic_context: ?*Interrupt.Context,
    IRQ_switch_thread: bool,
    scheduler_ready: bool,
    in_IRQ: bool,
    in_async_task: bool,
    processor_ID: u32,
    spinlock_count: u64,
    cpu: ?*CPU,
    async_task_list: SimpleList,
    //
    pub fn get() callconv(.Inline) ?*@This()
    {
        return asm volatile(
                \\mov %%gs:0x0, %[out]
                : [out] "=r" (-> ?*@This())
        );
    }

    fn set(storage: *@This()) callconv(.Inline) void
    {
        asm volatile(
            \\mov %[in], %%gs:0x0
            :
            : [in] "r" (storage)
        );
    }
    //extern fn set(storage: *LocalStorage) callconv(.C) void;
    //comptime asm
};

pub fn get_current_thread() callconv(.Inline) ?*Thread
{
    return asm volatile(
                \\mov %%gs:0x10, %[out]
                : [out] "=r" (-> ?*Thread)
    );
}

fn set_current_thread(thread: *Thread) callconv(.Inline) void
{
    asm volatile(
            \\mov %[in], %%gs:0x10
            :
            : [in] "r" (thread)
    );
}

fn set_stack(stack: u64) callconv(.Inline) void
{
    asm volatile(
            \\mov %[in], %%gs:0x08
            :
            : [in] "r" (stack)
    );
}

pub fn read_timestamp() callconv(.Inline) u64
{
    var eax: u32 = undefined;
    var edx: u32 = undefined;
    asm volatile ("rdtsc"
        : [_] "={eax}" (eax),
          [_] "={edx}" (edx)
    );
    return @as(u64, eax) + (@as(u64, edx) << 32);
}

pub const Interrupt = struct
{
    pub const Context = extern struct
    {
        cr2: u64,
        ds: u64,
        fx_save: [512 + 16]u8,
        _check: u64,
        cr8: u64,
        r15: u64,
        r14: u64,
        r13: u64,
        r12: u64,
        r11: u64,
        r10: u64,
        r9: u64,
        r8: u64,
        rbp: u64,
        rdi: u64,
        rsi: u64,
        rdx: u64,
        rcx: u64,
        rbx: u64,
        rax: u64,
        interrupt_number: u64,
        error_code: u64,
        rip: u64,
        cs: u64,
        flags: u64,
        rsp: u64,
        ss: u64,

        fn sanity_check(self: *@This()) void
        {
            if (self.cs > 0x100 or
                self.ds > 0x100 or
                self.ss > 0x100 or
                (self.rip >= 0x1000000000000 and self.rip < 0xFFFF000000000000) or
                (self.rip < 0xFFFF800000000000 and self.cs == 0x48))
            {
                kernel.panic_raw("context sanity check failed\n");
            }
        }

    };

    pub fn enable() callconv(.Inline) void
    {
        // WARNING: Changing this mechanism also requires update in x86_64.cpp, when deciding if we should re-enable interrupts on exception.
        CR8.write(0);
        asm volatile("sti");
    }

    pub fn disable() callconv(.Inline) void
    {
        CR8.write(14); // Still allow important IPI to go through
        asm volatile("sti");
    }

    pub fn are_enabled() callconv(.Inline) bool
    {
        const eflags = get_eflags();
        const maybe_result = (eflags & 0x200) >> 9;
        const result =
            if (CR8.read() == 0) maybe_result
            else 0;
        return result != 0;
    }
};

fn InterruptHandler(comptime number: u64, comptime has_error_code: bool) type
{
    return struct
    {
        fn routine() callconv(.Naked) noreturn
        {
            @setRuntimeSafety(false);

            if (comptime !has_error_code)
            {
                asm volatile(
                \\.intel_syntax noprefix
                \\push 0
                );
            }

            asm volatile(
                ".intel_syntax noprefix\npush " ++ std.fmt.comptimePrint("{}", .{number})
                );

            asm volatile(
                \\.intel_syntax noprefix
                \\
                \\cld
                \\
                \\push rax
                \\push rbx
                \\push rcx
                \\push rdx
                \\push rsi
                \\push rdi
                \\push rbp
                \\push r8
                \\push r9
                \\push r10
                \\push r11
                \\push r12
                \\push r13
                \\push r14
                \\push r15
                \\
                \\mov rax, cr8
                \\push rax
                \\
                \\mov rax, 0x123456789ABCDEF
                \\push rax
                \\
                \\mov rbx, rsp
                \\and rsp, ~0xf
                \\fxsave [rsp - 512]
                \\mov rsp, rbx
                \\sub rsp, 512 + 16
                \\
                \\xor rax, rax
                \\mov ax, ds
                \\push rax
                \\mov ax, 0x10
                \\mov ds, ax
                \\mov es, ax
                \\mov rax, cr2
                \\push rax
                \\
                \\mov rdi, rsp
                \\mov rbx, rsp
                \\and rsp, ~0xf
                \\call interrupt_handler
                \\mov rsp, rbx
                \\xor rax, rax
                \\
                \\jmp return_from_interrupt_handler
            );

            unreachable;
        }
    };
}

pub const PhysicalMemory = struct
{
    regions: []PhysicalMemory.Region,
    page_count: u64,
    original_page_count: u64,
    region_index: u64,
    highest: u64,

    pub const Region = memory.Region.Descriptor;

    pub fn setup(self: *@This()) void
    {
        const physical_memory_region_ptr = @intToPtr([*]PhysicalMemory.Region, low_memory_map_start + 0x60000 + bootloader_information_offset);
        self.regions.ptr = physical_memory_region_ptr;

        var region_i: u64 = 0;
        while (physical_memory_region_ptr[region_i].base_address != 0) : (region_i += 1)
        {
            const region = &physical_memory_region_ptr[region_i];
            const end = region.base_address + (region.page_count << page_bit_count);
            self.page_count += region.page_count;
            if (end > self.highest) self.highest = end;
            self.regions.len += 1;
        }

        self.original_page_count = physical_memory_region_ptr[self.regions.len].page_count;
    }
};

const timer_interrupt = 0x40;
const yield_IPI = 0x41;
const IRQ_base = 0x50;

const LAPIC = struct
{
    fn read(register: u32) u32
    {
        return kernel.acpi.LAPIC_address[register];
    }

    fn write(register: u32, value: u32) void
    {
        kernel.acpi.LAPIC_address[register] = value;
    }

    fn next_timer(ms: u64) void
    {
        LAPIC.write(0x320 >> 2, timer_interrupt | (1 << 17));
        LAPIC.write(0x380 >> 2, @intCast(u32, kernel.acpi.LAPIC_ticks_per_ms * ms));
    }

    fn end_of_interrupt() void
    {
        LAPIC.write(0xb0 >> 2, 0);
    }
};

const NewProcessorStorage = extern struct
{
    local: *LocalStorage,
    gdt: u64,

    fn allocate(cpu: *CPU) @This()
    {
        var storage: @This() = undefined;
        storage.local = @intToPtr(*LocalStorage, kernel.core.fixed_heap.allocate(@sizeOf(LocalStorage), true));
        const gdt_physical_address = kernel.physical_allocator.allocate_with_flags(memory.Physical.Flags.from_flag(.commit_now));
        storage.gdt = kernel.process.address_space.map_physical(gdt_physical_address, page_size, memory.Region.Flags.empty());
        storage.local.cpu = cpu;
        cpu.local_storage = storage.local;
        kernel.scheduler.create_processor_threads(storage.local);
        cpu.kernel_processor_ID = @intCast(u8, storage.local.processor_ID);
        return storage;
    }
};
const GDT = packed struct
{
    null_entry: Entry,
    code_entry: Entry,
    data_entry: Entry,
    code_entry16: Entry,
    data_entry16: Entry,
    user_code: Entry,
    user_data: Entry,
    tss: TSS,
    code_entry64: Entry,
    data_entry64: Entry,
    user_code64: Entry,
    user_data64: Entry,
    user_code64c: Entry,

    const Entry = packed struct
    {
        foo1: u32,
        foo2: u8,
        foo3: u16,
        foo4: u8,

        fn new(foo1: u32, foo2: u8, foo3: u16, foo4: u8) @This()
        {
            return @This()
            {
                .foo1 = foo1,
                .foo2 = foo2,
                .foo3 = foo3,
                .foo4 = foo4,
            };
        }
    };

    const Descriptor = packed struct
    {
        limit: u16,
        base: u64,
    };

    const WithDescriptor = packed struct
    {
        gdt: GDT,
        descriptor: Descriptor,
    };

    fn load() callconv(.Inline) void
    {
        asm volatile(
            \\lgdt %[gdt_descriptor]
            :
            : [gdt_descriptor] "*gdt_descriptor" (&global_descriptor_table.descriptor)
        );
    }

    comptime
    {
        assert(@sizeOf(Entry) == 8);
        assert(@sizeOf(TSS) == 16);
        assert(@sizeOf(GDT) == @sizeOf(u64) * 14);
        assert(@sizeOf(Descriptor) == 10);
        assert(@offsetOf(GDT.WithDescriptor, "descriptor") == @sizeOf(GDT));
        // This is false
        //assert(@sizeOf(Complete) == @sizeOf(GDT) + @sizeOf(Descriptor));
    }
};

const TSS = packed struct
{
    foo1: u32,
    foo2: u8,
    foo3: u16,
    foo4: u8,
    foo5: u64,

    fn load(value: u16) callconv(.Inline) void
    {
        asm volatile(
            \\ltr %[ts_selector]
            :
            : [ts_selector] "r" (value)
        );
    }
};

//pub fn switch_context(
    //context: *Interrupt.Context, //rdi
    //arch_virtual_address_space: *AddressSpace, //rsi
    //thread_kernel_stack: u64, // rdx
    //new_thread: *Thread, // rcx
    //old_address_space: *memory.AddressSpace) // r8
    //callconv(.C) noreturn
//{
    //asm volatile("cli");
    //set_current_thread(new_thread);
    //set_stack(thread_kernel_stack);
    
    //if (arch_virtual_address_space.cr3 != CR3.read()) CR3.write(arch_virtual_address_space.cr3);
    //asm volatile("mov %[context], %%rsp"
        //:
        //: [context] "r" (context));

    //post_context_switch(context, old_address_space);

    //asm volatile("jmp return_from_interrupt_handler");
    //unreachable;
//}
pub extern fn switch_context(
    context: *Interrupt.Context, //rdi
    arch_virtual_address_space: *AddressSpace, //rsi
    thread_kernel_stack: u64, // rdx
    new_thread: *Thread, // rcx
    old_address_space: *memory.AddressSpace) // r8
    callconv(.C) noreturn;
comptime
{
    asm(
        \\.global switch_context
        \\switch_context:
        \\cli
        \\mov %rcx, %gs:0x10
        \\mov %rdx, %gs:0x08
        \\mov (%rsi), %rsi
        \\mov %cr3, %rax
        \\cmp %rsi, %rax
        \\je .cont
        \\mov %rsi, %cr3
        \\.cont:
        \\mov %rdi, %rsp
        \\mov %r8, %rsi
        \\call post_context_switch
        \\jmp return_from_interrupt_handler
    );
}

export fn post_context_switch(context: *Interrupt.Context, old_address_space: *memory.AddressSpace) callconv(.C) void
{
    //_ = post_context_switch(context, old_address_space);
    // @TODO: trying to inline the function. If not possible, come back here
    if (kernel.scheduler.dispatch_spinlock.interrupts_enabled.read_volatile()) panic_raw("interrupts were enabled");

    kernel.scheduler.dispatch_spinlock.release_ex(true);
    const current_thread = get_current_thread().?;
    const local = LocalStorage.get().?;
    local.cpu.?.kernel_stack.* = current_thread.kernel_stack;

    const is_new_thread = current_thread.cpu_time_slices.read_volatile() == 1;
    _ = is_new_thread;
    LAPIC.end_of_interrupt();
    context.sanity_check();
    set_thread_storage(current_thread.tls_address);
    old_address_space.close_reference();
    current_thread.last_known_execution_address = context.rip;
    if (Interrupt.are_enabled()) panic_raw("interrupts were enabled");

    if (local.spinlock_count != 0) panic_raw("spinlock_count not zero");

    current_thread.timer_adjust_ticks += read_timestamp() - local.current_thread.?.last_interrupt_timestamp;
    if (current_thread.timer_adjust_address != 0 and is_buffer_in_user_range(current_thread.timer_adjust_address, @sizeOf(u64)))
    {
        TODO();
    }
}

fn is_buffer_in_user_range(base_address: u64, byte_count: u64) bool
{
    if (base_address & 0xFFFF800000000000 != 0) return false;
    if (byte_count & 0xFFFF800000000000 != 0) return false;
    if ((base_address + byte_count) & 0xFFFF800000000000 != 0) return false;
    return true;
}
//comptime
//{
        //\\mov %rdi, %rsp
        //\\mov %r8, %rsi
        //\\call post_context_switch
        //\\jmp return_from_interrupt_handler
    //);
//}

//export fn post_context_switch(context: *Interrupt.Context, old_address_space: *memory.AddressSpace) callconv(.C) bool
//{
    //_ = context;
    //_ = old_address_space;
    //TODO();
//}
//

const IA32_EFER    = MSR(0xC0000080);
const IA32_STAR    = MSR(0xC0000081);
const IA32_LSTAR   = MSR(0xC0000082);
const IA32_FMASK   = MSR(0xC0000084);

const IA32_FS_BASE = MSR(0xC0000100);
const IA32_GS_BASE = MSR(0xC0000101);

fn MSR(comptime msr: u32) type
{
    return struct
    {
        pub fn read() callconv(.Inline) u64
        {
            var low: u32 = undefined;
            var high: u32 = undefined;
            asm volatile(
                "rdmsr"
                : [_] "={eax}" (low),
                  [_] "={edx}" (high),
                  [_] "={ecx}" (msr),
            );

            return (@as(u64, high) << 32) | @as(u64, low);
        }

        pub fn write(value: u64) callconv(.Inline) void
        {
            const low = @truncate(u32, value);
            const high = @truncate(u32, value >> 32);
            asm volatile(
                "wrmsr"
                :
                : [_] "{eax}" (low),
                  [_] "{edx}" (high),
                  [_] "{ecx}" (msr)
            );
        }
    };
}

fn set_thread_storage(tls: u64) callconv(.Inline) void
{
    IA32_GS_BASE.write(tls);
}

export fn setup_processor2(storage: *NewProcessorStorage) void
{
    // Setup the local interrupts for the current processor
    for (kernel.acpi.LAPIC_NMIs[0..kernel.acpi.LAPIC_NMI_count]) |nmi|
    {
        if (nmi.processor == 0xff or nmi.processor == storage.local.cpu.?.processor_ID)
        {
            const register_index = (0x350 + @as(u32, nmi.lint_index << 4)) >> 2;
            var value: u32 = 2 | (1 << 10);
            if (nmi.active_low) value |= 1 << 13;
            if (nmi.level_triggered) value |= 1 << 15;
            LAPIC.write(register_index, value);
        }
    }

    LAPIC.write(0x350 >> 2, LAPIC.read(0x350 >> 2) & ~@as(u32, 1 << 16));
    LAPIC.write(0x360 >> 2, LAPIC.read(0x360 >> 2) & ~@as(u32, 1 << 16));
    LAPIC.write(0x80 >> 2, 0);
    if (LAPIC.read(0x30 >> 2) & 0x80000000 != 0) LAPIC.write(0x410 >> 2, 0);
    LAPIC.end_of_interrupt();

    // Configure the LAPIC timer
    LAPIC.write(0x3e0 >> 2, 2);

    // Create the processor local storage
    LocalStorage.set(storage.local);

    // Setup a GDT and TSS for the processor
    const gdt = storage.gdt;
    const bootstrap_GDT = @intToPtr(*align(1) u64, (@ptrToInt(&gdt_descriptor) + @sizeOf(u16))).*;
    std.mem.copy(u8, @intToPtr([*]u8, gdt)[0..2048], @intToPtr([*]u8, bootstrap_GDT)[0..2048]);
    const tss = gdt + 2048;
    storage.local.cpu.?.kernel_stack = @intToPtr(*align(1) u64, tss + @sizeOf(u32));

    const offset = 56;
    const gdt_plus_offset = gdt + offset;
    var tss_it = tss;
    @intToPtr(*u16, gdt_plus_offset + 2).* = @truncate(u16, tss_it);
    tss_it >>= 16;
    @intToPtr(*u8, gdt_plus_offset + 4).* = @truncate(u8, tss_it);
    tss_it >>= 8;
    @intToPtr(*u8, gdt_plus_offset + 7).* = @truncate(u8, tss_it);
    tss_it >>= 8;
    @intToPtr(*u64, gdt_plus_offset + 8).* = tss_it;

    const old_base = global_descriptor_table.descriptor.base;
    global_descriptor_table.descriptor.base = gdt;
    GDT.load();
    global_descriptor_table.descriptor.base = old_base;
    TSS.load(0x38);
}

pub fn init() void
{
    kernel.acpi.parse_tables();
    const bootstrap_LAPIC_ID = @intCast(u8, LAPIC.read(0x20 >> 2) >> 24);
    
    const current_CPU = blk:
    {
        for (kernel.acpi.processors[0..kernel.acpi.processor_count]) |*processor|
        {
            if (processor.APIC_ID == bootstrap_LAPIC_ID)
            {
                processor.boot_processor = true;
                break :blk processor;
            }
        }

        panic_raw("could not find the bootstrap processor");
    };

    Interrupt.disable();
    const start = read_timestamp();
    LAPIC.write(0x380 >> 2, std.math.maxInt(u32));
    // Wait 8 ms
    {
        var i: u8 = 0;
        while (i < 8) : (i += 1)
        {
            PIT_command.write(u8, 0x30);
            PIT_data.write(u8, 0xa9);
            PIT_data.write(u8, 0x04);

            while (true)
            {
                PIT_command.write(u8, 0xe2);
                if (PIT_data.read(u8) & (1 << 7) != 0) break;
            }
        }
    }

    kernel.acpi.LAPIC_ticks_per_ms = (std.math.maxInt(u32) - LAPIC.read(0x390 >> 2)) >> 4;
    kernel.random_number_generator.add_entropy(LAPIC.read(0x390 >> 2));
    const end = read_timestamp();
    kernel.arch.timestamp_ticks_per_ms = (end - start) >> 3;
    Interrupt.enable();
    var processor_storage = NewProcessorStorage.allocate(current_CPU);
    setup_processor2(&processor_storage);
}
