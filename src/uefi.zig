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

fn panic(comptime format: []const u8, args: anytype) noreturn
{
    print("\r\nPANIC:\r\n\r\n" ++ format, args);
    cpu_stop();
}

var boot_services: *uefi.tables.BootServices = undefined;

fn efi_check(result: uefi.Status, comptime error_message: []const u8) void
{
    if (result != .Success)
    {
        panic("ERROR: {}. " ++ error_message, .{result});
    }
}


pub fn main() noreturn
{
    stdout = .{ .protocol = uefi.system_table.con_out.? };
    boot_services = uefi.system_table.boot_services.?;
    _ = stdout.protocol.clearScreen();
    stdout.write("UEFI hello world\r\n");

    // Make sure 0x100000 -> 0x300000 is identity mapped.
    {
        var address = @intToPtr([*]align(0x1000) u8, 0x100000);
        efi_check(boot_services.allocatePages(.AllocateAddress, .LoaderData, 0x200, &address), "Could not allocate 1MB->3MB\n");
    }

    const RSDP_entry_vendor_table: *anyopaque = blk:
    {
        const configuration_entries = uefi.system_table.configuration_table[0..uefi.system_table.number_of_table_entries]; 

        for (configuration_entries) |*entry|
        {
            if (entry.vendor_guid.eql(uefi.tables.ConfigurationTable.acpi_20_table_guid))
            {
                break :blk entry.vendor_table;
            }
        }

        panic("RSDP not found", .{});
    };
    _ = RSDP_entry_vendor_table;

    cpu_stop();
}

pub fn cpu_stop() callconv(.Inline) noreturn
{
    @setRuntimeSafety(false);
    while (true)
    {
        asm volatile(
        \\.intel_syntax noprefix
        \\cli
        \\hlt
        );
    }
    unreachable;
}
