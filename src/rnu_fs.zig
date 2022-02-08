const std = @import("std");

pub const Superblock = extern struct
{
    kernel_raw_offset: u64,
    kernel_size: u64,
    disk_start: u64,

    pub const offset = 0x2000;

    pub fn format(self: *@This(), kernel_raw_offset: u64, kernel_size: u64, disk_start: u64) void
    {
        self.kernel_raw_offset = kernel_raw_offset;
        self.kernel_size = kernel_size;
        self.disk_start = disk_start;
    }
};
