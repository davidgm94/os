const std = @import("std");
const Kernel = @import("kernel.zig");

pub const low_memory_map_start = 0xFFFFFE0000000000;

pub const memory_map_core_space_start  = 0xFFFF800100000000;
pub const memory_map_core_space_size   = 0xFFFF800100000000 - 0xFFFF800100000000;
pub const memory_map_core_region_start = 0xFFFF8001F0000000;
pub const memory_map_core_region_count = (0xFFFF800200000000 - memory_map_core_region_start) / @sizeOf(Kernel.Memory.Region);

pub const memory_map_kernel_space_start = 0xFFFF900000000000;
pub const memory_map_kernel_space_size  = 0xFFFFF00000000000 - memory_map_kernel_space_start;

pub const memory_map_modules_start = 0xFFFFFFFF90000000;
pub const memory_map_modules_size  = 0xFFFFFFFFC0000000 - memory_map_modules_start;

pub const user_space_start = 0x100000000000;
pub const user_space_size = 0xF00000000000 - user_space_start;

pub const Page = struct
{
    pub const size = 0x1000;
    pub const bit_count = 12;

    fn get_base_address(address: u64) u64
    {
        return address & ~@as(u64, Page.size - 1);
    }

    const Table = struct
    {
        const PointerType = [*]volatile u64;

        const Level = enum(u8)
        {
            level_1 = 0,
            level_2 = 1,
            level_3 = 2,
            level_4 = 3,
        };

        const entry_count = 0x200;
        const entry_bit_count = 9;

        // @INFO: this is a workaround for bad Zig codegen which causes a page fault
        fn access(comptime level: Level, indices: [4]u64) *volatile u64
        {
            const page_table_level_base_address: u64 = switch (level)
            {
                .level_1 => 0xFFFFFF0000000000,
                .level_2 => 0xFFFFFF7F80000000,
                .level_3 => 0xFFFFFF7FBFC00000,
                .level_4 => 0xFFFFFF7FBFDFE000,
            };

            const index = indices[@enumToInt(level)];
            const element_pointer: u64 = page_table_level_base_address + (index * @sizeOf(u64));
            return @intToPtr(*volatile u64, element_pointer);
        }
    };

    pub const Fault = struct
    {
        const ErrorCodeBit = enum(u8)
        {
            present = 0,
            write = 1,
            user = 2,
            reserved_write = 3,
            instruction_fetch = 4,
            protection_key = 5,
            shadow_stack = 6,

            software_guard_extensions = 15,
        };


        const HandleError = error
        {
            LowMemoryError,
            CoreRegionError,
            CoreSpaceError,
            KernelSpaceError,
            ModuleSpaceError,
            UnknownError,
        };

        pub fn handle(fault_address: u64, flags: u32) HandleError!void
        {
            const address = fault_address & ~@as(u64, Page.size - 1);
            const for_supervisor = (flags & (1 << @enumToInt(Kernel.Memory.PageFault.Flags.for_supervisor))) != 0;

            if (!are_interrupts_enabled())
            {
                Kernel.panic(.page_fault_handle, "Page fault with interrupts disabled\n", .{});
            }

            const handle_fault_error: ?HandleError = blk:
            {
                if (address >= Page.size)
                {
                    if (address >= low_memory_map_start and address < low_memory_map_start + 0x100000000 and for_supervisor)
                    {
                        Page.map(&Kernel.kernel_memory_space, address - low_memory_map_start, address, 1 << @enumToInt(MapFlags.not_cacheable) | 1 << @enumToInt(MapFlags.commit_tables_now)) catch {};
                        break :blk null;
                    }
                    else if (address >= memory_map_core_region_start and address < memory_map_core_region_start + (memory_map_core_region_count * @sizeOf(Kernel.Memory.Region)) and for_supervisor)
                    {
                        const new_physical_address = Kernel.physical_memory_allocator.allocate_lockfree(@enumToInt(Kernel.Memory.Physical.Flags.zeroed), null, null, null);
                        Page.map(&Kernel.kernel_memory_space, new_physical_address, address, 1 << @enumToInt(MapFlags.commit_tables_now)) catch {};
                        break :blk null;
                    }
                    else if (address >= memory_map_core_space_start and address < memory_map_core_space_start + memory_map_core_space_size and for_supervisor)
                    {
                        Kernel.Memory.PageFault.handle(&Kernel.core_memory_space, address, flags) catch
                        {
                            break :blk HandleError.CoreSpaceError;
                        };

                        break :blk null;
                    }
                    else if (address >= memory_map_kernel_space_start and address < memory_map_kernel_space_start + memory_map_kernel_space_size and for_supervisor)
                    {
                        Kernel.Memory.PageFault.handle(&Kernel.kernel_memory_space, address, flags) catch
                        {
                            break :blk HandleError.KernelSpaceError;
                        };

                        break :blk null;
                    }
                    else if (address >= memory_map_modules_start and address < memory_map_modules_start + memory_map_modules_size and for_supervisor)
                    {
                        Kernel.Memory.PageFault.handle(&Kernel.kernel_memory_space, address, flags) catch
                        {
                            break :blk HandleError.ModuleSpaceError;
                        };

                        break :blk null;
                    }
                    else
                    {
                        const thread = thread_get_current();
                        var space = if (thread.temporary_address_space) |temporary_space| @ptrCast(*Kernel.Memory.Space, temporary_space) else thread.process.virtual_memory_space;
                        Kernel.Memory.PageFault.handle(space, address, flags) catch
                        {
                            break :blk HandleError.UnknownError;
                        };

                        break :blk null;
                    }
                }
                else
                {
                    break :blk HandleError.UnknownError;
                }
            };

            return handle_fault_error orelse return;
        }
    };

    pub const MapError = error
    {
        failed,
    };

    pub const MapFlags = enum(u8)
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
    };

    fn map_page_level_manipulation(memory_space: *Kernel.Memory.Space, comptime level: Page.Table.Level, indices: [4]u64, flags: u32) void
    {
        if (Page.Table.access(level, indices).* & 1 == 0)
        {
            if (flags & (1 << @enumToInt(MapFlags.no_new_tables)) != 0) CPU_stop();

            Page.Table.access(level, indices).* = Kernel.physical_memory_allocator.allocate_lockfree(1 << @enumToInt(Kernel.Memory.Physical.Flags.lock_acquired), null, null, null) | 0b111;
            const a_lower_level = comptime @intToEnum(Page.Table.Level, @enumToInt(level) - 1);
            const page_to_invalidate_address = @ptrToInt(Page.Table.access(a_lower_level, indices));
            invalidate_page(page_to_invalidate_address); // not strictly necessary
            std.mem.set(u8, @intToPtr([*]u8, page_to_invalidate_address & ~@as(u64, Page.size - 1))[0..Page.size], 0); 
            memory_space.virtual_address_space.active_page_table_count += 1;
        }
    }


    pub fn map(memory_space: *Kernel.Memory.Space, asked_physical_address: u64, asked_virtual_address: u64, flags: u32) MapError!void
    {
        if (asked_physical_address & (Page.size - 1) != 0)
        {
            CPU_stop();
        }

        // @TODO: page frames
        //
        // @Spinlock

        const cr3 = memory_space.virtual_address_space.cr3;

        if (!address_is_in_kernel_space(asked_virtual_address) and CR3_read() != cr3)
        {
            CPU_stop();
        }
        else if (asked_physical_address == 0)
        {
            CPU_stop();
        }
        else if (asked_virtual_address == 0)
        {
            CPU_stop();
        }
        else if (@ptrToInt(memory_space) != @ptrToInt(&Kernel.core_memory_space) and @ptrToInt(memory_space) != @ptrToInt(&Kernel.kernel_memory_space))
        {
            CPU_stop();
        }

        const physical_address = asked_physical_address & 0xFFFFFFFFFFFFF000;
        const virtual_address = asked_virtual_address & 0x0000FFFFFFFFF000;

        const indices = compute_page_table_indices(virtual_address);

        map_page_level_manipulation(memory_space, .level_4, indices, flags);
        map_page_level_manipulation(memory_space, .level_3, indices, flags);
        map_page_level_manipulation(memory_space, .level_2, indices, flags);

        //const L4_address: u64 = 0xFFFFFF7FBFDFE000 + index_l4 * 8;
        //if (Page.Table.access(.level_4, index_l4)* & 1 == 0)
        //{
            //if (flags & (1 << @enumToInt(MapFlags.no_new_tables)) != 0) CPU_stop();
            //Page.Table.access(.level_4, index_l4).* = Kernel.physical_memory_allocator.allocate_lockfree(@enumToInt(Kernel.Memory.Physical.Flags.lock_acquired), null, null, null) | 0b111;
            //const page_to_invalidate_address = @ptrToInt(&Page.Table.L3[index_l3]);
            //invalidate_page(page_to_invalidate_address); // not strictly necessary
            //std.mem.set(u8, @intToPtr([*]u8, page_to_invalidate_address & ~@as(u64, Page.size - 1))[0..Page.size], 0); 
            //memory_space.virtual_address_space.active_page_table_count += 1;
        //}

        //if (Page.Table.L3[index_l3] & 1 == 0)
        //{
            //if (flags & (1 << @enumToInt(MapFlags.no_new_tables)) != 0) CPU_stop();
            //Page.Table.L3[index_l3] = Kernel.physical_memory_allocator.allocate_lockfree(@enumToInt(Kernel.Memory.Physical.Flags.lock_acquired), null, null, null) | 0b111;
            //const page_to_invalidate_address = @ptrToInt(&Page.Table.L2[index_l2]);
            //invalidate_page(page_to_invalidate_address); // not strictly necessary
            //std.mem.set(u8, @intToPtr([*]u8, page_to_invalidate_address & ~@as(u64, Page.size - 1))[0..Page.size], 0); 
            //memory_space.virtual_address_space.active_page_table_count += 1;
        //}

        //if (Page.Table.L2[index_l2] & 1 == 0)
        //{
            //if (flags & (1 << @enumToInt(MapFlags.no_new_tables)) != 0) CPU_stop();
            //Page.Table.L2[index_l2] = Kernel.physical_memory_allocator.allocate_lockfree(@enumToInt(Kernel.Memory.Physical.Flags.lock_acquired), null, null, null) | 0b111;
            //const page_to_invalidate_address = @ptrToInt(&Page.Table.L1[index_l1]);
            //invalidate_page(page_to_invalidate_address); // not strictly necessary
            //std.mem.set(u8, @intToPtr([*]u8, page_to_invalidate_address & ~@as(u64, Page.size - 1))[0..Page.size], 0); 
            //memory_space.virtual_address_space.active_page_table_count += 1;
        //}

        const old_value = Page.Table.access(.level_1, indices).*;
        var value = physical_address | 0b11;

        if (flags & (1 << @enumToInt(MapFlags.write_combining)) != 0) value |= 16;
        if (flags & (1 << @enumToInt(MapFlags.not_cacheable)) != 0) value |= 24;
        if (flags & (1 << @enumToInt(MapFlags.user)) != 0)
        {
            value |= 7;
        }
        else
        {
            value |= 1 << 8; //global
        }
        if (flags & (1 << @enumToInt(MapFlags.read_only)) != 0) value &= ~@as(u64, 2);
        if (flags & (1 << @enumToInt(MapFlags.copied)) != 0) value |= 1 << 9;

        value |= (1 << 5) | (1 << 6);

        if (old_value & 1 != 0 and flags & (1 << @enumToInt(MapFlags.overwrite)) == 0)
        {
            CPU_stop();
        }

        Page.Table.access(.level_1, indices).* = value;

        invalidate_page(asked_virtual_address);
    }
};

pub fn address_is_in_kernel_space(address: u64) bool
{
    return address >= 0xFFFF800000000000;
}

pub const VirtualAddressSpace = struct
{
    cr3: u64,
    l1_commit: []u8,

    commited_page_table_count: u64,
    active_page_table_count: u64,

    pub fn init() void
    {
        var core_vas = &Kernel.core_memory_space.virtual_address_space; 
        core_vas.cr3 = CR3_read();
        Kernel.kernel_memory_space.virtual_address_space.cr3 = core_vas.cr3;
        core_vas.l1_commit = &core_L1_commit;


        CPU_stop();
        //var page_table_l4_i: u32 = 0x100;
        //while (page_table_l4_i < Page.Table.entry_count) : (page_table_l4_i += 1)
        //{
            //if (Page.Table.access(.level_4, page_table_l4_i).* == 0)
            //{
                //Page.Table.access(.level_4, page_table_l4_i).* = Kernel.physical_memory_allocator.allocate_lockfree(0, null, null, null) | 0b11;
                //var page_table_slice = @intToPtr([*]volatile u8, @ptrToInt(&Page.Table.L3[page_table_l4_i * 0x200]));
                //std.mem.set(u8, page_table_slice[0..Kernel.Arch.Page.size], 0);
            //}
        //}
    }

    const core_L1_commit_size = (0xFFFF800200000000 - 0xFFFF800100000000) >> (Page.Table.entry_bit_count + Page.bit_count + 3);
    var core_L1_commit: [core_L1_commit_size]u8 = undefined;
};

fn compute_page_table_indices(virtual_address: u64) [4]u64
{
    var indices: [4]u64 = undefined;
    indices[@enumToInt(Page.Table.Level.level_4)] = virtual_address >> (Page.bit_count + Page.Table.entry_bit_count * 3);
    indices[@enumToInt(Page.Table.Level.level_3)] = virtual_address >> (Page.bit_count + Page.Table.entry_bit_count * 2);
    indices[@enumToInt(Page.Table.Level.level_2)] = virtual_address >> (Page.bit_count + Page.Table.entry_bit_count * 1);
    indices[@enumToInt(Page.Table.Level.level_1)] = virtual_address >> (Page.bit_count + Page.Table.entry_bit_count * 0);

    return indices;
}

pub fn translate_address(asked_virtual_address: u64, write_access: bool) u64
{
    const virtual_address = asked_virtual_address & 0x0000FFFFFFFFF000;

    const indices = compute_page_table_indices(virtual_address);

    if (Page.Table.access(.level_4, indices).* & 1 == 0)
    {
        return 0;
    }
    if (Page.Table.access(.level_3, indices).* & 1 == 0)
    {
        return 0;
    }
    if (Page.Table.access(.level_2, indices).* & 1 == 0)
    {
        return 0;
    }

    const physical_address = Page.Table.access(.level_1, indices).*;

    if (write_access and (physical_address & 2) == 0) return 0;

    if ((physical_address & 1) == 0)
    {
        return 0; 
    }
    else
    {
        return physical_address & 0x0000FFFFFFFFF000;
    }
}

pub fn early_allocate_page() u64
{
    var physical_memory_regions = physical_memory_regions_get();
    const memory_region_count = physical_memory_regions.count;
    const memory_region_base = @ptrToInt(physical_memory_regions.ptr);
    const memory_region_index = physical_memory_regions.index;

    var region: *Kernel.Memory.PhysicalRegion = undefined;
    const region_index = blk:
    {
        const memory_region_slice = @intToPtr([*]Kernel.Memory.PhysicalRegion, memory_region_base + (memory_region_index * @sizeOf(Kernel.Memory.PhysicalRegion)))[0..memory_region_count];

        for (memory_region_slice) |*r, region_i|
        {
            if (r.page_count != 0)
            {
                region = r;
                break :blk memory_region_index + region_i;
            }
        }

        CPU_stop();
    };

    const page_base_address = region.base_address;
    region.base_address += Page.size;
    region.page_count -= 1;
    physical_memory_regions.count -= 1;
    physical_memory_regions.index = region_index;

    return page_base_address;
}

const InterruptContext = extern struct
{
    cr2: u64,
    ds: u64,
    fxsave: [512 + 16]u8,
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

    fn sanity_check(self: *InterruptContext) void
    {
        if (self.cs > 0x100 or self.ds > 0x100 or self.ss > 0x100 or (self.rip >= 0x1000000000000 and self.rip < 0xFFFF000000000000) or (self.rip < 0xFFFF800000000000 and self.cs == 0x48))
        {
            CPU_stop();
        }
    }
};

const Exception = enum(u64)
{
    divide_by_zero = 0x00,
    debug = 0x01,
    non_maskable_interrupt = 0x02,
    breakpoint = 0x03,
    overflow = 0x04,
    bound_range_exceeded = 0x05,
    invalid_opcode = 0x06,
    device_not_available = 0x07,
    double_fault = 0x08,
    coprocessor_segment_overrun = 0x09, // no
    invalid_TSS = 0x0a,
    segment_not_present = 0x0b,
    stack_segment_fault = 0x0c,
    general_protection_fault = 0x0d,
    page_fault = 0x0e,
    x87_floating_point_exception = 0x10,
    alignment_check = 0x11,
    machine_check = 0x12,
    simd_floating_point_exception = 0x13,
    virtualization_exception = 0x14,
    security_exception = 0x1e,
};

pub export fn interrupt_handler(context: *InterruptContext) callconv(.C) void
{
    var interrupts_enabled = are_interrupts_enabled();
    if (interrupts_enabled) CPU_stop();

    const interrupt = context.interrupt_number;

    const local_storage = get_local_storage();

    _ = local_storage;
    switch (interrupt)
    {
        0x0...0x19 =>
        {
            if (interrupt == 2)
            {
                CPU_stop();
            }

            const supervisor = (context.cs & 3) == 0;

            if (!supervisor)
            {
                if (context.cs != 0x5b and context.cs != 0x6b)
                {
                    Kernel.panic_lf(.interrupt_handler, "Unexpected value of CS: 0x{x}\n", .{context.cs});
                }

                const current_thread = thread_get_current();
                if (current_thread.is_kernel_thread)
                {
                    Kernel.panic_lf(.interrupt_handler, "Kernel thread executing user code\n", .{});
                }

                CPU_stop();
            }
            else
            {
                if (context.cs != 0x48)
                {
                    Kernel.panic_lf(.interrupt_handler, "Unexpected value of CS: {} 0x{x}\n", .{context.cs});
                }

                const exception = @intToEnum(Exception, interrupt);
                if (exception == .page_fault)
                {
                    if (context.error_code & (1 << @enumToInt(Page.Fault.ErrorCodeBit.reserved_write)) != 0)
                    {
                        unresolvable_exception();
                    }

                    if ((context.flags & 0x200) != 0 and context.cr8 != 0x0e)
                    {
                        enable_interrupts();
                    }

                    // @SpinLock condition kernel panic
                    const write_flag: u32 = 
                        if (context.error_code & @enumToInt(Page.Fault.ErrorCodeBit.write) != 0)
                            1 << @as(u32, @enumToInt(Kernel.Memory.PageFault.Flags.write))
                        else 0;

                    const handle_flags: u32 =
                        1 << @enumToInt(Kernel.Memory.PageFault.Flags.for_supervisor) |
                        write_flag;

                    Page.Fault.handle(context.cr2, handle_flags) catch
                    {
                        CPU_stop();
                    };
                
                    disable_interrupts();
                }
                else
                {
                    CPU_stop();
                }
            }
        },
        0x20...0x29 => { },
        0xff => { },
        else => CPU_stop(),
    }

    context.sanity_check();

    interrupts_enabled = are_interrupts_enabled();
    if (interrupts_enabled) CPU_stop();
}

fn unresolvable_exception() noreturn
{
    // @TODO: panic
    CPU_stop();
}

pub export fn syscall() callconv(.C) noreturn
{
    CPU_stop();
}

pub extern fn CPU_stop() callconv(.C) noreturn;
pub extern fn CR3_read() callconv(.C) u64;

pub extern fn thread_get_current() callconv(.C) *Kernel.Scheduler.Thread;
pub extern fn get_local_storage() callconv(.C) *Kernel.LocalStorage;

pub extern fn are_interrupts_enabled() callconv(.C) bool;
pub extern fn enable_interrupts() callconv(.C) void;
pub extern fn disable_interrupts() callconv(.C) void;

pub extern fn invalidate_page(page: u64) callconv(.C) void;
pub extern fn physical_memory_regions_get() callconv(.C) *Kernel.Memory.PhysicalRegions;
