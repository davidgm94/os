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
    const Base = struct
    {
        elf_name: []const u8,
        out_path: []const u8,
        elf_path: []const u8,
    };

    const Version = enum
    {
        Rust,
        CPP,
    };

    const rust = Rust
    {
        .base = Kernel.Base
        {
            .elf_name = Rust.elf_name,
            .out_path = Rust.out_path,
            .elf_path = Rust.out_path ++ Rust.elf_name,
        }
    };

    const cpp = CPP
    {
        .base = Kernel.Base
        {
            .elf_name = CPP.elf_name,
            .out_path = build_cache_dir,
            .elf_path = build_cache_dir ++ CPP.elf_name,
        },
    };

    fn build_kernel_common(b: *Builder, kernel_output_file: []const u8) *LibExeObjStep
    {
        const kernel = b.addExecutable(kernel_output_file, null);
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
        base: Base,

        const elf_name = "rust_kernel.elf";
        const out_path = "target/rust_target/debug/";
        //const rust_kernel_lib_path = rust_out_path ++ "librenaissance_os.a";
        //const rust_kernel_bin_path = rust_out_path ++ "renaissance-os";
        //

        fn build(b: *Builder) void
        {
            const cargo_build = b.addSystemCommand(&[_][]const u8 { "cargo", "build" });
            b.default_step.dependOn(&cargo_build.step);
        }
    };

    const CPP = struct
    {
        base: Base,

        fn build(b: *Builder) void
        {
            const kernel = build_kernel_common(b, cpp.base.elf_name);

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
                    .Rust => Kernel.rust.base.out_path,
                    .CPP => Kernel.cpp.base.out_path,
                },
                null);
            kernel_size = @intCast(u32, self.file_buffer.items.len - kernel_offset);
            var kernel_size_writer = @ptrCast(*align(1) u32, &self.file_buffer.items[MBR.Offset.kernel_size]);
            kernel_size_writer.* = kernel_size;

            self.align_buffer(0x200);

            try self.copy_file("zig-cache/desktop.elf", null);

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

            step = &self.step;
            step.dependOn(b.default_step);
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
            uefi_loader.install();

            b.default_step.dependOn(&uefi_loader.step);
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
        const files_to_copy = &[_][]const u8 { app_out_path };
        const directories_to_copy_them_to = &[_][]const u8 { "/EFI/BOOT" };
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

//pub const mdisk_str = "my_disk.img";
//pub const nmdisk_str = "not_my_disk.img";
//pub const mpartition_str = "my_partition.img";
//pub const nmpartition_str = "not_my_partition.img";

//pub const efi_partition_block_count = efi_partition_end - efi_partition_start + 1;
//pub const directory_to_copy_them_to = &[_][]const u8 { "/EFI/BOOT" };

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
                            try allocPrint(b.allocator, "bs={}", .{block_size}),
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
                    const directory_steps = try b.allocator.alloc(*Step, file_count);

                    var created_directories = ArrayList([]const u8).init(b.allocator);

                    for (self.directories_to_copy_them_to) |directory, i|
                    {
                        var composed = false;

                        var previous_steps = ArrayList(*Step).init(b.allocator);

                        for (directory) |db, di|
                        {
                            if (db == '/' and di != 0)
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

                                    previous_steps.append(partition_create_directory) catch unreachable;
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

                            previous_steps.append(partition_create_directory) catch unreachable;

                            directory_steps[i] = partition_create_directory;

                            if (!composed)
                            {
                                directory_steps[i].dependOn(directory_steps[i - @boolToInt(i != 0)]);
                            }
                        }
                    }

                    var previous_command_step: ?*Step = null;
                    {
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
                            partition_copy_efi_file.step.dependOn(&partition_create_zero_blob.step);
                            partition_copy_efi_file.step.dependOn(&partition_format.step);
                            partition_copy_efi_file.step.dependOn(directory_steps[i]);

                            if (previous_command_step != null)
                            {
                                previous_command_step.?.dependOn(&partition_copy_efi_file.step);
                            }
                            previous_command_step = &partition_copy_efi_file.step;
                        }
                    }

                    break :blk previous_command_step.?;
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
                            try allocPrint(b.allocator, "bs={}", .{block_size}),
                            try allocPrint(b.allocator, "count={}", .{block_count}),
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
                            try allocPrint(b.allocator, "if={s}", .{partition_image_str}),
                            try allocPrint(b.allocator, "of={s}", .{disk_image_str}),
                            try allocPrint(b.allocator, "bs={}", .{block_size}),
                            try allocPrint(b.allocator, "count={}", .{partition_block_count}),
                            try allocPrint(b.allocator, "seek={}", .{partition_block_start}),
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

const loader = Loader.UEFI;
const kernel_version = Kernel.Version.Rust;
const final_image = switch (loader)
{
    .BIOS => BIOS.Image.final_path,
    .UEFI => UEFI.Image.final_path,
};

const qemu_base_command_str = &[_][]const u8
{
    "qemu-system-x86_64",
    "-device", "ich9-ahci,id=ahci",
    "-device", "ide-hd,drive=mydisk,bus=ahci.0",
    "-no-reboot", "-no-shutdown", "-M", "q35", "-cpu", "Haswell",
    "-serial", "stdio",
    "-d", "int,cpu_reset,in_asm",
    //"-D", "logging.txt",
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

pub fn build(b: *Builder) !void
{
    // Default build command
    {
        BIOS.Bootloader.build(b);
        UEFI.Bootloader.build(b);
        Kernel.CPP.build(b);
        Kernel.Rust.build(b);
        Desktop.build(b);
    }

    // "bios" step
    BIOS.Image.create(b);
    // "uefi" step
    UEFI.Image.create(b);

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
        const qemu_debug_command = 
            qemu_command_str ++
            &[_][]const u8 { "-s" } ++
            &[_][]const u8 { "-S" };

        const debug_command = b.addSystemCommand(qemu_debug_command);
        debug_command.step.dependOn(image_step);

        const debug_step = b.step("debug", "Debug the kernel");
        debug_step.dependOn(&debug_command.step);
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
