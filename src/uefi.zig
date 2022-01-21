const std = @import("std");
const uefi = std.os.uefi;
const assert = std.debug.assert;

const ELF = struct
{
    const Header = extern struct
    {
        magic: u32,
        bits: Bits,
        endianness: Endianness,
        version1: u8,
        abi: ABI,
        _unused: [8]u8,
        object_type: ObjectType,
        instruction_set: InstructionSet,
        object_file_format_version: u32,
        entry_point_virtual_address: u64,
        program_header_table_offset: u64,
        section_header_table_offset: u64,
        cpu_specific_flags: u32,
        file_header_size: u16,
        program_header_entry_size: u16,
        program_header_entry_count: u16,
        section_header_entry_size: u16,
        section_header_entry_count: u16,
        section_name_string_table_index: u16,

        const Bits = enum(u8)
        {
            @"32",
            @"64",
        };

        const Endianness = enum(u8)
        {
            little_endian = 1,
            big_endian = 2,
        };

        const ABI = enum(u8)
        {
            system_v = 0,
        };

        const ObjectType = enum(u16)
        {
            none = 0,
            relocatable = 1,
            executable = 2,
            shared = 3,
            core = 4,
        };

        const InstructionSet = enum(u16)
        {
            x86 = 0x03,
            ARM = 0x28,
            x86_64 = 0x3e,
            aarch64 = 0xb7,
        };
    };

    const ProgramHeader = extern struct
    {
        type: Type,
        flags: u32,
        offset_in_file: u64,
        virtual_address: u64,
        reserved: u64,
        size_in_file: u64,
        size_in_memory: u64,
        alignment: u64,

        const Type = enum(u32)
        {
            unused = 0,
            load = 1,
            dynamic = 2,
            interp = 3,
            note = 4,
        };

        const Flags = struct
        {
            const executable: u32 = 1 << 0;
            const writable: u32 = 1 << 1;
            const readable: u32 = 1 << 2;
        };
    };

    const SectionHeader = extern struct
    {
        section_name_offset: u32, // Relative to the start of the section name string table
        type: Type,
        flags: u64,
        virtual_address: u64,
        offset_in_file: u64,
        size: u64,
        link: u32,
        info: u32,
        alignment: u64,
        entry_size: u64,

        const Type = enum(u32)
        {
            unused = 0,
            program = 1,
            symbol_table = 2,
            string_table = 3,
            rela_relocation_entries = 4,
            symbol_hash_table = 5,
            dynamic_linking_table = 6,
            note = 7,
            no_bits = 8,
            rel_relocation_entries = 9,
            reserved = 10,
            dynamic_loader_symbol_table = 11,
        };

        const Flags = struct
        {
            const writable: u32 = 1 << 0;
            const allocated: u32 = 1 << 1;
            const executable_instructions: u32 = 1 << 2;
        };
    };
};

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

const MemoryRegion = extern struct
{
    base_address: u64,
    page_count: u64,
};

var boot_services: *uefi.tables.BootServices = undefined;
var memory_map_buffer: [0x4000]u8 = undefined;
var memory_regions: [1024]MemoryRegion = undefined;

fn efi_check(result: uefi.Status, comptime error_message: []const u8) void
{
    if (result != .Success)
    {
        panic("ERROR: {}. " ++ error_message, .{result});
    }
}

const ProvisionalVideoInformation = struct
{
    framebuffer: u64,
    horizontal_resolution: u32,
    vertical_resolution: u32,
    pixels_per_scan_line: u32,
};

const VideoModeInformation = extern struct
{
    valid_edid_valid: u8,
    bits_per_pixel: u8,
    width: u16,
    height: u16,
    bytes_per_scanline: u16,
    physical_buffer_address: u64,
    edid: [128]u8,
};

const page_size = 0x1000;
const page_bit_count = 12;
const entry_per_page_table_count = 512;
const entry_per_page_table_bit_count = 9;

const GDT = extern struct
{
    null_entry: u64,
    code_entry: u64,
    data_entry: u64,
    code_entry_16: u64,
    data_entry_16: u64,
    user_code: u64,
    user_data: u64,
    tss1: u64,
    tss2: u64,
    code_entry_64: u64,
    data_entry_64: u64,
    user_code_64: u64,
    user_data_64: u64,
    user_code_64c: u64,

    comptime { assert(@sizeOf(GDT) == 14 * @sizeOf(u64)); }

    const Entry = packed struct
    {
        foo1: u32,
        foo2: u8,
        foo3: u16,
        foo4: u8,

        comptime { assert(@sizeOf(Entry) == @sizeOf(u64)); }

        fn new(foo1: u32, foo2: u8, foo3: u16, foo4: u8) u64
        {
            const entry = Entry
            {
                .foo1 = foo1,
                .foo2 = foo2,
                .foo3 = foo3,
                .foo4 = foo4,
            };

            return @ptrCast(*align(1) const u64, &entry).*;
        }
    };

    const Descriptor = packed struct
    {
        limit: u16,
        base: u64,

        comptime { assert(@sizeOf(Descriptor) == @sizeOf(u16) + @sizeOf(u64)); }
    };

};

const uefi_asm_address = 0x180000;

const fault_address = 0xffffffff800d9000;
fn in_range(ph: *ELF.ProgramHeader) bool
{
    return _in_range(ph.virtual_address, ph.size_in_memory);
}

fn _in_range(va: u64, size: u64) bool
{
    return va <= fault_address and va + size >= fault_address;
}

//fn page_range(va: u64) bool
//{
    //return va 
//}

var kernel_pages: [0x10000]u64 = undefined;
var kernel_page_count: u64 = 0;

var kernel_program_headers: [0x100]u64 = undefined;
var kernel_program_header_count: u64 = 0;

pub fn main() noreturn
{
    stdout = .{ .protocol = uefi.system_table.con_out.? };
    boot_services = uefi.system_table.boot_services.?;
    _ = stdout.protocol.clearScreen();
    stdout.write("UEFI hello world\r\n");

    // Make sure 0x100000 -> 0x300000 is identity mapped.
    // @TODO: we can have problems with this
    const base_address   = 0x100000;
    const kernel_address = 0x200000;
    const page_count = 0x200;

    {
        var address = @intToPtr([*]align(page_size) u8, base_address);
        efi_check(boot_services.allocatePages(.AllocateAddress, .LoaderData, page_count, &address), "Could not allocate 1MB->3MB\n");
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

    {
        const loaded_image_protocol = blk:
        {
            const loaded_image_protocol_guid = uefi.protocols.LoadedImageProtocol.guid;
            var ptr: ?*anyopaque = undefined;
            efi_check(boot_services.openProtocol(uefi.handle, @ptrCast(*align(8) const uefi.Guid, &loaded_image_protocol_guid), &ptr, uefi.handle, null, .{ .get_protocol = true }),
                "Could not open protocol (1)");
            break :blk @ptrCast(*align(1) uefi.protocols.LoadedImageProtocol, ptr.?);
        };

        const simple_filesystem_protocol = blk:
        {
            const simple_fs_protocol_guid = uefi.protocols.SimpleFileSystemProtocol.guid;
            var ptr: ?*uefi.protocols.SimpleFileSystemProtocol = undefined;
            efi_check(boot_services.openProtocol(loaded_image_protocol.device_handle.?, @ptrCast(*align(8) const uefi.Guid, &simple_fs_protocol_guid), @ptrCast(*?*anyopaque, &ptr), uefi.handle, null, .{ .get_protocol = true }),
                "Could not open protocol (2)");
            break :blk ptr.?;
        };

        const filesystem_root = blk:
        {
            var file_protocol: *const uefi.protocols.FileProtocol = undefined;
            efi_check(simple_filesystem_protocol.openVolume(&file_protocol),
                "Could not open ESP volume");
            break :blk file_protocol;
        };

        {
            const kernel_file = blk:
            {
                var file: *uefi.protocols.FileProtocol = undefined;
                efi_check(filesystem_root.open(&file, std.unicode.utf8ToUtf16LeStringLiteral("zig-kernel.elf"), uefi.protocols.FileProtocol.efi_file_mode_read, 0),
                    "Can't open kernel");
                break :blk file;
            };
            const max_kernel_size = (page_count * page_size) + (kernel_address - base_address);
            var kernel_size: usize = max_kernel_size;
            efi_check(kernel_file.read(&kernel_size, @intToPtr([*]u8, kernel_address)),
                "Can't read kernel file");

            if (kernel_size == max_kernel_size)
            {
                panic("Kernel too large\n", .{});
            }
        }

        {
            const uefi_asm_file = blk:
            {
                var file: *uefi.protocols.FileProtocol = undefined;
                efi_check(filesystem_root.open(&file, std.unicode.utf8ToUtf16LeStringLiteral("uefi_asm.bin"), uefi.protocols.FileProtocol.efi_file_mode_read, 0),
                    "Can't open UEFI asm binary");
                break :blk file;
            };
            var size: usize = 0x80000;
            efi_check(uefi_asm_file.read(&size, @intToPtr([*]u8, uefi_asm_address)),
                "Can't read UEFI asm binary file");
        }
    }

    const provisional_video_information = blk:
    {
        var gop: *uefi.protocols.GraphicsOutputProtocol = undefined;
        const gop_guid = uefi.protocols.GraphicsOutputProtocol.guid;

        efi_check(boot_services.locateProtocol(@ptrCast(*align(8) const uefi.Guid, &gop_guid), null, @ptrCast(*?*anyopaque, &gop)),
            "Failed to locate GOP\n");


        break :blk ProvisionalVideoInformation
        {
            .framebuffer = gop.mode.frame_buffer_base,
            .horizontal_resolution = gop.mode.info.horizontal_resolution,
            .vertical_resolution = gop.mode.info.vertical_resolution,
            .pixels_per_scan_line = gop.mode.info.pixels_per_scan_line,
        };
    };
    _ = provisional_video_information;

    {
        var map_key: usize = 0;
        var size: usize = memory_map_buffer.len;
        var descriptor_size: usize = 0;
        var descriptor_version: u32 = 0;
        efi_check(boot_services.getMemoryMap(&size, @intToPtr([*]uefi.tables.MemoryDescriptor, @ptrToInt(&memory_map_buffer)),  &map_key, &descriptor_size, &descriptor_version),
            "Failed to get memory map\n");

        if (size == 0) panic("Size is 0\n", .{});
        if (descriptor_size == 0) panic("Descriptor size is 0\n", .{});

        var memory_region_count: u64 = 0;
        const max_count = size / descriptor_size;

        var region_i: u64 = 0;
        while (region_i < max_count and memory_region_count != memory_regions.len - 1)
            : (region_i += 1)
        {
            const descriptor = @intToPtr(*uefi.tables.MemoryDescriptor, @ptrToInt(&memory_map_buffer) + region_i * descriptor_size);

            if (descriptor.type == .ConventionalMemory and descriptor.physical_start >= 0x300000)
            {
                memory_regions[memory_region_count].base_address = descriptor.physical_start; memory_regions[memory_region_count].page_count = descriptor.number_of_pages; memory_region_count += 1; } }
        memory_regions[memory_region_count].base_address = 0;

        efi_check(boot_services.exitBootServices(uefi.handle, map_key),
            "Failed to exit boot services\n");
    }

    // Identity map the first 3MB for the loader
    {
        var paging = @intToPtr([*]u64, 0x140000);
        std.mem.set(u8, @ptrCast([*]u8, paging)[0..0x5000], 0);

        paging[0x1FE] = 0x140003; // Recursive
        paging[0x000] = 0x141003; // L4
        paging[0x200] = 0x142003; // L3
        paging[0x400] = 0x143003; // L2
        paging[0x401] = 0x144003;

        for (paging[0x600..0x600 + 0x400]) |*ptr, i|
        {
            ptr.* = (i * page_size) | 3; // L1
        }
    }

    // Copy the installation ID across
    // @TODO:
    {
        var destination = @intToPtr([*]u8, 0x107ff0)[0..16];
        std.mem.set(u8, destination, 0);
    }

    {
        var video = @intToPtr(*VideoModeInformation, 0x107000);
        video.width = @intCast(u16, provisional_video_information.horizontal_resolution);
        video.height = @intCast(u16, provisional_video_information.vertical_resolution);
        video.physical_buffer_address = provisional_video_information.framebuffer;
        video.bytes_per_scanline = @intCast(u16, provisional_video_information.pixels_per_scan_line * @sizeOf(u32));
        video.bits_per_pixel = 32;
        video.valid_edid_valid = (0 << 1) | (1 << 0);
    }

    // Allocate and map memory for the kernel
    {
        var next_page_table: u64 = 0x1c0000;
        const elf_header = @intToPtr(*ELF.Header, kernel_address);

        assert(elf_header.program_header_entry_size == @sizeOf(ELF.ProgramHeader));

        const program_headers = @intToPtr([*]ELF.ProgramHeader, kernel_address + elf_header.program_header_table_offset)[0..elf_header.program_header_entry_count];

        //print("Program header entry count: {}\n", .{elf_header.program_header_entry_count});
        var boolean = false;
        for (program_headers) |*program_header|
        {
            //print("Header type: {}\n", .{program_header.type});
            if (program_header.type != .load) continue;
            // Program is not prepared to take unaligned segment virtual addresses at the moment
            if (program_header.virtual_address & 0xfff != 0)
            {
                //panic("Program header virtual address must be page-aligned\n", .{});
                cpu_stop();
            }

            // @TODO: this should be or or and?
            const page_to_allocate_count = (program_header.size_in_memory >> page_bit_count) + @boolToInt(program_header.size_in_memory & 0xfff != 0) + @boolToInt(program_header.virtual_address & 0xfff != 0);
            //print("PH address: 0x{x}. Size: 0x{x}. Page count: {}\n", .{program_header.virtual_address, program_header.size_in_memory, page_to_allocate_count});

            var physical_address = blk:
            {
                for (memory_regions) |*region|
                {
                    if (region.base_address == 0) break;
                    if (region.page_count >= page_to_allocate_count)
                    {
                        const result = region.base_address;
                        region.page_count -= page_to_allocate_count;
                        region.base_address += page_to_allocate_count << 12;

                        break :blk result & 0xFFFFFFFFFFFFF000;
                    }
                }

                // panic
                @intToPtr(*u32, provisional_video_information.framebuffer + @sizeOf(u32)).* = 0xffff00ff;
                while (true) {}
            };

            var page_i: u64 = 0;
            while (page_i < page_to_allocate_count)
                : ({
                    page_i += 1;
                    physical_address += page_size;
                    })
            {
                const _base = (program_header.virtual_address + (page_i * page_size));
                if (in_range(program_header))
                {
                    //print("Base: 0x{x}\n", .{_base});
                    if (_base >= fault_address and _base - fault_address < 0x1000)
                    {
                        boolean = true;
                        //print("Base: 0x{x}. Physical address: 0x{x}\n", .{_base, physical_address});
                    }
                }
                const virtual_address = _base & 0x0000FFFFFFFFF000;

                const index_L4: u64 = (virtual_address >> (page_bit_count + entry_per_page_table_bit_count * 3)) & (entry_per_page_table_count - 1);
                const index_L3 = (virtual_address >> (page_bit_count + entry_per_page_table_bit_count * 2)) & (entry_per_page_table_count - 1);
                const index_L2 = (virtual_address >> (page_bit_count + entry_per_page_table_bit_count * 1)) & (entry_per_page_table_count - 1);
                const index_L1 = (virtual_address >> (page_bit_count + entry_per_page_table_bit_count * 0)) & (entry_per_page_table_count - 1);

                var table_L4 = @intToPtr([*]u64, 0x140000);
                if (table_L4[index_L4] & 1 == 0)
                {
                    table_L4[index_L4] = next_page_table | 0b111;
                    std.mem.set(u8, @intToPtr([*]u8, next_page_table)[0..page_size], 0);
                    next_page_table += page_size;
                }

                var table_L3 = @intToPtr([*]u64, table_L4[index_L4] & ~@as(u64, page_size - 1));
                if (table_L3[index_L3] & 1 == 0)
                {
                    table_L3[index_L3] = next_page_table | 0b111;
                    std.mem.set(u8, @intToPtr([*]u8, next_page_table)[0..page_size], 0);
                    next_page_table += page_size;
                }

                var table_L2 = @intToPtr([*]u64, table_L3[index_L3] & ~@as(u64, page_size - 1));
                if (table_L2[index_L2] & 1 == 0)
                {
                    table_L2[index_L2] = next_page_table | 0b111;
                    std.mem.set(u8, @intToPtr([*]u8, next_page_table)[0..page_size], 0);
                    next_page_table += page_size;
                }

                var table_L1 = @intToPtr([*]u64, table_L2[index_L2] & ~@as(u64, page_size - 1));
                table_L1[index_L1] = physical_address | 0b11;
            }

            if (in_range(program_header))
            {
                //print("0x{x} -- 0x{x}\n", .{program_header.virtual_address, program_header.virtual_address + program_header.size_in_memory});
            }
        }
    }

    //{
        //const elf_header = @intToPtr(*ELF.Header, kernel_address);
        //assert(elf_header.program_header_entry_size == @sizeOf(ELF.ProgramHeader));

        //const program_headers = @intToPtr([*]ELF.ProgramHeader, kernel_address + elf_header.program_header_table_offset)[0..elf_header.program_header_entry_count];

        ////print("Program header entry count: {}\n", .{elf_header.program_header_entry_count});
        //for (program_headers) |*program_header|
        //{
            ////print("Header type: {}\n", .{program_header.type});
            //if (program_header.type != .load) continue;

            //// @TODO: this should be or or and?
            //var page_to_allocate_count = (program_header.size_in_memory >> page_bit_count) + @boolToInt(program_header.size_in_memory & 0xfff != 0) + @boolToInt(program_header.virtual_address & 0xfff != 0);

            //var base_virtual_address = program_header.virtual_address & 0x0000FFFFFFFFF000;
            //for (kernel_pages[0..kernel_page_count]) |kernel_page|
            //{
                //if (kernel_page >= base_virtual_address)
                //{
                    //base_virtual_address += page_size;
                    //page_to_allocate_count -= 1;
                //}
            //}

            //var virtual_address_it: u64 = base_virtual_address;
            //const top_address = base_virtual_address + (page_size * page_to_allocate_count);
            //while (virtual_address_it < top_address) : (virtual_address_it += page_size)
            //{
                //kernel_pages[kernel_page_count] = virtual_address_it;
                //kernel_page_count += 1;
            //}
        //}

        ////const base_physical_address = blk:
        ////{
            ////for (memory_regions) |*region|
            ////{
                ////if (region.base_address == 0) break;
                ////if (region.page_count >= page_to_allocate_count)
                ////{
                    ////const result = region.base_address;
                    ////region.page_count -= page_to_allocate_count;
                    ////region.base_address += page_to_allocate_count << 12;

                    ////break :blk result & 0xFFFFFFFFFFFFF000;
                ////}
            ////}

            ////// panic
            ////@intToPtr(*u32, provisional_video_information.framebuffer + @sizeOf(u32)).* = 0xffff00ff;
            ////while (true) {}
        ////};
    //}

    //print("Kernel page count: {}\n", .{kernel_page_count});


    //print("Page to allocate count: {}\n", .{count});

    //if (true) cpu_stop();

    // Copy the memory region information across
    {
        var memory_regions_new = @intToPtr([*]MemoryRegion, 0x160000);
        std.mem.copy(MemoryRegion, memory_regions_new[0..memory_regions.len], memory_regions[0..]);
    }

    // Copy GDT
    //const gdt_base = 0x180000;
    //const gdt_descriptor_base_address = gdt_base + @sizeOf(GDT);
    //{
        //var gdt = @intToPtr(*GDT, gdt_base);
        //gdt.null_entry = 0; // 0x00
        //gdt.code_entry = GDT.Entry.new(0xffff, 0, 0xcf9a, 0); // 0x08
        //gdt.data_entry = GDT.Entry.new(0xffff, 0, 0xcf92, 0); // 0x10
        //gdt.code_entry_16 = GDT.Entry.new(0xffff, 0, 0x0f9a, 0); // 0x18
        //gdt.data_entry_16 = GDT.Entry.new(0xffff, 0, 0x0f92, 0); // 0x20
        //gdt.user_code = GDT.Entry.new(0xffff, 0, 0xcffa, 0); // 0x2b
        //gdt.user_data = GDT.Entry.new(0xffff, 0, 0xcff2, 0); // 0x33
        //gdt.tss1 = GDT.Entry.new(0x68, 0, 0xe9, 0); // 0x38
        //gdt.tss2 = 0;
        //gdt.code_entry_64 = GDT.Entry.new(0xffff, 0, 0xaf9a, 0); // 0x48
        //gdt.data_entry_64 = GDT.Entry.new(0xffff, 0, 0xaf92, 0); // 0x50
        //gdt.user_code_64 = GDT.Entry.new(0xffff, 0, 0xaffa, 0); // 0x5b
        //gdt.user_data_64 = GDT.Entry.new(0xffff, 0, 0xaff2, 0); // 0x63
        //gdt.user_code_64c = GDT.Entry.new(0xffff, 0, 0xaffa, 0); // 0x6b

        //var gdt_descriptor = @intToPtr(*GDT.Descriptor, gdt_descriptor_base_address);
        //gdt_descriptor.limit = @sizeOf(GDT) - 1;
        //gdt_descriptor.base = gdt_base;
    //}

    //{
        //asm volatile("lgdt %[p]"
            //:
            //: [p] "*p" (@intToPtr(*GDT.Descriptor, gdt_descriptor_base_address)));

        //asm volatile(
            //\\.intel_syntax noprefix
            //\\mov rax,0x140000
            //\\mov cr3,rax
            ////\\mov rax,0x200000
            ////\\mov rsp,rax
            //\\mov rax,0x50
            //\\mov ds,rax
            //\\mov es,rax
            //\\mov ss,rax
        //);
    //}
    //

    @intToPtr(fn() callconv(.C) noreturn, uefi_asm_address)();
}

pub fn cpu_stop() callconv(.Inline) noreturn
{
    @setCold(true);
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
