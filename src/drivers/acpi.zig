const std = @import("std");
const Kernel = @import("../kernel/kernel.zig");

var acpi: ACPI = undefined;

pub const ACPI = extern struct
{
    processor_count: u64,
    IO_APIC_count: u64,
    interrupt_override_count: u64,
    LAPIC_NMI_count: u64,

    processors: [256]CPU,
    IO_APICs: [16]IOAPIC,
    interrupt_overrides: [256]InterruptOverride,
    LAPIC_NMIs: [32]LAPIC_NMI,

    LAPIC_address: *volatile u32,

    rsdp: *RootSystemDescriptorPointer,

    PS2_controller_unavailable: bool,
    VGA_controller_unavailable: bool,
    century_register_index: u8,

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
            const physical_header_address = @intToPtr([*]align(1) u32, table_list_address)[table_i];

            const virtual_header_address = Kernel.Memory.map_physical(&Kernel.kernel_memory_space, physical_header_address, @sizeOf(DescriptorTable), 0) orelse unreachable;
            const header = @intToPtr(*align(1) DescriptorTable, virtual_header_address);

            switch (header.signature)
            {
                MADT_signature =>
                {
                    header.check();
                    const madt = @intToPtr(*align(1) MADT, virtual_header_address + DescriptorTable.header_length);
                    var length = header.length - DescriptorTable.header_length - @sizeOf(MADT);
                    const start_length = length;
                    var data = @intToPtr([*]u8, @ptrToInt(madt) + @sizeOf(MADT));

                    acpi.LAPIC_address = @intToPtr(*volatile u32, ACPI.map_physical_memory(madt.LAPIC_address, 0x10000));

                    var entry_type: MADT.EntryType = undefined;
                    var entry_length: u8 = undefined;
                    while (length != 0 and length <= start_length) : 
                    ({
                        length -= entry_length;
                        data = @intToPtr([*]u8, @ptrToInt(data) + entry_length);
                    })
                    {
                        entry_type = @intToEnum(MADT.EntryType, data[0]);
                        entry_length = data[1];

                        switch (entry_type)
                        {
                            .LAPIC =>
                            {
                                if ((data[4] & 1) == 0) continue;

                                var processor = &acpi.processors[acpi.processor_count];

                                processor.processor_ID = data[2];
                                processor.APIC_ID = data[3];

                                acpi.processor_count += 1;
                            },
                            .IO_APIC =>
                            {
                                var io_apic = &acpi.IO_APICs[acpi.IO_APIC_count];

                                io_apic.id = data[2];
                                io_apic.address = @intToPtr([*] volatile u32, ACPI.map_physical_memory(@ptrCast([*]align(1) u32, data)[1], 0x10000));
                                _ = io_apic.read(0); // make sure it's mapped
                                io_apic.GSI_base = @ptrCast([*]align(1) u32, data)[2];

                                acpi.IO_APIC_count += 1;
                            },
                            .IO_APIC_ISO =>
                            {
                                var iso = &acpi.interrupt_overrides[acpi.interrupt_override_count];
                                iso.source_IRQ = data[3];
                                iso.GSI_number = @ptrCast([*] align(1) u32, data)[1];
                                iso.active_low = data[8] & 2 != 0;
                                iso.level_triggered = data[8] & 8 != 0;

                                acpi.interrupt_override_count += 1;
                            },
                            .LAPIC_NMI =>
                            {
                                var nmi = &acpi.LAPIC_NMIs[acpi.LAPIC_NMI_count];

                                nmi.processor = data[2];
                                nmi.lint_index = data[5];
                                nmi.active_low = data[3] & 2 != 0;
                                nmi.level_triggered = data[3] & 8 != 0;
                                
                                acpi.LAPIC_NMI_count += 1;
                            },
                            else => unreachable,
                        }
                    }
                },
                FADT_signature =>
                {
                    const fadt = @intToPtr(*align(1) DescriptorTable, Kernel.Memory.map_physical(&Kernel.kernel_memory_space, physical_header_address, header.length, 0) orelse unreachable);
                    fadt.check();

                    if (header.length > 109)
                    {
                        const fadt_bytes = @ptrCast([*]u8, fadt);
                        acpi.century_register_index = fadt_bytes[108];
                        const boot_architecture_flags = fadt_bytes[109];
                        acpi.PS2_controller_unavailable = (~boot_architecture_flags & (1 << 1)) != 0;
                        acpi.VGA_controller_unavailable = (boot_architecture_flags & (1 << 2)) != 0;
                    }

                    Kernel.Memory.free(&Kernel.kernel_memory_space, @ptrToInt(fadt), null, null) catch unreachable;
                },
                HPET_signature =>
                {
                    const hpet = @intToPtr(*align(1) DescriptorTable, Kernel.Memory.map_physical(&Kernel.kernel_memory_space, physical_header_address, header.length, 0) orelse unreachable);
                    hpet.check();

                    if (header.length == 52 and @ptrCast([*]u8, hpet)[52] == 0)
                    {
                        const header_bytes = @ptrCast([*]u8, header);
                        const base_address = @ptrCast([*]align(1) u64, &header_bytes[44])[0];
                        _ = base_address;
                    }

                    Kernel.Memory.free(&Kernel.kernel_memory_space, @ptrToInt(hpet), null, null) catch unreachable;
                },
                else => {}
            }

            Kernel.Memory.free(&Kernel.kernel_memory_space, virtual_header_address, null, null) catch unreachable;
        }

        if (acpi.processor_count > 256 or acpi.IO_APIC_count > 16 or acpi.interrupt_override_count > 256 or acpi.LAPIC_NMI_count > 32)
        {
            Kernel.Arch.CPU_stop();
        }

        Kernel.Arch.CPU_stop();
    }

    fn map_physical_memory(physical_address: u64, length: u64) u64
    {
        return Kernel.Memory.map_physical(&Kernel.kernel_memory_space, physical_address, length, 1 << @enumToInt(Kernel.Memory.Region.Flags.not_cacheable)) orelse unreachable;
    }

    pub const MADT = extern struct
    {
        LAPIC_address: u32,
        flags: u32,

        const EntryType = enum(u8)
        {
            LAPIC = 0,
            IO_APIC = 1,
            IO_APIC_ISO = 2,
            IO_APIC_NMI_source = 3,
            LAPIC_NMI = 4,
            LAPIC_address_override = 5,
            local_x2APIC = 9,
        };
    };

    const MADT_signature = 0x43495041;
    const FADT_signature = 0x50434146;
    const HPET_signature = 0x54455048;

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

        fn check(self: *align(1) DescriptorTable) void
        {
            if (@truncate(u8, Kernel.Arch.sum_bytes(@ptrCast([*]u8, self)[0..self.length])) != 0)
                Kernel.Arch.CPU_stop();
        }
    };

    pub const CPU = extern struct
    {
        processor_ID: u8,
        kernel_processor_ID: u8,
        APIC_ID: u8,
        boot_processor: bool,
        // @TODO: add more components
    };

    pub const IOAPIC = extern struct
    {
        address: [*] volatile u32,
        GSI_base: u32,
        id: u8,

        fn read(self: *IOAPIC, register: u32) u32
        {
            self.address[0] = register;
            return self.address[4];
        }

        fn write(self: *IOAPIC, register: u32, value: u32) void
        {
            self.address[0] = register;
            self.address[4] = value;
        }
    };

    pub const InterruptOverride = extern struct
    {
        source_IRQ: u8,
        GSI_number: u32,
        active_low: bool,
        level_triggered: bool,
    };

    pub const LAPIC_NMI = extern struct
    {
        processor: u8,
        lint_index: u8,
        active_low: bool,
        level_triggered: bool
    };
};
