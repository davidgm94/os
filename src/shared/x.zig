const std = @import("std");

const Arch = enum(u16)
{
    x86_64,
};

const OS = enum(u16)
{
    Renaissance,
};

const XHeader = struct
{
    signature: u32,
    cpu_architecture: Arch,
    os: OS,
    entry_point: u64,
    file_size: u64,
    section_count: u16,
    section_alignment: u16,
    time_data_stamp: u32,
};

const SectionHeader = struct
{
    size: u64,
    file_offset: u64,
    memory_offset: u64,
    permissions: u32,
    flags: u32,
};
