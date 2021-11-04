const Kernel = @import("../kernel/kernel.zig");

var acpi: ACPI = undefined;

pub const ACPI = extern struct
{
    processor_count: u64,
    IO_APIC_count: u64,
    interrupt_override_count: u64,
    LAPIC_NMI_count: u64,

    rsdp: *RootSystemDescriptorPointer,

    pub fn parse_tables() void
    {
        const rsdp_address = Kernel.Arch.RSDP_find();
        acpi.rsdp = @intToPtr(*RootSystemDescriptorPointer, Kernel.Memory.map_physical(&Kernel.kernel_memory_space, rsdp_address, 0x4000, 0) orelse unreachable);

        if (acpi.rsdp.revision == 2 and acpi.rsdp.extended_address != 0)
        {
            // ni
            Kernel.Arch.CPU_stop();
        }

        const is_xsdt = false;
        const sdt = @intToPtr(*align(1) DescriptorTable, Kernel.Memory.map_physical(&Kernel.kernel_memory_space, acpi.rsdp.address, 0x4000, 0) orelse unreachable);
        if (!(sdt.signature == RSDT_signature and sdt.length < 0x4000))
        {
            Kernel.Arch.CPU_stop();
        }

        const table_count = (sdt.length - @sizeOf(DescriptorTable)) >> comptime (2 + @boolToInt(is_xsdt));

        if (table_count == 0) Kernel.Arch.CPU_stop();

        const table_list_address = @ptrToInt(sdt) + DescriptorTable.header_length;

        var table_i: u64 = 0;
        while (table_i < table_count) : (table_i += 1)
        {
            // XSDT
            const table_address = @intToPtr([*]align(1) u32, table_list_address)[table_i];

            const header_address = Kernel.Memory.map_physical(&Kernel.kernel_memory_space, table_address, @sizeOf(DescriptorTable), 0) orelse unreachable;
            const header = @intToPtr(*align(1) DescriptorTable, header_address);
            _ = header;
            var a: u32 = 1;
            a += 1;
        }

        Kernel.Arch.CPU_stop();
    }

    pub const RootSystemDescriptorPointer = extern struct
    {
        signature: u64,
        checksum: u8,
        OEM_ID: [6]u8,
        revision: u8,
        address: u32,
        length: u32,
        extended_address: u64,
        extended_checksum: u8,
        reserved: [3]u8,

        pub const signature = 0x2052545020445352;
    };

    pub const XSDT_signature = 0x54445358;
    pub const RSDT_signature = 0x54445352;

    pub const DescriptorTable = extern struct
    {
        signature: u32,
        length: u32,
        ID: u64,
        table_ID: u64,
        OEM_revision: u32,
        creator_ID: u32,
        creator_revision: u32,

        const header_length = 36;
    };
};
