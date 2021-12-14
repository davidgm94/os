const std = @import("std");

const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;
const Target = std.Target;
const FileSource = std.build.FileSource;
const Step = std.build.Step;
const RunStep = std.build.RunStep;
const LibExeObjStep = std.build.LibExeObjStep;

const ArrayList = std.ArrayList;
const print = std.debug.print;
const assert = std.debug.assert;

const build_rust = true;
const rust_kernel_elf_path = "/home/david/git/os/target/rust_target/debug/renaissance-os";

pub fn build(b: *std.build.Builder) !void
{
    const mbr = nasm_compile_binary(b, mbr_source_file, mbr_output_path);
    b.default_step.dependOn(&mbr.step);

    const bios_stage_1 = nasm_compile_binary(b, bios_stage_1_source_file, bios_stage_1_output_path);
    b.default_step.dependOn(&bios_stage_1.step);

    const bios_stage_2 = nasm_compile_binary(b, bios_stage_2_source_file, bios_stage_2_output_path);
    b.default_step.dependOn(&bios_stage_2.step);

    if (build_rust)
    {
        const cargo_cmd = b.addSystemCommand(&[_][]const u8 { "cargo", "build" });
        b.default_step.dependOn(&cargo_cmd.step);

    }
    else
    {
        const kernel = build_kernel(b);
        b.default_step.dependOn(&kernel.step);
    }

    const desktop = build_desktop(b);
    b.default_step.dependOn(&desktop.step);

    var disk_image = try DiskImage.create(b);
    disk_image.step.dependOn(b.default_step);

    const install_disk_image = b.addInstallBinFile(FileSource.relative(disk_image_output_path), disk_image_output_file);
    install_disk_image.step.dependOn(&disk_image.step);

    const qemu_command_str =
            &[_][]const u8
            {
                "qemu-system-x86_64",
                "-drive", "file=" ++ final_disk_image ++ ",if=none,id=mydisk,format=raw,media=disk,index=0",
                "-device", "ich9-ahci,id=ahci",
                "-device", "ide-hd,drive=mydisk,bus=ahci.0",
                "-no-reboot", "-no-shutdown", "-M", "q35", "-cpu", "Haswell",
                "-serial", "stdio",
                "-d", "int,cpu_reset,in_asm",
                //"-D", "logging.txt",
                //"-d", "guest_errors,int,cpu,cpu_reset,in_asm"
            };

    const run_command = b.addSystemCommand(qemu_command_str);
    run_command.step.dependOn(&install_disk_image.step);
    const run_step = b.step("run", "Run the bootloader");
    run_step.dependOn(&run_command.step);

    const qemu_debug_command = qemu_command_str ++ &[_][]const u8 { "-s" } ++
&[_][]const u8 { "-S" };
    const debug_command = b.addSystemCommand(qemu_debug_command);
    debug_command.step.dependOn(&install_disk_image.step);

    const debug_step = b.step("debug", "Debug the kernel");
    debug_step.dependOn(&debug_command.step);

    // Add clear
    const remove_cache = b.addRemoveDirTree("zig-cache");
    const remove_bin = b.addRemoveDirTree("zig-out");
    const clear_step = b.step("clear", "Clear the cache and binary directories");
    clear_step.dependOn(&remove_cache.step);
    clear_step.dependOn(&remove_bin.step);
}

const build_cache_dir = "zig-cache/";
const build_output_dir = "zig-out/bin/";
const bios_source_root_dir = "src/boot/x86/";

const mbr_source_file = bios_source_root_dir ++ "mbr.S";
const mbr_output_file = "mbr.bin";
const mbr_output_path = build_cache_dir ++ mbr_output_file;

const bios_stage_1_source_file = bios_source_root_dir ++ "bios_stage_1.S";
const bios_stage_1_output_file = "bios_stage_1.bin";
const bios_stage_1_output_path = build_cache_dir ++ bios_stage_1_output_file;

const bios_stage_2_source_file = bios_source_root_dir ++ "bios_stage_2.S";
const bios_stage_2_output_file = "bios_stage_2.bin";
const bios_stage_2_output_path = build_cache_dir ++ bios_stage_2_output_file;

const kernel_source_file = "src/kernel/main.zig";
const kernel_output_file = "kernel.elf";
const kernel_output_path = build_cache_dir ++ kernel_output_file;
const kernel_linker_script_path = "src/linker.ld";

const disk_image_output_file = "disk.img";
const disk_image_output_path = build_cache_dir ++ disk_image_output_file;

    const final_disk_image =
        if (true)
            build_output_dir ++ disk_image_output_file
        else 
            "/home/david/git/essence/bin/drive";

fn nasm_compile_elf_object(builder: *Builder, executable: *std.build.LibExeObjStep, comptime src: []const u8, comptime out: []const u8) void
{
    const base_nasm_command = &[_][]const u8 { "nasm", "-felf64", "-g", "-F", "dwarf", src, "-o", out };
    const nasm_command = builder.addSystemCommand(base_nasm_command);
    executable.addObjectFile(out);
    executable.step.dependOn(&nasm_command.step);
}

const c_flags = &[_][]const u8
{
    "-ffreestanding",
    "-fno-exceptions",
    "-Wall",
    "-Wextra",
};

const cross_target = CrossTarget
{
    .cpu_arch = .x86_64,
    .os_tag = .freestanding,
    .abi = .none,
};

fn build_kernel(b: *Builder) *LibExeObjStep
{
    const kernel = b.addExecutable(kernel_output_file, null);
    kernel.red_zone = false;
    kernel.code_model = .kernel;
    kernel.disable_stack_probing = true;

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

        const c_source_files = &[_][]const u8
        {
            "src/kernel.cpp",
        };

        kernel.addCSourceFiles(c_source_files, c_flags);

    const compile_rust_kernel = b.addSystemCommand(&[_][]const u8 { "cargo", "build" });
    kernel.step.dependOn(&compile_rust_kernel.step);
    //kernel.addLibPath("rust_target/target/debug");
    //kernel.linkSystemLibrary("renaissance-os");
    kernel.addObjectFile("target/rust_target/debug/librenaissance_os.a");
    nasm_compile_elf_object(b, kernel, "src/x86_64.S", "zig-cache/kernel_x86.o");
    kernel.setMainPkgPath("src");
    kernel.setLinkerScriptPath(FileSource.relative(kernel_linker_script_path));
    kernel.setOutputDir(build_cache_dir);

    return kernel;
}

fn build_desktop(b: *Builder) *LibExeObjStep
{
    const build_cpp = false;
    const desktop_exe_name = "desktop.elf";
    const desktop = if (build_cpp) b.addExecutable(desktop_exe_name, null) else b.addExecutable(desktop_exe_name, "src/desktop.zig");
    desktop.setOutputDir("zig-cache");
    desktop.setBuildMode(b.standardReleaseOptions());
    desktop.setTarget(cross_target);

    if (build_cpp)
    {
        desktop.addCSourceFile("src/desktop.cpp", c_flags);
        nasm_compile_elf_object(b, desktop, "src/desktop.S", "zig-cache/desktop_asm.o");
    }

    return desktop;
}

const a_megabyte = 1024 * 1024;
const disk_size: u64 = 256 * a_megabyte;
const memory_size: u64 = disk_size;

const DiskImage = struct
{
    const Self = @This();

    step: Step,
    builder: *Builder,
    file_buffer: ArrayList(u8),

    fn build(step: *Step) !void
    {
        const self = @fieldParentPtr(Self, "step", step);
        const MBR = @import("src/boot/x86/mbr.zig");

        self.file_buffer = try ArrayList(u8).initCapacity(self.builder.allocator, disk_size);
        self.file_buffer.items.len = disk_size;
        std.mem.set(u8, self.file_buffer.items, 0);
        self.file_buffer.items.len = 0;

        print("Reading MBR file...\n", .{});
        try self.copy_file(mbr_output_path, MBR.length);
        var partitions = @intToPtr(*align(1) [16]u32, @ptrToInt(&self.file_buffer.items[MBR.Offset.partition]));
        partitions[0] = 0x80; // bootable
        partitions[1] = 0x83; // type
        partitions[2] = 0x800; // offset
        partitions[3] = @intCast(u32, disk_size / 0x200) - 0x800; // sector count
        fix_partition(partitions);

        // fill out 0s for this space
        const blank_size = 0x800 * 0x200 - 0x200;
        self.file_buffer.items.len += blank_size;

        const bios_stage_1_max_length = 0x200;
        print("Reading BIOS stage 1 file...\n", .{});
        try self.copy_file(bios_stage_1_output_path, bios_stage_1_max_length);
        print("File offset: {}\n", .{self.file_buffer.items.len});

        const bios_stage_2_max_length = 0x200 * 15;
        const file_offset = self.file_buffer.items.len;
        print("Reading BIOS stage 2 file...\n", .{});
        try self.copy_file(bios_stage_2_output_path, bios_stage_2_max_length);
        const kernel_offset = file_offset + bios_stage_2_max_length;
        self.file_buffer.items.len = kernel_offset;
        print("File offset: {}\n", .{self.file_buffer.items.len});
        var kernel_size: u32 = 0;
        try self.copy_file(if (build_rust) rust_kernel_elf_path else kernel_output_path, null);
        kernel_size = @intCast(u32, self.file_buffer.items.len - kernel_offset);
        var kernel_size_writer = @ptrCast(*align(1) u32, &self.file_buffer.items[MBR.Offset.kernel_size]);
        kernel_size_writer.* = kernel_size;

        self.align_buffer(0x200);

        try self.copy_file("zig-cache/desktop.elf", null);

        // @TODO: continue writing to the disk
        print("Writing image disk to {s}\n", .{disk_image_output_path});
        self.file_buffer.items.len = self.file_buffer.capacity;
        print("Disk size: {}\n", .{self.file_buffer.items.len});
        try std.fs.cwd().writeFile(disk_image_output_path, self.file_buffer.items[0..]);
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

    fn create(b: *Builder) !*Self
    {
        var self = b.allocator.create(Self) catch @panic("out of memory");
        self.* = Self
        {
            .step = Step.init(.custom, "image", b.allocator, Self.build),
            .builder = b,
            .file_buffer = undefined,
            
        };

        return self;
    }

    fn copy_file(self: *Self, filename: []const u8, expected_length: ?u64) !void
    {
        print("Copying file {s} to file buffer at offset {}...\n", .{filename, self.file_buffer.items.len});

        const file = try std.fs.cwd().openFile(filename, .{});
        const file_size = try file.getEndPos();
        const file_buffer_offset = self.file_buffer.items.len;
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

fn nasm_compile_binary(builder: *Builder, comptime src: []const u8, comptime out: []const u8) *RunStep
{
    const base_nasm_command = &[_][]const u8 { "nasm", "-fbin", src, "-o", out };
    return builder.addSystemCommand(base_nasm_command);
}
