const kernel = @import("../kernel.zig");

const TODO = kernel.TODO;
const Bitflag = kernel.Bitflag;
const log = kernel.log;

const arch = kernel.arch;
const serial = kernel.drivers.serial;

const Region = kernel.memory.Region;

const std = @import("std");

pub const Driver = struct
{
    linear_buffer: [*]volatile u8,
    width: u32,
    height: u32,
    pixel_byte_count_x: u32,
    pixel_byte_count_y: u32,

    pub fn init() void
    {
        driver.setup();
    }

    fn setup(self: *@This()) void
    {
        info = @intToPtr(?*VideoModeInformation, kernel.address_space.map_physical(0x7000 + arch.bootloader_information_offset, @sizeOf(VideoModeInformation), Region.Flags.empty())) orelse kernel.panic("Unable to map VBE");

        if (!info.validation.contains(.valid)) kernel.panic("Unable to initialize VBE: valid is missing\n");

        if (info.validation.contains(.edid_valid))
        {
            serial.write("EDID:\n");
            for (info.edid) |edid_byte, i|
            {
                if (i % 10 == 0) serial.write("\n");
                log(" 0x{x:0>2} |", .{edid_byte});
            }
            serial.write("\n");
        }

        self.linear_buffer = @intToPtr(?[*]volatile u8, kernel.address_space.map_physical(info.buffer_physical_address, @intCast(u32, info.bytes_per_scanline) * @intCast(u32, info.height), Region.Flags.from_flag(.write_combining))) orelse kernel.panic("Unable to map VBE");
        log("Linear buffer: {*}\n", .{self.linear_buffer});
        self.width = info.width;
        self.height = info.height;
        self.pixel_byte_count_x = info.bits_per_pixel >> 3;
        self.pixel_byte_count_y = info.bytes_per_scanline;

        if (info.bits_per_pixel != 32)
        {
            kernel.panicf("Only 32 bit pixels are supported. VBE pixel count: {}", .{info.bits_per_pixel});
        }
    }

    pub fn update_screen(self: *@This(), source_ptr: [*]const u8, source_width: u32, source_height: u32, source_stride: u32, destination_x: u32, destination_y: u32) void
    {
        var destination_row_start = @intToPtr([*]u32, @ptrToInt(self.linear_buffer) + destination_x * @sizeOf(u32) + destination_y * self.pixel_byte_count_y);
        const source_row_start = @ptrCast([*]const u32, source_ptr);

        if (destination_x > self.width or source_width > self.width - destination_x or destination_y > self.height or source_height > self.height - destination_y)
        {
            kernel.panic("Update region outside graphics target bounds");

            var y: u64 = 0;
            while (y < source_height) :
                ({
                    y += 1;
                    destination_row_start += self.pixel_byte_count_y / 4;
                    source_row_start += source_stride / 4;
                })
            {
                const destination = destination_row_start[0..source_width];
                const source = source_row_start[0..source_width];
                std.mem.copy(@TypeOf(source), destination, source);
            }
        }
    }

    pub fn debug_put_block(self: *@This(), x: u64, y: u64, toggle: bool) void
    {
        if (toggle)
        {
            self.linear_buffer[y * self.pixel_byte_count_y + x * @sizeOf(u32) + 0] += 0x4c;
            self.linear_buffer[y * self.pixel_byte_count_y + x * @sizeOf(u32) + 1] += 0x4c;
            self.linear_buffer[y * self.pixel_byte_count_y + x * @sizeOf(u32) + 2] += 0x4c;
        }
        else
        {
            self.linear_buffer[y * self.pixel_byte_count_y + x * @sizeOf(u32) + 0] = 0xff;
            self.linear_buffer[y * self.pixel_byte_count_y + x * @sizeOf(u32) + 1] = 0xff;
            self.linear_buffer[y * self.pixel_byte_count_y + x * @sizeOf(u32) + 2] = 0xff;
        }

        self.linear_buffer[(y + 1) * self.pixel_byte_count_y + (x + 1) * @sizeOf(u32) + 0] = 0;
        self.linear_buffer[(y + 1) * self.pixel_byte_count_y + (x + 1) * @sizeOf(u32) + 1] = 0;
        self.linear_buffer[(y + 1) * self.pixel_byte_count_y + (x + 1) * @sizeOf(u32) + 2] = 0;

    }

    pub fn debug_clear_screen(self: *@This()) void
    {
        var height_i: u64 = 0;
        while (height_i < self.height) : (height_i += 1)
        {
            var width_i: u64 = 0;
            while (width_i < self.width * @sizeOf(u32)) : (width_i += @sizeOf(u32))
            {
                if (true)
                {
                    self.linear_buffer[height_i * self.pixel_byte_count_y + width_i + 2] = 0x18;
                    self.linear_buffer[height_i * self.pixel_byte_count_y + width_i + 1] = 0x7e;
                    self.linear_buffer[height_i * self.pixel_byte_count_y + width_i + 0] = 0xcf;
                }
                else
                {
                    TODO();
                }
            }
        }
    }
};

pub var driver: Driver = undefined;
var info: *VideoModeInformation = undefined;

const VideoModeInformation = extern struct
{
    validation: Validation,
    bits_per_pixel: u8,
    width: u16,
    height: u16,
    bytes_per_scanline: u16,
    buffer_physical_address: u64,
    edid: [128]u8,

    const Validation = Bitflag(enum(u8)
        {
            valid = 0,
            edid_valid = 1,
        });
    };
