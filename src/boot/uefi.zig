const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");
const string = std.unicode.utf8ToUtf16LeStringLiteral;
const UEFI = std.os.uefi;

var system_table: *UEFI.tables.SystemTable = undefined;
var boot_services: *UEFI.tables.BootServices = undefined;
var console: Console = undefined;

const platform = @import("../platform.zig");

const graphics_info_address     = 0x107000;
const RSDP_address              = 0x107fe8;
const installation_id_address   = 0x107ff0;
const identity_paging_tables    = 0x140000;
const memory_region_address     = 0x160000;
const uefi_loader_address       = 0x180000;
const kernel_paging_tables      = 0x1C0000;
const stack_down_address        = 0x200000;
const kernel_address            = 0x200000;

fn ok(src: std.builtin.SourceLocation, status: std.os.uefi.Status) void
{
    if (status != .Success)
    {
        report_error("UEFI error at {s}:{}:{}, {s}\nError code: {}\n", .{src.file, src.line, src.column, src.fn_name, status});
    }
}

var u8_stdout_buffer: [16 * 1024]u8 = undefined;
var u16_stdout_buffer: [8 * 1024]u16 = undefined;

var memory_map_buffer: [16 * 1024]u8 = undefined;

const MemoryRegion = extern struct
{
    base_address: u64,
    page_count: u64,

    const max_count = 1024;
};

var memory_regions: [MemoryRegion.max_count]MemoryRegion = undefined;
const page_size: u64 = 0x1000;
const page_bits = 12;
const entries_per_page_table = 512;
const entries_per_page_table_bits = 9;

const Console = struct
{
    con_out: *UEFI.protocols.SimpleTextOutputProtocol,

    fn log(self: Console, comptime u8_format: []const u8, arguments: anytype) void
    {
        const u8_message_formatted = std.fmt.bufPrint(u8_stdout_buffer[0..], u8_format, arguments) catch
        {
            //report_error("u8 format failed!", .{});
            platform.stop_cpu();
        };
        const length = std.unicode.utf8ToUtf16Le(u16_stdout_buffer[0..], u8_message_formatted) catch
        {
            //report_error("u8 to u16 string conversion failed!", .{});
            platform.stop_cpu();
        };

        u16_stdout_buffer[length] = 0;

        self.write_u16(@ptrCast([*:0]const u16, &u16_stdout_buffer));
    }

    fn write(self: Console, comptime u8_string: []const u8) void
    {
        const u16_string = comptime string(u8_string);
        self.write_u16(u16_string);
    }

    fn write_u16(self: Console, u16_string: [*:0]const u16) void
    {
        ok(@src(), self.con_out.outputString(u16_string));
    }
};

fn report_error(comptime format: []const u8, arguments: anytype) noreturn
{
    console.log(format, arguments);
    platform.stop_cpu();
}

const System = struct
{
    fn initialize() void
    {
        system_table = UEFI.system_table;
        boot_services = system_table.boot_services.?;

        console = Console
        {
            .con_out = system_table.con_out.?,
        };

        _ = console.con_out.reset(true);
    }
};

const VideoModeInformation = extern struct
{
    valid_edid_valid: u8,
    bits_per_pixel: u8,
    width: u16,
    height: u16,
    bytes_per_scanline_linear: u16,
    buffer_physical_address: u64,
    edid: [128]u8,
};

pub fn main() noreturn
{
    System.initialize();
    console.write("UEFI initialized\n");
    var base_address: u64 = 0x100000;
    ok(@src(), boot_services.allocatePages(.AllocateAddress, .LoaderData, 0x200, @ptrCast(*[*]align(0x1000) u8, &base_address)));
    console.write("Past allocation of initial pages\n");

    const table_entries = system_table.configuration_table[0..system_table.number_of_table_entries];
    var found = false;

    for (table_entries) |*table_entry|
    {
        if (UEFI.Guid.eql(table_entry.vendor_guid, UEFI.tables.ConfigurationTable.acpi_20_table_guid))
        {
            found = true;
            var rsdp_address = @intToPtr(*u64, RSDP_address);
            rsdp_address.* = @ptrToInt(table_entry.vendor_table);
        }
    }

    if (!found)
    {
        report_error("RSDP not found\n", .{});
    }

    console.write("RSDP found\n");

    //var loaded_image_protocol: ?*align(8) UEFI.protocols.LoadedImageProtocol = undefined;
    ////openProtocol: fn (Handle, *align(8) const Guid, *?*c_void, ?Handle, ?Handle, OpenProtocolAttributes) callconv(.C) Status,

    const kernel_buffer_size = 1048576;
    const kernel_buffer_address: u64 = 0x200000;

    {
        const sfs_handle = blk:
        {
            var handle_list_size: usize = 0;
            var handle_list: [*]UEFI.Handle = undefined;

            while (boot_services.locateHandle(.ByProtocol, &UEFI.protocols.SimpleFileSystemProtocol.guid, null, &handle_list_size, handle_list) == .BufferTooSmall)
            {
                ok(@src(), boot_services.allocatePool(.LoaderData, handle_list_size, @ptrCast(*[*] align(8) u8, &handle_list)));
            }


            const handle_count = handle_list_size / @sizeOf(UEFI.Handle);
            console.log("Handle count: {}\n", .{handle_count});
            //assert_eq(u64, handle_count, 1, @src());

            const handle = handle_list[0];
            break :blk handle;
        };

        const sfs_protocol = blk:
        {
            var protocol: *align(8) UEFI.protocols.SimpleFileSystemProtocol = undefined;
            ok(@src(), boot_services.openProtocol(sfs_handle, &UEFI.protocols.SimpleFileSystemProtocol.guid, @ptrCast(*?*c_void, &protocol), UEFI.handle, null, .{ .get_protocol = true }));
            break :blk protocol;
        };

        console.write("Simple file system protocol acquired\n");

        const filesystem_root = blk:
        {
            var fs_root: *UEFI.protocols.FileProtocol = undefined;
            ok(@src(), sfs_protocol.openVolume(&fs_root));
            break :blk fs_root;
        };

        console.write("Filesystem root acquired\n");

        const kernel_file_handle = blk:
        {
            var file_handle: *UEFI.protocols.FileProtocol = undefined;
            const filename = string("kernel.elf");

            ok(@src(), filesystem_root.open(&file_handle, filename, UEFI.protocols.FileProtocol.efi_file_mode_read, 0));

            break :blk file_handle;
        };

        console.write("Kernel file handle acquired\n");

        var size: u64 = kernel_buffer_size;

        ok(@src(), kernel_file_handle.read(&size, @intToPtr([*]u8, kernel_buffer_address)));
        console.log("Kernel size: {}\n", .{size});
        if (size == kernel_buffer_size) report_error("Kernel too large to fit into the buffer\n", .{});
        console.write("Kernel file read into memory\n");
        const kernel_buffer = @intToPtr([*]u8, kernel_buffer_address)[0..1000];
        for (kernel_buffer) |kernel_byte, i|
        {
            if (i % 10 == 0) console.log("\n{x}: ", .{i});
            console.log("0x{x:0>2} ", .{kernel_byte});
        }


        const loader_file_handle = blk:
        {
            var file_handle: *UEFI.protocols.FileProtocol = undefined;
            const filename = string("uefi_loader.bin");

            ok(@src(), filesystem_root.open(&file_handle, filename, UEFI.protocols.FileProtocol.efi_file_mode_read, 0));

            break :blk file_handle;
        };

        const loader_max_size = 0x80000;
        size = loader_max_size;

        ok(@src(), loader_file_handle.read(&size, @intToPtr([*]u8, uefi_loader_address)));
        console.log("Loader size: {}\n", .{size});
        if (size == loader_max_size) report_error("Loader too large to fit into the buffer\n", .{});
        console.write("Loader file read into memory\n");
        for (@intToPtr([*]u8, uefi_loader_address)[0..size]) |loader_byte, i|
        {
            if (i % 10 == 0) console.log("\n{x}: ", .{i});
            console.log("0x{x:0>2} ", .{loader_byte});
        }
    }

    const graphics_output_protocol = blk:
    {
        var gop: *UEFI.protocols.GraphicsOutputProtocol = undefined;
        ok(@src(), boot_services.locateProtocol(&UEFI.protocols.GraphicsOutputProtocol.guid, null, @ptrCast(*?*c_void, &gop))); 

        break :blk gop;
    };

    const horizontal_resolution = graphics_output_protocol.mode.info.horizontal_resolution;
    const vertical_resolution = graphics_output_protocol.mode.info.vertical_resolution;
    const pixels_per_scanline = graphics_output_protocol.mode.info.pixels_per_scan_line;
    const framebuffer = graphics_output_protocol.mode.frame_buffer_base;
    console.write("GOP located\n");
    console.log("GOP mode: {}\n", .{graphics_output_protocol.mode});

    {
        var paging = @intToPtr([*]u64, identity_paging_tables);
        const paging_array_size = 0x5000 / @sizeOf(u64);
        std.mem.set(u64, paging[0..paging_array_size], 0);

        paging[0x1fe] = 0x140003; // recursive
        paging[0x000] = 0x141003; // l4
        paging[0x200] = 0x142003; // l3
        paging[0x400] = 0x143003; // l2
        paging[0x401] = 0x144003;

        var i: u64 = 0;
        while (i < 0x400) : (i += 1)
        {
            paging[0x600 + i] = (i * 0x1000) | 3; // l1
        }
    }

    {
        var video_mode_information = @intToPtr(*VideoModeInformation, 0x107000);
        video_mode_information.width = @intCast(u16, horizontal_resolution);
        video_mode_information.height = @intCast(u16, vertical_resolution);
        video_mode_information.buffer_physical_address = framebuffer;
        video_mode_information.bytes_per_scanline_linear = @intCast(u16, pixels_per_scanline) * @sizeOf(u32);
        video_mode_information.bits_per_pixel = @bitSizeOf(u32);
        video_mode_information.valid_edid_valid = 1; // valid = 1, edid_valid = 0
    }

    var memory_region_count: u64 = 0;
    var map_key: u64 = 0;
    {
        var size: u64 = memory_map_buffer.len;
        var descriptor_size: u64 = undefined;
        var descriptor_version: u32 = undefined;
        ok(@src(), boot_services.getMemoryMap(&size, @ptrCast([*]UEFI.tables.MemoryDescriptor, &memory_map_buffer), &map_key, &descriptor_size, &descriptor_version));

        //console.write("Could get memory map\n");

        const efi_memory_region_count = size / descriptor_size;
        const max_memory_region_count = std.math.min(efi_memory_region_count, MemoryRegion.max_count - 1);

        const efi_memory_region_descriptors = @ptrCast([*]UEFI.tables.MemoryDescriptor, &memory_map_buffer)[0..max_memory_region_count];

        for (efi_memory_region_descriptors) |*descriptor|
        {
            if (descriptor.type == .ConventionalMemory and descriptor.physical_start >= 0x300000)
            {
                memory_regions[memory_region_count].base_address = descriptor.physical_start;
                memory_regions[memory_region_count].page_count = descriptor.number_of_pages;
                //console.log("{}\n", .{memory_regions[memory_region_count]});
                memory_region_count += 1;
            }
        }

        memory_regions[memory_region_count].base_address = 0;

        //console.log("Memory region count: {}\n", .{memory_region_count});
    }

    ok(@src(), boot_services.exitBootServices(UEFI.handle, map_key));

    {
        var next_page_table: u64 = kernel_paging_tables;
        var buffer = std.io.fixedBufferStream(@intToPtr([*]const u8, kernel_buffer_address)[0..kernel_buffer_size]);
        const elf_header = std.elf.Header.read(&buffer) catch platform.stop_cpu();
        var elf_ph_iterator = elf_header.program_header_iterator(&buffer);

        while (elf_ph_iterator.next() catch platform.stop_cpu()) |program_header|
        {
            if (program_header.p_type != std.elf.PT_LOAD) continue;

            const page_to_allocate_count = (program_header.p_memsz >> 12) + @boolToInt(program_header.p_memsz & 0xfff != 0);

            var physical_address: u64 = 0;

            for (memory_regions[0..memory_region_count]) |*memory_region|
            {
                if (memory_region.page_count >= page_to_allocate_count) 
                {
                    physical_address = memory_region.base_address;
                    memory_region.page_count -= page_to_allocate_count;
                    memory_region.base_address += page_to_allocate_count << 12;
                    break;
                }
            }

            if (physical_address == 0)
            {
                var fb = @intToPtr([*]u32, framebuffer)[0..100];
                fb[3] = 0xffff00ff;
                platform.stop_cpu();
            }

            var page_i: u64 = 0;
            while (page_i < page_to_allocate_count) :
                ({
                    page_i += 1;
                    physical_address += page_size;
                })
            {
                const virtual_address = (program_header.p_vaddr + page_i * page_size) & 0x0000FFFFFFFFF000;
                physical_address &= 0xFFFFFFFFFFFFF000;

                const index_l4 = (virtual_address >> (page_bits + entries_per_page_table_bits * 3)) & (entries_per_page_table - 1);
                const index_l3 = (virtual_address >> (page_bits + entries_per_page_table_bits * 2)) & (entries_per_page_table - 1);
                const index_l2 = (virtual_address >> (page_bits + entries_per_page_table_bits * 2)) & (entries_per_page_table - 1);
                const index_l1 = (virtual_address >> (page_bits + entries_per_page_table_bits * 1)) & (entries_per_page_table - 1);

                var table_l4 = @intToPtr([*]u64, 0x140000);

                if (table_l4[index_l4] & 1 == 0)
                {
                    table_l4[index_l4] = next_page_table | 0b111;
                    std.mem.set(u8, @intToPtr([*]u8, next_page_table)[0..page_size], 0);
                    next_page_table += page_size;
                }

                var table_l3 = @intToPtr([*]u64, (table_l4[index_l4] & ~(page_size - 1)));

                if (table_l3[index_l3] & 1 == 0)
                {
                    table_l3[index_l3] = next_page_table | 0b111;
                    std.mem.set(u8, @intToPtr([*]u8, next_page_table)[0..page_size], 0);
                    next_page_table += page_size;
                }

                var table_l2 = @intToPtr([*]u64, (table_l3[index_l3] & ~(page_size - 1)));

                if (table_l2[index_l2] & 1 == 0)
                {
                    table_l2[index_l2] = next_page_table | 0b111;
                    std.mem.set(u8, @intToPtr([*]u8, next_page_table)[0..page_size], 0);
                    next_page_table += page_size;
                }

                var table_l1 = @intToPtr([*]u64, (table_l2[index_l2] & ~(page_size - 1)));
                table_l1[index_l1] = physical_address | 0b11;
            }
        }
    }

    {
        var mapped_memory_regions = @intToPtr([*]MemoryRegion, memory_region_address)[0..memory_region_count + 1];
        std.mem.copy(MemoryRegion, mapped_memory_regions, memory_regions[0..memory_region_count + 1]);
    }


    {
        const loader_entry_point = @intToPtr(fn() void, uefi_loader_address);
        if (false) 
        {
            loader_entry_point();
        }
        else
        {
            uefi_loader_continuation();
        }
    }

    platform.stop_cpu();
}

fn uefi_loader_continuation() void
{
    gdt = GDT
    {
        .null_entry = std.mem.zeroes(GDT.Entry),
        .code_entry = std.mem.zeroInit(GDT.Entry, .
            {
                .dword = 0xffff,
                .half = 0xcf9a,
            }),
        .data_entry = std.mem.zeroInit(GDT.Entry, .
            {
                .dword = 0xffff,
                .half = 0xcf92,
            }),
        .code_entry_16 = std.mem.zeroInit(GDT.Entry, .
            {
                .dword = 0xffff,
                .half = 0x0f9a,
            }),
        .data_entry_16 = std.mem.zeroInit(GDT.Entry, .
            {
                .dword = 0xffff,
                .half = 0x0f92,
            }),
        .user_code = std.mem.zeroInit(GDT.Entry, .
            {
                .dword = 0xffff,
                .half = 0xcffa,
            }),
        .user_data = std.mem.zeroInit(GDT.Entry, .
            {
                .dword = 0xffff,
                .half = 0xcff2,
            }),
        .tss_dword0 = 0x68,
        .tss_byte0 = 0,
        .tss_half = 0xe9,
        .tss_byte1 = 0,
        .tss_qword = 0,
        .code_entry_64 = std.mem.zeroInit(GDT.Entry, .
            {
                .dword = 0xffff,
                .half = 0xaf9a,
            }),
        .data_entry_64 = std.mem.zeroInit(GDT.Entry, .
            {
                .dword = 0xffff,
                .half = 0xaf92,
            }),
        .user_code_64 = std.mem.zeroInit(GDT.Entry, .
            {
                .dword = 0xffff,
                .half = 0xaffa,
            }),
        .user_data_64 = std.mem.zeroInit(GDT.Entry, .
            {
                .dword = 0xffff,
                .half = 0xaff2,
            }),
        .user_code_64c = std.mem.zeroInit(GDT.Entry, .
            {
                .dword = 0xffff,
                .half = 0xaffa,
            }),
        .gdt_size = @offsetOf(GDT, "gdt_size") - 1,
        .gdt_pointer = @ptrToInt(&gdt), // will set later
    };
    asm volatile("lgdt (%[gdt])"
        :
        : [gdt] "r" (&gdt),
        : "memory"
    );
}


var gdt: GDT = undefined;

const TSS = packed struct
{
    dword0: u32,
    byte0: u8,
    half: u16,
    byte1: u8,
    qword: u64,
};

comptime
{
    assert(@sizeOf(GDT.Entry) == 8);
    assert(@sizeOf(TSS) == 16);
    assert(@sizeOf(GDT) == ((12 * @sizeOf(GDT.Entry)) + 16 + 10));
}

const GDT = packed struct
{
    null_entry: Entry,
    code_entry: Entry,
    data_entry: Entry,
    code_entry_16: Entry,
    data_entry_16: Entry,
    user_code: Entry,
    user_data: Entry,
    tss_dword0: u32,
    tss_byte0: u8,
    tss_half: u16,
    tss_byte1: u8,
    tss_qword: u64,
    code_entry_64: Entry,
    data_entry_64: Entry,
    user_code_64: Entry,
    user_data_64: Entry,
    user_code_64c: Entry,
    gdt_size: u16,
    gdt_pointer: u64,

    const Entry = packed struct
    {
        dword: u32,
        byte0: u8,
        half: u16,
        byte1: u8,
    };
};
