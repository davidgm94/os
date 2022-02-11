const kernel = @import("kernel.zig");
const ES_SUCCESS = kernel.ES_SUCCESS;
const round_up = kernel.round_up;
const round_down = kernel.round_down;
const EsMemoryCopy = kernel.EsMemoryCopy;
const Error = kernel.Error;
const Errors = kernel.Errors;
const align_u64 = kernel.align_u64;

const arch = kernel.arch;
const page_size = arch.page_size;

const AHCI = kernel.drivers.AHCI;

const Filesystem = kernel.Filesystem;

const AddressSpace = kernel.memory.AddressSpace;
const Region = kernel.memory.Region;

const std = @import("std");
const assert = std.debug.assert;

pub const ReadError = error
{
    failed,
};

pub const LoadedExecutable = extern struct
{
    start_address: u64,
    tls_image_start: u64,
    tls_image_byte_count: u64,
    tls_byte_count: u64,

    is_desktop: bool,
    is_bundle: bool,
};

pub fn read_file_in_buffer(file_buffer: []u8, file_descriptor: *const Filesystem.File.Descriptor) ReadError!void
{
    try AHCI.driver.get_drive().read_file(file_buffer, file_descriptor);
}

pub fn read_file_alloc(space: *AddressSpace, file_descriptor: *const Filesystem.File.Descriptor) ![]u8
{
    const drive = AHCI.Driver.get_drive();
    const sector_aligned_size = align_u64(file_descriptor.size, drive.block_device.sector_size);
    const file_buffer = @intToPtr(?[*]u8, space.allocate_standard(sector_aligned_size, Region.Flags.empty(), 0, true)) orelse return ReadError.failed;
    return try drive.read_file(file_buffer, file_descriptor);
}

export var desktop_executable_buffer: [0x8000]u8 align(0x1000) = undefined;

fn hard_disk_read_desktop_executable() void
{
    read_file_in_buffer(@intToPtr([*]u8, @ptrToInt(&desktop_executable_buffer))[0..desktop_executable_buffer.len], &superblock.desktop_exe) catch kernel.panicf("Unable to read desktop executable\n", .{});
}

var superblock: Filesystem.Superblock = undefined;

pub fn parse_superblock() void
{
    var superblock_buffer: [0x200]u8 align(0x200) = undefined;
    read_file_in_buffer(&superblock_buffer, &Filesystem.Superblock.file_descriptor) catch kernel.panicf("Unable to read superblock\n", .{});
    var superblock_buffer_ptr = @intToPtr(*Filesystem.Superblock, @ptrToInt(&superblock_buffer));
    superblock = superblock_buffer_ptr.*;
}

const ELF = extern struct
{
    const Header = extern struct
    {
        magic: u32,
        bits: u8,
        endianness: u8,
        version1: u8,
        abi: u8,
        unused: [8]u8,
        type: u16,
        instruction_set: u16,
        version2: u32,

        entry: u64,
        program_header_table: u64,
        section_header_table: u64,
        flags: u32,
        header_size: u16,
        program_header_entry_size: u16,
        program_header_entry_count: u16,
        section_header_entry_size: u16,
        section_header_entry_count: u16,
        section_name_index: u16,
    };

    const ProgramHeader = extern struct
    {
        type: u32,
        flags: u32,
        file_offset: u64,
        virtual_address: u64,
        unused0: u64,
        data_in_file: u64,
        segment_size: u64,
        alignment: u64,

        fn is_bad(self: *@This()) bool
        {
            return self.virtual_address >= 0xC0000000 or self.virtual_address < 0x1000 or self.segment_size > 0x10000000;
        }
    };
};

pub fn LoadDesktopELF(exe: *LoadedExecutable) Error
{
    const process = arch.get_current_thread().?.process.?;

    hard_disk_read_desktop_executable();

    const header = @ptrCast(*ELF.Header, &desktop_executable_buffer);
    if (header.magic != 0x464c457f) return Errors.ES_ERROR_UNSUPPORTED_EXECUTABLE;
    if (header.bits != 2) return Errors.ES_ERROR_UNSUPPORTED_EXECUTABLE;
    if (header.endianness != 1) return Errors.ES_ERROR_UNSUPPORTED_EXECUTABLE;
    if (header.abi != 0) return Errors.ES_ERROR_UNSUPPORTED_EXECUTABLE;
    if (header.type != 2) return Errors.ES_ERROR_UNSUPPORTED_EXECUTABLE;
    if (header.instruction_set != 0x3e) return Errors.ES_ERROR_UNSUPPORTED_EXECUTABLE;

    const program_headers = @intToPtr(?[*]ELF.ProgramHeader, kernel.heapFixed.allocate(header.program_header_entry_size * header.program_header_entry_count, false)) orelse return Errors.ES_ERROR_INSUFFICIENT_RESOURCES; // K_PAGED
    defer kernel.heapFixed.free(@ptrToInt(program_headers), 0); // K_PAGED

    const executable_offset = 0;
    EsMemoryCopy(@ptrToInt(program_headers), @ptrToInt(&desktop_executable_buffer[executable_offset + header.program_header_table]), header.program_header_entry_size * header.program_header_entry_count);

    var ph_i: u64 = 0;
    while (ph_i < header.program_header_entry_count) : (ph_i += 1)
    {
        const ph = @intToPtr(*ELF.ProgramHeader, @ptrToInt(program_headers) + header.program_header_entry_size * ph_i);

        if (ph.type == 1) // PT_LOAD
        {
            if (ph.is_bad()) return Errors.ES_ERROR_UNSUPPORTED_EXECUTABLE;

            const result = process.address_space.allocate_standard(round_up(u64, ph.segment_size, page_size), Region.Flags.empty(), round_down(u64, ph.virtual_address, page_size), true);
            if (result != 0)
            {
                EsMemoryCopy(ph.virtual_address, @ptrToInt(&desktop_executable_buffer[executable_offset + ph.file_offset]), ph.data_in_file);
            }
            else
            {
                return Errors.ES_ERROR_INSUFFICIENT_RESOURCES;
            }
        }
        else if (ph.type == 7)  // PT_TLS
        {
            exe.tls_image_start = ph.virtual_address;
            exe.tls_image_byte_count = ph.data_in_file;
            exe.tls_byte_count = ph.segment_size;
        }
    }

    exe.start_address = header.entry;
    return ES_SUCCESS;
}
