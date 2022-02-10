const std = @import("std");

pub const Superblock = extern struct
{
    kernel_exe: File.Descriptor,
    desktop_exe: File.Descriptor,
    disk_start: u64,

    pub const offset = 0x2000;
    pub const file_descriptor = File.Descriptor { .offset = offset, .size = @sizeOf(Superblock) };

    pub fn format(self: *@This(), kernel_raw_offset: u64, kernel_size: u64, disk_start: u64, desktop_raw_offset: u64, desktop_size: u64) void
    {
        self.kernel_exe = .{ .offset = kernel_raw_offset, .size = kernel_size };
        self.desktop_exe = .{ .offset = desktop_raw_offset, .size = desktop_size };
        self.disk_start = disk_start;
    }
};

pub const File = extern struct
{
    pub const Descriptor = extern struct
    {
        offset: u64,
        size: u64,
    };
};
