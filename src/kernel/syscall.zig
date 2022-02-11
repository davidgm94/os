const kernel = @import("kernel.zig");
const Volatile = kernel.Volatile;
const FatalError = kernel.FatalError;

const arch = kernel.arch;

const AddressSpace = kernel.memory.AddressSpace;

const object = kernel.object;

const scheduling = kernel.scheduling;
const Thread = scheduling.Thread;
const Process = scheduling.Process;


const std = @import("std");

pub const Function = fn (argument0: u64, argument1: u64, argument2: u64, argument3: u64, current_thread: *Thread, current_process: *Process, current_address_space: *AddressSpace, user_stack_pointer: ?*u64, fatal_error: *u8) callconv(.C) u64;

pub const Type = enum(u32)
{
    exit = 0,
    batch = 1,
    pub const count = std.enums.values(Type).len;
};

pub fn process_exit(argument0: u64, argument1: u64, argument2: u64, argument3: u64, current_thread: *Thread, current_process: *Process, current_address_space: *AddressSpace, user_stack_pointer: ?*u64, fatal_error: *u8) callconv(.C) u64
{
    _ = argument2;
    _ = argument3;
    _ = current_thread;
    _ = current_address_space;
    _ = user_stack_pointer;

    var self = false;

    {
        var process_out: kernel.object.Handle = undefined;
        const status = current_process.handle_table.resolve_handle(&process_out, argument0, @enumToInt(kernel.object.Type.process));
        if (status == .failed)
        {
            fatal_error.* = @enumToInt(FatalError.invalid_handle);
            return @boolToInt(true);
        }

        const process = @ptrCast(*Process, @alignCast(@alignOf(Process), process_out.object));
        defer if (status == .normal) object.close_handle(process, 0);
        if (process == current_process) self = true
        else scheduling.process_exit(process, @intCast(i32, argument1));
    }

    if (self) scheduling.process_exit(current_process, @intCast(i32, argument1));

    // @AIDS
    fatal_error.* = @bitCast(u8, @intCast(i8, kernel.ES_SUCCESS));
    return @boolToInt(false);
}
