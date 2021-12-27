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
        const size: u64 = 64 * a_megabyte;
        const memory_size: u64 = size;
        const output_file = "bios_disk.img";
        const final_path = build_cache_dir ++ output_file;
        const Self = @This();
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
    const Bootloader = struct
    {
        const src_file = "src/uefi.zig";
        const out_file = "bootx64";
        const output_dir = build_cache_dir;
        const app_out_path = output_dir ++ out_file ++ ".efi";

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

            b.default_step.dependOn(&uefi_loader.step);
        }
    };

    const Image = struct
    {
        const Self = @This();
        const output_file = "uefi_disk.img";
        const final_path = build_cache_dir ++ output_file;
        var step: *Step = undefined;

        step: Step,
        builder: *Builder,
        file_buffer: ArrayList(u8),

        fn create(b: *Builder) void
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

        fn build(_step: *Step) !void
        {
            const self = @fieldParentPtr(Self, "step", _step);
            _ = self;
            unreachable;
        }
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

    const qemu_command_str = &[_][]const u8
    {
        "qemu-system-x86_64",
        "-drive", "file=" ++ 
            switch (loader)
            {
                .BIOS => BIOS.Image.final_path,
                .UEFI => UEFI.Image.final_path,
            }
            ++ ",if=none,id=mydisk,format=raw,media=disk,index=0",
        "-device", "ich9-ahci,id=ahci",
        "-device", "ide-hd,drive=mydisk,bus=ahci.0",
        "-no-reboot", "-no-shutdown", "-M", "q35", "-cpu", "Haswell",
        "-serial", "stdio",
        "-d", "int,cpu_reset,in_asm",
        //"-D", "logging.txt",
        //"-d", "guest_errors,int,cpu,cpu_reset,in_asm"
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
