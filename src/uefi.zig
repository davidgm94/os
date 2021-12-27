const std = @import("std");
const uefi = std.os.uefi;

const Stdout = struct
{
    const Self = @This();
    protocol: *uefi.protocols.SimpleTextOutputProtocol,

    fn write(self: *Self, message: []const u8) void
    {
        for (message) |u8_char|
        {
            const u16_char = [2]u16 { u8_char, 0 };
            _ = self.protocol.outputString(@ptrCast(*const [1:0]u16, &u16_char));
        }
    }
};

var stdout: Stdout = undefined;
var stdout_fmt_buffer: [0x1000]u8 = undefined;

fn print(comptime format: []const u8, args: anytype) void
{
    const formatted_u8_string = std.fmt.bufPrint(stdout_fmt_buffer[0..], format, args) catch unreachable;
    stdout.write(formatted_u8_string);
}

pub fn main() noreturn
{
    stdout = .{ .protocol = uefi.system_table.con_out.? };
    _ = stdout.protocol.clearScreen();
    stdout.write("UEFI hello world\r\n");

    cpu_stop();
}

pub fn cpu_stop() callconv(.Inline) noreturn
{
    @setRuntimeSafety(false);
    asm volatile(
        \\.intel_syntax noprefix
        \\.loop:
        \\cli
        \\hlt
        \\jmp .loop
    );
    unreachable;
}
