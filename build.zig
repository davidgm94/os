const std = @import("std");

const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;
const Target = std.Target;
const FileSource = std.build.FileSource;
const Step = std.build.Step;
const RunStep = std.build.RunStep;
const LibExeObjStep = std.build.LibExeObjStep;
const InstallFileStep = std.build.InstallFileStep;

const ArrayList = std.ArrayList;
const print = std.debug.print;
const assert = std.debug.assert;
const panic = std.debug.panic;
const allocPrint = std.fmt.allocPrint;
const comptimePrint = std.fmt.comptimePrint;

const a_megabyte = 1024 * 1024;

const cross_target = CrossTarget
{
    .cpu_arch = .x86_64,
    .os_tag = .freestanding,
    .abi = .none,
};

const Loader = enum
{
    BIOS,
    UEFI,
};

const build_cache_dir = "zig-cache/";
const build_output_dir = "zig-out/bin/";

const common_c_flags = &[_][]const u8
{
    "-ffreestanding",
    "-fno-exceptions",
    "-Wall",
    "-Wextra",
};

const NASM = struct
{
    fn build_flat_binary(builder: *Builder, comptime src: []const u8, comptime out: []const u8) *RunStep
    {
        const base_nasm_command = &[_][]const u8 { "nasm", "-fbin", src, "-o", out };
        return builder.addSystemCommand(base_nasm_command);
    }

    fn build_object(builder: *Builder, executable: *LibExeObjStep, comptime obj_src: []const u8, comptime obj_out: []const u8) void
    {
        const base_nasm_command = &[_][]const u8 { "nasm", "-felf64", "-g", "-F", "dwarf", obj_src, "-o", obj_out };
        const nasm_command = builder.addSystemCommand(base_nasm_command);
        executable.addObjectFile(obj_out);
        executable.step.dependOn(&nasm_command.step);
    }
};

const Kernel = struct
{
    elf_name: []const u8,
    out_path: []const u8,
    elf_path: []const u8,
    stripped: []const u8,

    const Version = enum
    {
        Rust,
        CPP,
        Zig,
    };

    const rust = Kernel
    {
        .elf_name = Rust.elf_name,
        .out_path = Rust.out_path,
        .elf_path = Rust.out_path ++ Rust.elf_name,
        .stripped = Rust.out_path ++ Rust.elf_name ++ ".stripped",
    };

    const cpp = Kernel
    {
        .elf_name = CPP.elf_name,
        .out_path = build_cache_dir,
        .elf_path = build_cache_dir ++ CPP.elf_name,
        .stripped = undefined
    };

    const zig = Kernel
    {
        .elf_name = Zig.elf_name,
        .out_path = build_cache_dir,
        .elf_path = build_cache_dir ++ Zig.elf_name,
        .stripped = undefined
    };

    fn strip_symbols(b: *Builder) ?*RunStep
    {
        if (kernel_version == .Rust)
        {
            const result = b.addSystemCommand(&[_][]const u8
                {
                    "objcopy",
                    "--strip-debug",
                    switch (kernel_version)
                    {
                        .CPP => Kernel.cpp.elf_path,
                        .Rust => Kernel.rust.elf_path,
                        .Zig => Kernel.zig.elf_path,
                    },
                    switch (kernel_version)
                    {
                        .CPP => Kernel.cpp.stripped,
                        .Rust => Kernel.rust.stripped,
                        .Zig => Kernel.zig.stripped,
                    },
                    });
            result.step.dependOn(b.default_step);
            return result;
        }

        return null;
    }

    fn build_kernel_common(b: *Builder, kernel_zig_file: ?[]const u8, kernel_output_file: []const u8) *LibExeObjStep
    {
        const kernel = b.addExecutable(kernel_output_file, kernel_zig_file);
        kernel.red_zone = false;
        kernel.code_model = .kernel;
        kernel.disable_stack_probing = true;
        kernel.link_function_sections = false;
        kernel.setMainPkgPath("src");
        kernel.setLinkerScriptPath(FileSource.relative(Kernel.linker_script_path));
        kernel.setOutputDir(build_cache_dir);

        var disabled_features = std.Target.Cpu.Feature.Set.empty;
        var enabled_features = std.Target.Cpu.Feature.Set.empty;

        const features = std.Target.x86.Feature;
        disabled_features.addFeature(@enumToInt(features.mmx));
        disabled_features.addFeature(@enumToInt(features.sse));
        disabled_features.addFeature(@enumToInt(features.sse2));
        disabled_features.addFeature(@enumToInt(features.sse3));
        disabled_features.addFeature(@enumToInt(features.ssse3));
        disabled_features.addFeature(@enumToInt(features.sse4a));
        disabled_features.addFeature(@enumToInt(features.sse4_1));
        disabled_features.addFeature(@enumToInt(features.sse4_2));
        disabled_features.addFeature(@enumToInt(features.avx));
        disabled_features.addFeature(@enumToInt(features.avx2));
        enabled_features.addFeature(@enumToInt(features.soft_float));

        const kernel_cross_target = CrossTarget
        {
            .cpu_arch = cross_target.cpu_arch,
            .os_tag = cross_target.os_tag,
            .abi = cross_target.abi,
            .cpu_features_sub = disabled_features,
            .cpu_features_add = enabled_features,
        };
        kernel.setTarget(kernel_cross_target);

        return kernel;
    }

    const Rust = struct
    {
        const elf_name = "renaissance-os";
        const out_path = "target/rust_target/debug/";

        fn build(b: *Builder) void
        {
            const cargo_build = b.addSystemCommand(&[_][]const u8 { "cargo", "build" });
            b.default_step.dependOn(&cargo_build.step);
        }
    };

    const CPP = struct
    {
        fn build(b: *Builder) void
        {
            const kernel = build_kernel_common(b, null, cpp.elf_name);

            kernel.addCSourceFiles(c_source_files, common_c_flags);

            NASM.build_object(b, kernel, "src/x86_64.S", "zig-cache/kernel_x86.o");

            b.default_step.dependOn(&kernel.step);
        }

        const elf_name = "cpp_kernel.elf";
        const c_source_files = &[_][]const u8
        {
            "src/kernel.cpp",
        };
    };

    const Zig = struct
    {
        const elf_name = "zig_kernel.elf";
        const src_file = "src/main.zig";

        fn build(b: *Builder) void
        {
            const kernel = build_kernel_common(b, Zig.src_file, zig.elf_name);
            //kernel.addAssemblyFile("src/arch.S");
            b.default_step.dependOn(&kernel.step);
        }
    };

    const linker_script_path = "src/linker.ld";
};

const BIOS = struct
{
    const mbr_output_path = build_cache_dir ++ BIOS.Bootloader.mbr_output_file;
    const stage_1_output_path = build_cache_dir ++ BIOS.Bootloader.stage_1_output_file;
    const stage_2_output_path = build_cache_dir ++ BIOS.Bootloader.stage_2_output_file;

    const Bootloader = struct
    {
        const source_root_dir = "src/boot/x86/";

        const mbr_source_file = source_root_dir ++ "mbr.S";
        const mbr_output_file = "mbr.bin";

        const stage_1_source_file = source_root_dir ++ "bios_stage_1.S";
        const stage_1_output_file = "bios_stage_1.bin";

        const stage_2_source_file = source_root_dir ++ "bios_stage_2.S";
        const stage_2_output_file = "bios_stage_2.bin";

        fn build(b: *Builder) void
        {
            const mbr = NASM.build_flat_binary(b, mbr_source_file, mbr_output_path);
            b.default_step.dependOn(&mbr.step);

            const stage_1 = NASM.build_flat_binary(b, stage_1_source_file, stage_1_output_path);
            b.default_step.dependOn(&stage_1.step);

            const stage_2 = NASM.build_flat_binary(b, stage_2_source_file, stage_2_output_path);
            b.default_step.dependOn(&stage_2.step);
        }
    };


    const Image = struct
    {
        const Self = @This();

        const size: u64 = 64 * a_megabyte;
        const memory_size: u64 = size;
        const output_file = "bios_disk.img";
        const final_path = build_cache_dir ++ output_file;
        var step: *Step = undefined;

        step: Step,
        builder: *Builder,
        file_buffer: ArrayList(u8),

        fn build(_step: *Step) !void
        {
            const self = @fieldParentPtr(Self, "step", _step);
            const MBR = @import("src/boot/x86/mbr.zig");

            self.file_buffer = try ArrayList(u8).initCapacity(self.builder.allocator, Image.size);
            self.file_buffer.items.len = Image.size;
            std.mem.set(u8, self.file_buffer.items, 0);
            self.file_buffer.items.len = 0;

            print("Reading MBR file...\n", .{});
            try self.copy_file(BIOS.mbr_output_path, MBR.length);
            var partitions = @intToPtr(*align(1) [16]u32, @ptrToInt(&self.file_buffer.items[MBR.Offset.partition]));
            partitions[0] = 0x80; // bootable
            partitions[1] = 0x83; // type
            partitions[2] = 0x800; // offset
            partitions[3] = @intCast(u32, Image.size / 0x200) - 0x800; // sector count
            fix_partition(partitions);

            // fill out 0s for this space
            const blank_size = 0x800 * 0x200 - 0x200;
            self.file_buffer.items.len += blank_size;

            const stage_1_max_length = 0x200;
            print("Reading BIOS stage 1 file...\n", .{});
            try self.copy_file(stage_1_output_path, stage_1_max_length);
            print("File offset: {}\n", .{self.file_buffer.items.len});

            const stage_2_max_length = 0x200 * 15;
            const file_offset = self.file_buffer.items.len;
            print("Reading BIOS stage 2 file...\n", .{});
            try self.copy_file(stage_2_output_path, stage_2_max_length);
            const kernel_offset = file_offset + stage_2_max_length;
            self.file_buffer.items.len = kernel_offset;
            print("File offset: {}\n", .{self.file_buffer.items.len});
            var kernel_size: u32 = 0;
            try self.copy_file(
                switch (kernel_version)
                {
                    .Rust => Kernel.rust.stripped,
                    .CPP => Kernel.cpp.elf_path,
                    .Zig => Kernel.zig.elf_path,
                },
                null);
            kernel_size = @intCast(u32, self.file_buffer.items.len - kernel_offset);
            var kernel_size_writer = @ptrCast(*align(1) u32, &self.file_buffer.items[MBR.Offset.kernel_size]);
            kernel_size_writer.* = kernel_size;

            self.align_buffer(0x200);

            try self.copy_file(Desktop.out_elf_path, null);

            // @TODO: continue writing to the disk
            print("Writing image disk to {s}\n", .{Image.final_path});
            self.file_buffer.items.len = self.file_buffer.capacity;
            print("Disk size: {}\n", .{self.file_buffer.items.len});
            try std.fs.cwd().writeFile(Image.final_path, self.file_buffer.items[0..]);
        }

        fn align_buffer(self: *Self, alignment: u64) void
        {
            self.file_buffer.items.len = std.mem.alignForward(self.file_buffer.items.len, alignment);
        }

        fn fix_partition(partitions: *align(1) [16]u32) void
        {
            const heads_per_cylinder = 256;
            const sectors_per_track = 63;
            const partition_offset_cylinder = (partitions[2] / sectors_per_track) / heads_per_cylinder;
            const partition_offset_head = (partitions[2] / sectors_per_track) % heads_per_cylinder;
            const partition_offset_sector = (partitions[2] % sectors_per_track) + 1;
            const partition_size_cylinder = (partitions[3] / sectors_per_track) / heads_per_cylinder;
            const partition_size_head = (partitions[3] / sectors_per_track) % heads_per_cylinder;
            const partition_size_sector = (partitions[3] % sectors_per_track) + 1;

            partitions[0] |= (partition_offset_head << 8) | (partition_offset_sector << 16) | (partition_offset_cylinder << 24) | ((partition_offset_cylinder >> 8) << 16);
            partitions[1] |= (partition_size_head << 8) | (partition_size_sector << 16) | (partition_size_cylinder << 24) | ((partition_size_cylinder >> 8) << 16);
        }

        fn create(b: *Builder) void
        {
            var self = b.allocator.create(Self) catch @panic("out of memory");
            self.* = Self
            {
                .step = Step.init(.custom, "bios", b.allocator, Self.build),
                .builder = b,
                .file_buffer = undefined,
            };

            self.step.dependOn(b.default_step);

            if (Kernel.strip_symbols(b)) |strip_symbols|
            {
                self.step.dependOn(&strip_symbols.step);
            }

            step = b.step("bios", "Create BIOS image");
            step.dependOn(&self.step);
        }

        fn copy_file(self: *Self, filename: []const u8, expected_length: ?u64) !void
        {
            print("Copying file {s} to file buffer at offset {}...\n", .{filename, self.file_buffer.items.len});

            const file = try std.fs.cwd().openFile(filename, .{});
            const file_size = try file.getEndPos();
            const file_buffer_offset = self.file_buffer.items.len;
            const space_left = Image.size - file_buffer_offset;
            assert(file_size < space_left);
            self.file_buffer.items.len += file_size;
            const written_byte_count = try file.readAll(self.file_buffer.items[file_buffer_offset..]);
            assert(written_byte_count == file_size);
            if (expected_length) |file_expected_length| assert(written_byte_count <= file_expected_length);
            print("Done! Copied {} bytes.\n", .{written_byte_count});
        }

        fn append_to_file(self: *Self, data: []const u8) void
        {
            print("Copying {} bytes to file buffer...\n", .{data.len});
            self.file_buffer.appendSliceAssumeCapacity(data);
        }
    };
};

const UEFI = struct
{
    const app_out_path = Bootloader.output_dir ++ Bootloader.out_file ++ ".efi";
    const asm_out_path = "zig-cache/uefi_asm.bin";
    const OVMF_path = "binaries/OVMF.fd";

    const Bootloader = struct
    {
        const src_file = "src/uefi.zig";
        const out_file = "bootx64";
        const output_dir = build_cache_dir;

        const loader_target = CrossTarget
        {
            .cpu_arch = .x86_64,
            .os_tag = .uefi,
            .abi = .msvc,
        };

        fn build(b: *Builder) void
        {
            const uefi_loader = b.addExecutable(out_file, src_file);
            uefi_loader.setTarget(UEFI.Bootloader.loader_target);
            uefi_loader.subsystem = .EfiApplication;
            uefi_loader.setOutputDir(output_dir);
            uefi_loader.red_zone = false;

            const uefi_loader_asm = NASM.build_flat_binary(b, "src/uefi.S", asm_out_path);
            b.default_step.dependOn(&uefi_loader.step);
            b.default_step.dependOn(&uefi_loader_asm.step);
        }
    };

    const Image = struct
    {
        const Self = @This();

        // @TODO: work on non-script build so we can have fast build times
        const script = true;
        const output_file = "uefi_disk.img";
        const partition_tmp_file = "efi_fat32_partition.img";
        const partition_tmp_path = build_cache_dir ++ partition_tmp_file;
        const final_path = build_cache_dir ++ output_file;
        const block_size = 512;
        const block_count = 93750;
        const partition_block_start = 2048;
        const partition_block_end = 93716;
        const files_to_copy = &[_][]const u8
        {
            app_out_path,
            switch (kernel_version)
            {
                .Rust => Kernel.rust.stripped,
                .CPP => Kernel.cpp.elf_path,
                .Zig => Kernel.zig.elf_path,
            },
            Desktop.out_elf_path,
            UEFI.asm_out_path,
        };
        const directories_to_copy_them_to = &[_][]const u8
        {
            "/EFI/BOOT",
            "/",
            "/",
            "/",
        };
        var step: *Step = undefined;

        step: Step,
        builder: *Builder,
        file_buffer: ArrayList(u8),

        fn create(b: *Builder) void
        {
            if (script)
            {
                const script_build = Script
                {
                    .block_size = block_size,
                    .block_count = block_count,
                    .partition_block_start = partition_block_start,
                    .partition_block_end = partition_block_end,
                    .files_to_copy = files_to_copy,
                    .directories_to_copy_them_to = directories_to_copy_them_to,
                };
                script_build.build(b, partition_tmp_path, Image.final_path) catch |err| panic("Failed to do scripted build: {}\n", .{err});
            }
            else
            {
                var self = b.allocator.create(Self) catch @panic("out of memory");
                self.* = Self
                {
                    .step = Step.init(.custom, "uefi", b.allocator, Self.build),
                    .builder = b,
                    .file_buffer = undefined,
                };

                step = &self.step;
                step.dependOn(b.default_step);
            }
        }

        // @INFO: this is just for scripting builds, which are the only one available right now

        // @INFO: this is just for non-script builds, which are not mature yet
        fn build(_step: *Step) !void
        {
            const self = @fieldParentPtr(Self, "step", _step);
            _ = self;
            unreachable;
        }

        const Script = struct
        {
            block_size: u64,
            block_count: u64,
            partition_block_start: u64,
            partition_block_end: u64,
            files_to_copy: []const []const u8,
            directories_to_copy_them_to: []const []const u8,

            fn build(self: *const Script, b: *Builder, comptime partition_image_str: []const u8, comptime disk_image_str: []const u8) !void
            {
                const partition_block_count = self.partition_block_end - self.partition_block_start + 1;
                // Partition
                const partition_step = blk:
                {
                    const partition_create_zero_blob = b.addSystemCommand(
                        &[_][]const u8
                        {
                            "dd",
                            "if=/dev/zero",
                            "of=" ++ partition_image_str,
                            comptimePrint("bs={}", .{block_size}),
                            try allocPrint(b.allocator, "count={}", .{partition_block_count}),
                        }
                    );

                    const partition_format = b.addSystemCommand(
                        &[_][]const u8
                        {
                            "mformat",
                            "-i",
                            partition_image_str,
                            "-F",
                            "::",
                        }
                    );
                    partition_format.step.dependOn(&partition_create_zero_blob.step);

                    const file_count = self.files_to_copy.len;
                    assert(file_count == self.directories_to_copy_them_to.len);

                    var directory_steps = ArrayList(*Step).init(b.allocator);
                    var created_directories = ArrayList([]const u8).init(b.allocator);
                    var previous_steps = ArrayList(*Step).init(b.allocator);

                    for (self.directories_to_copy_them_to) |directory|
                    {
                        if (!std.mem.eql(u8, directory, "/"))
                        {
                            var composed = false;

                            for (directory) |db, di|
                            {
                                if (db == '/')
                                {
                                    if (di != 0)
                                    {
                                        composed = true;
                                        const d = directory[0..di];

                                        if (allocate_if_not_found(b, partition_image_str, &created_directories, d)) |partition_create_directory|
                                        {
                                            partition_create_directory.dependOn(&partition_create_zero_blob.step);
                                            partition_create_directory.dependOn(&partition_format.step);

                                            for (previous_steps.items) |previous_step|
                                            {
                                                partition_create_directory.dependOn(previous_step);
                                            }

                                            directory_steps.append(partition_create_directory) catch unreachable;
                                            previous_steps.append(partition_create_directory) catch unreachable;
                                        }
                                    }
                                }
                            }

                            if (allocate_if_not_found(b, partition_image_str, &created_directories, directory)) |partition_create_directory|
                            {
                                partition_create_directory.dependOn(&partition_create_zero_blob.step);
                                partition_create_directory.dependOn(&partition_format.step);

                                for (previous_steps.items) |previous_step|
                                {
                                    partition_create_directory.dependOn(previous_step);
                                }

                                directory_steps.append(partition_create_directory) catch unreachable;
                                previous_steps.append(partition_create_directory) catch unreachable;
                            }
                        }
                    }

                    const strip_symbols = Kernel.strip_symbols(b);

                    assert(created_directories.items.len == directory_steps.items.len);

                    var previous_command_step: *Step = undefined;

                    for (self.files_to_copy) |file, i|
                    {
                        const directory = self.directories_to_copy_them_to[i];

                        const partition_copy_efi_file = b.addSystemCommand(
                            &[_][]const u8
                            {
                                "mcopy",
                                "-i",
                                partition_image_str,
                                file,
                                try allocPrint(b.allocator, "::{s}", .{directory}),
                            }
                        );
                        partition_copy_efi_file.step.dependOn(b.default_step);
                        if (strip_symbols) |strip| partition_copy_efi_file.step.dependOn(&strip.step);
                        partition_copy_efi_file.step.dependOn(&partition_create_zero_blob.step);
                        partition_copy_efi_file.step.dependOn(&partition_format.step);

                        if (!std.mem.eql(u8, directory, "/"))
                        {
                            var found = false;
                            for (created_directories.items) |cd, cdi|
                            {
                                if (std.mem.eql(u8, directory, cd))
                                {
                                    partition_copy_efi_file.step.dependOn(directory_steps.items[cdi]);
                                    found = true;
                                    break;
                                }
                            }

                            if (!found) panic("Unable to get directory step\n", .{});
                        }

                        if (i != 0)
                        {
                            partition_copy_efi_file.step.dependOn(previous_command_step);
                        }

                        previous_command_step = &partition_copy_efi_file.step;
                    }

                    assert(@ptrToInt(previous_command_step) != 0);

                    break :blk previous_command_step;
                };

                // Disk
                const disk_step = blk:
                {
                    const disk_create_zero_blob = b.addSystemCommand(
                        &[_][]const u8
                        {
                            "dd",
                            "if=/dev/zero",
                            "of=" ++ disk_image_str,
                            comptimePrint("bs={}", .{block_size}),
                            comptimePrint("count={}", .{block_count}),
                        }
                    );

                    const disk_make_label = b.addSystemCommand(
                        &[_][]const u8
                        {
                            "parted",
                            disk_image_str,
                            "-s",
                            "-a",
                            "minimal",
                            "mklabel",
                            "gpt",
                        }
                    );
                    disk_make_label.step.dependOn(&disk_create_zero_blob.step);

                    const disk_make_partition = b.addSystemCommand(
                        &[_][]const u8
                        {
                            "parted",
                            disk_image_str,
                            "-s",
                            "-a",
                            "minimal",
                            "mkpart",
                            "EFI",
                            "FAT32",
                            try allocPrint(b.allocator, "{}s", .{self.partition_block_start}),
                            try allocPrint(b.allocator, "{}s", .{self.partition_block_end}),
                        }
                    );
                    disk_make_partition.step.dependOn(&disk_make_label.step);

                    const disk_toggle_boot = b.addSystemCommand(
                        &[_][]const u8
                        {
                            "parted",
                            disk_image_str,
                            "-s",
                            "-a",
                            "minimal",
                            "toggle",
                            "1",
                            "boot",
                        }
                    );
                    disk_toggle_boot.step.dependOn(&disk_make_partition.step);

                    const partition_write_into_disk = b.addSystemCommand(
                        &[_][]const u8
                        {
                            "dd",
                            comptimePrint("if={s}", .{partition_image_str}),
                            comptimePrint("of={s}", .{disk_image_str}),
                            comptimePrint("bs={}", .{block_size}),
                            try allocPrint(b.allocator, "count={}", .{partition_block_count}),
                            comptimePrint("seek={}", .{partition_block_start}),
                            "conv=notrunc",
                        }
                    );

                    partition_write_into_disk.step.dependOn(partition_step);
                    partition_write_into_disk.step.dependOn(&disk_toggle_boot.step);

                    break :blk &partition_write_into_disk.step;
                };

                Image.step = b.step("uefi", "Create disk and partition images from scratch");
                Image.step.dependOn(disk_step);
            }

            fn allocate_if_not_found(b: *Builder, partition_image_str: []const u8, created_directories: *ArrayList([]const u8), dir: []const u8) ?*Step
            {
                var found = false;
                for (created_directories.items) |cd|
                {
                    if (std.mem.eql(u8, dir, cd))
                    {
                        found = true;
                        break;
                    }
                }

                if (!found)
                {
                    const make_dir = b.addSystemCommand(
                        &[_][]const u8
                        {
                            "mmd",
                            "-i",
                            partition_image_str,
                            allocPrint(b.allocator, "::{s}", .{dir}) catch unreachable,
                        }
                    );

                    created_directories.append(dir) catch unreachable;

                    return &make_dir.step;
                }

                return null;
            }
        };
    };
};

const Desktop = struct
{
    const build_cpp = false;
    const exe_name = "desktop.elf";
    const cpp_src_file = "src/desktop.cpp";
    const zig_src_file = "src/desktop.zig";
    const asm_src_file = "src/desktop.S";
    const asm_out_file = build_cache_dir ++ "desktop_asm.o";
    const out_elf_path = build_cache_dir ++ exe_name;

    fn build(b: *Builder) void
    {
        const desktop = b.addExecutable(exe_name, if (build_cpp) null else zig_src_file);
        desktop.setOutputDir(build_cache_dir);
        desktop.setBuildMode(b.standardReleaseOptions());
        desktop.setTarget(cross_target);

        if (build_cpp)
        {
            desktop.addCSourceFile(cpp_src_file, common_c_flags);
            NASM.build_object(b, desktop, asm_src_file, asm_out_file);
        }

        b.default_step.dependOn(&desktop.step);
    }
};

const qemu_base_command_str = &[_][]const u8
{
    "qemu-system-x86_64",
    "-device", "ich9-ahci,id=ahci",
    "-device", "ide-hd,drive=mydisk,bus=ahci.0",
    "-no-reboot", "-no-shutdown",
    "-M", "q35", "-cpu", "Haswell",
    "-m", "4096",
    //"-serial", "stdio",
    "-d", "int,cpu_reset,in_asm",
    "-D", "logging.txt",
    //"-d", "guest_errors,int,cpu,cpu_reset,in_asm"
};

const qemu_command_str = blk:
{
    const result = qemu_base_command_str ++ &[_][]const u8 { "-drive", "file=" ++ final_image ++ ",if=none,id=mydisk,format=raw,media=disk,index=0" };

    if (loader == .UEFI)
        break :blk (result ++
            &[_][]const u8
            {
                "-bios",
                UEFI.OVMF_path,
            })
    else break :blk result;
};

const Debug = struct
{
    const Self = @This();
    step: Step,
    b: *Builder,

    fn create(b: *Builder, image_step: *Step) *Self
    {
        var self = b.allocator.create(Self) catch @panic("out of memory");
        self.* = Self
        {
            .step = Step.init(.custom, "debug", b.allocator, Self.build),
            .b = b,
        };

        self.step.dependOn(image_step);

        return self; 
    }

    fn build(given_step: *Step) !void
    {
        const self = @fieldParentPtr(Self, "step", given_step);
        const gdb_script = comptimePrint(comptime
                \\set disassembly-flavor intel
                \\symbol-file {s}
                \\b _start
                \\b panic
                \\b KernelInitialise
                \\b KernelPanic
                \\b KernelMain
                \\b kernel.panic
                \\b kernel.panic_raw
                \\b kernel.TODO
                \\b kernel.main_thread
                \\b main_thread
                \\b init
                \\target remote localhost:1234
                \\c
                ,
        .{
            comptime switch (kernel_version)
            {
                .CPP => Kernel.cpp.elf_path,
                .Rust => Kernel.rust.elf_path,
                .Zig => Kernel.zig.elf_path,
            }
        });
        
        const gdb_script_path = "zig-cache/gdb_script";
        try std.fs.cwd().writeFile(gdb_script_path, gdb_script);
        const first_pid = try std.os.fork();
        if (first_pid == 0)
        {
            const debugger = try std.ChildProcess.init(
                &[_][]const u8 { "gf2", "-x", gdb_script_path }, self.b.allocator);
            _ = try debugger.spawnAndWait();
        }
        else
        {
            const qemu_debug_command = 
                qemu_command_str ++
                &[_][]const u8 { "-s" } ++
                &[_][]const u8 { "-S" };
            const qemu = try std.ChildProcess.init(qemu_debug_command, self.b.allocator);
            try qemu.spawn();

            _ = std.os.waitpid(first_pid, 0);
            _ = try qemu.kill();
        }
    }
};

const loader = Loader.BIOS;
const kernel_version = Kernel.Version.Zig;
const final_image = switch (loader)
{
    .BIOS => BIOS.Image.final_path,
    .UEFI => UEFI.Image.final_path,
};

pub fn build(b: *Builder) !void
{
    // Default build command
    {
        switch (loader)
        {
            .BIOS => BIOS.Bootloader.build(b),
            .UEFI => UEFI.Bootloader.build(b),
        }
        switch (kernel_version)
        {
            .CPP  => Kernel.CPP.build(b),
            .Rust => Kernel.Rust.build(b),
            .Zig  => Kernel.Zig.build(b),
        }
        Desktop.build(b);
    }

    switch (loader)
    {
        // "bios" step
        .BIOS => BIOS.Image.create(b),
        // "uefi" step
        .UEFI => UEFI.Image.create(b),
    }

    const image_step = switch (loader)
    {
        .BIOS => BIOS.Image.step,
        .UEFI => UEFI.Image.step,
    };

    // "run" step
    {
        const run_command = b.addSystemCommand(qemu_command_str);
        run_command.step.dependOn(image_step);
        const run_step = b.step("run", "Run the bootloader");
        run_step.dependOn(&run_command.step);
    }

    // "debug" step
    {
        const debug_step = Debug.create(b, image_step);
        const debug_step_named = b.step("debug", "The debugger GF and QEMU are launched in order to debug the kernel"); 
        debug_step_named.dependOn(&debug_step.step);
    }

    // "clear" step
    {
        const remove_cache = b.addRemoveDirTree(build_cache_dir);
        const remove_bin = b.addRemoveDirTree(build_output_dir);
        const clear_step = b.step("clear", "Clear the cache and binary directories");
        clear_step.dependOn(&remove_cache.step);
        clear_step.dependOn(&remove_bin.step);
    }
}
