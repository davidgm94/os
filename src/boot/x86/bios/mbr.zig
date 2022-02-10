pub const length = 0x200;
pub const disk_identifier_length = 10;

pub const Offset = struct
{
    pub const kernel_size = disk_identifier - 4;
    pub const disk_identifier = 0x1b4;
    pub const partition = Offset.disk_identifier + disk_identifier_length;
};
