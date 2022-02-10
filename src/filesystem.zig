const std = @import("std");

pub const Superblock = extern struct
{
    disk_start: u64,
    kernel_raw_offset: u64,
    kernel_size: u64,
    desktop_raw_offset: u64,
    desktop_size: u64,

    pub const offset = 0x2000;

    pub fn format(self: *@This(), kernel_raw_offset: u64, kernel_size: u64, disk_start: u64, desktop_raw_offset: u64, desktop_size: u64) void
    {
        self.disk_start = disk_start;
        self.kernel_raw_offset = kernel_raw_offset;
        self.kernel_size = kernel_size;
        self.desktop_raw_offset = desktop_raw_offset;
        self.desktop_size = desktop_size;
    }
};
