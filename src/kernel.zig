const unused_delay = Port(0x0080);
fn Port(comptime port: u16) type
{
    return struct
    {
        const Self = @This();

        pub fn read(comptime T: type) callconv(.Inline) T
        {
            return switch(T)
            {
                u8 => in8(port),
                u16 => in16(port),
                u32 => in32(port),
                else => @compileError("type not supported"),
            };
        }

        pub fn write(comptime T: type, value: T) callconv(.Inline) void
        {
            switch(T)
            {
                u8 => out8(port, value),
                u16 => out16(port, value),
                u32 => out32(port, value),
                else => @compileError("type not supported"),
            }
        }

        pub fn write_delayed(comptime T: type, value: T) callconv(.Inline) void
        {
            switch(T)
            {
                u8  => { out8(port, value);  _ = unused_delay.read(u8); },
                u16 => { out16(port, value); _ = unused_delay.read(u8); },
                u32 => { out32(port, value); _ = unused_delay.read(u8); },
                else => @compileError("type not supported"),
            }
        }
    };
}

fn in8(comptime port: u16) callconv(.Inline) u8
{
    return asm volatile(
        "inb %[port], %[result]"
        : [result] "={al}" (-> u8)
        : [port] "N{dx}" (port)
    );
}

fn out8(comptime port: u16, value: u8) callconv(.Inline) void
{
    asm volatile(
        "outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port]  "N{dx}" (port)
    );
}

fn in16(comptime port: u16) callconv(.Inline) u16
{
    _ = port;
    unreachable;
    //return asm volatile(
        //"inb %[port], %[result]"
        //: [result] "={al}" (-> u8)
        //: [port] "N{dx}" (port)
    //);
}

fn out16(comptime port: u16, value: u16) callconv(.Inline) void
{
    _ = port; _ = value;
    unreachable;
    //asm volatile(
        //"outb %[value], %[port]"
        //:
        //: [value] "{al}" (value),
          //[port]  "N{dx}" (port)
    //);
}

fn in32(comptime port: u16) callconv(.Inline) u32
{
    _ = port;
    unreachable;
    //return asm volatile(
        //"inb %[port], %[result]"
        //: [result] "={al}" (-> u8)
        //: [port] "N{dx}" (port)
    //);
}

fn out32(comptime port: u16, value: u32) callconv(.Inline) void
{
    _ = port; _ = value;
    unreachable;
    //asm volatile(
        //"outb %[value], %[port]"
        //:
        //: [value] "{al}" (value),
          //[port]  "N{dx}" (port)
    //);
}

const PIC1_command = Port(0x20);
const PIC1_data = Port(0x21);
const PIC2_command = Port(0xa0);
const PIC2_data = Port(0xa1);

export fn PIC_disable() callconv(.C) void
{
    PIC1_command.write_delayed(u8, 0x11);
    PIC2_command.write_delayed(u8, 0x11);
    PIC1_data.write_delayed(u8, 0x20);
    PIC2_data.write_delayed(u8, 0x28);
    PIC1_data.write_delayed(u8, 0x04);
    PIC2_data.write_delayed(u8, 0x02);
    PIC1_data.write_delayed(u8, 0x01);
    PIC2_data.write_delayed(u8, 0x01);

    PIC1_data.write_delayed(u8, 0xff);
    PIC2_data.write_delayed(u8, 0xff);
}

const page_bit_count = 12;
const page_size = 0x1000;

//const core_memory_region_start = 0xFFFF8001F0000000;
//const core_memory_region_count = (0xFFFF800200000000 - 0xFFFF8001F0000000) / @sizeOf(MMRegion);
const mm_kernel_space_start = 0xFFFF900000000000;
const mm_kernel_space_size =  0xFFFFF00000000000 - 0xFFFF900000000000;
const mm_modules_start =      0xFFFFFFFF90000000;
const mm_modules_size =      0xFFFFFFFFC0000000 - 0xFFFFFFFF90000000;

const mm_core_space_start =   0xFFFF800100000000;
const mm_core_space_size  = 0xFFFF8001F0000000 - 0xFFFF800100000000;
const mm_user_space_start = 0x100000000000;
const mm_user_space_size  = 0xF00000000000 - 0x100000000000;
const low_memory_map_start = 0xFFFFFE0000000000;
const low_memory_limit = 0x100000000; // The first 4GB is mapped here.

export fn memory_region_setup() callconv(.C) void
{
    //const physical_memory_region_ptr = 
}

const PhysicalMemoryRegion = extern struct
{
    base_address: u64,
    page_count: u64,
};

const PhysicalMemory = struct
{
    regions: []PhysicalMemoryRegion,
    page_count: u64,
    original_page_count: u64,
    region_index: u64,
    highest: u64,
};

const Kernel = struct
{
    physical_memory: PhysicalMemory,
};

var kernel: Kernel = undefined;
