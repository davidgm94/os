const std = @import("std");

const Builder = std.build.Builder;
const CrossTarget = std.zig.CrossTarget;
const Target = std.Target;
const FileSource = std.build.FileSource;

pub fn build(b: *std.build.Builder) void
{
    //var kernel = build_kernel(b);
    //build_bios(b, kernel);
    //build_uefi(b, kernel);
    build_bootloader(b);
}

const boot_dir = "src/boot/";
const qemu = "qemu-system-x86_64";

fn build_bios(b: *std.build.Builder, kernel: *std.build.LibExeObjStep) void
{
    const nasm = "nasm";
    const format = "-f bin";
    const bios_source = boot_dir ++ "x86/bios.asm";
    const bios_output = "zig-cache/bios.bin";
    const nasm_command = &[_][]const u8 { nasm, format, bios_source, "-o", bios_output };
    const nasm_step = b.addSystemCommand(nasm_command);
    nasm_step.step.dependOn(&kernel.step);
    b.default_step.dependOn(&nasm_step.step);

    const qemu_command = &[_][]const u8 { qemu, bios_output };
    const run_command = b.addSystemCommand(qemu_command);

    const run = b.step("bios", "Run the kernel");
    run.dependOn(&run_command.step);
}

const uefi_mount_dir = "./zig-out/bin/EFI_MOUNT/";
fn build_uefi(b: *std.build.Builder, kernel: *std.build.LibExeObjStep) void
{
    const uefi_bootloader = blk:
    {
        if (true)
        {
            const uefi_target = std.zig.CrossTarget
            {
                .cpu_arch = .x86_64,
                .os_tag = .uefi,
                .abi = .msvc,
            };

            const uefi_bootloader_name = "bootx64";
            const uefi_build_mode = b.standardReleaseOptions();
            const uefi_main_file = "src/boot/uefi.zig";

            const uefi_bootloader_dir = "EFI/BOOT/";

            const bootloader = b.addExecutable(uefi_bootloader_name, uefi_main_file);
            bootloader.setMainPkgPath("src");
            bootloader.setBuildMode(uefi_build_mode);
            bootloader.setTarget(uefi_target);
            bootloader.force_pic = true;
            bootloader.setOutputDir(uefi_mount_dir ++ uefi_bootloader_dir);
            bootloader.install();

            bootloader.step.dependOn(&kernel.step);
            b.default_step.dependOn(&bootloader.step);

            break :blk bootloader;
        }
        else
        {
            const bootloader = b.addInstallBinFile(std.build.FileSource.relative("uefi"), "EFI_MOUNT/EFI/BOOT/bootx64.efi");
            bootloader.step.dependOn(&kernel.step);
            b.default_step.dependOn(&bootloader.step);

            break :blk bootloader;
        }
    };

    const dst_file ="uefi_loader.bin"; 
    const dst_path ="zig-cache/" ++ dst_file;
    const uefi_loader = b.addSystemCommand(&[_][]const u8 {"nasm", "-fbin", boot_dir ++ "x86/uefi_loader.asm", "-o", dst_path });
    b.default_step.dependOn(&uefi_loader.step);

    const install_uefi_loader = b.addInstallBinFile(std.build.FileSource.relative(dst_path), "EFI_MOUNT/" ++ dst_file);
    install_uefi_loader.step.dependOn(&uefi_loader.step);
    b.default_step.dependOn(&install_uefi_loader.step);
    install_uefi_loader.step.dependOn(&uefi_bootloader.step);

    const ovmf_path = "/usr/share/OVMF/x64/OVMF.fd";
    const bios_selection = "-bios";
    const hdd_selection = "-hdd";
    const vdisk_target = "fat:rw:" ++ uefi_mount_dir;
    const qemu_command = &[_][]const u8 { qemu, bios_selection, ovmf_path, hdd_selection, vdisk_target, "-net", "none", "-serial", "stdio", "-M", "q35", "-cpu", "qemu64", "-enable-kvm", "-no-shutdown", "-no-reboot", "-d", "guest_errors,int,cpu_reset,out_asm,in_asm"};
        //"-s", "-S" };
    const run_command = b.addSystemCommand(qemu_command);
    run_command.step.dependOn(&install_uefi_loader.step);
    const run = b.step("uefi", "Run the kernel");

    run.dependOn(&run_command.step);
}

fn build_kernel(b: *std.build.Builder) *std.build.LibExeObjStep
{
    const kernel_target = std.zig.CrossTarget
    {
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    };

    const kernel_name = "kernel.elf";
    const kernel_build_mode = b.standardReleaseOptions();
    const kernel_main_file = "src/kernel/main.zig";
    const kernel_x86_file = "src/kernel/x86.asm";
    const kernel_x86_obj_file = "kernel_x86.o";
    const kernel_x86_obj_file_path = "zig-cache/" ++ kernel_x86_obj_file;
    const kernel_x86 = b.addSystemCommand(&[_][]const u8 { "nasm", kernel_x86_file, "-felf64", "-Fdwarf", "-o", kernel_x86_obj_file_path });

    const kernel = b.addExecutable(kernel_name, kernel_main_file);
    kernel.addObjectFileSource(std.build.FileSource.relative(kernel_x86_obj_file_path));
    kernel.setLinkerScriptPath(std.build.FileSource.relative("src/kernel/linker.ld"));
    kernel.red_zone = false;
    kernel.setMainPkgPath("src");
    kernel.setBuildMode(kernel_build_mode);
    kernel.setTarget(kernel_target);
    kernel.setOutputDir(uefi_mount_dir);
    kernel.step.dependOn(&kernel_x86.step);
    kernel.install();

    return kernel;
}

fn build_bootloader(b: *std.build.Builder) void
{
    const bios_output_file = "bios.bin";
    const bios_output_path = "zig-cache/" ++ bios_output_file;
    const bootloader = b.addSystemCommand(&[_][]const u8 { "nasm", "-fbin", "src/boot/x86/bios.S", "-o", bios_output_path });
    b.default_step.dependOn(&bootloader.step);

    const bootloader_install = b.addInstallBinFile(FileSource.relative(bios_output_path), bios_output_file);
    bootloader_install.step.dependOn(&bootloader.step);
    b.default_step.dependOn(&bootloader_install.step);

    const bootloader_install_path = "zig-out/bin/" ++ bios_output_file;
    const run_command = b.addSystemCommand(&[_][]const u8 { "qemu-system-x86_64", "-hda", bootloader_install_path, "-d", "guest_errors,int,cpu_reset,in_asm"});
    run_command.step.dependOn(&bootloader_install.step);

    const run_step = b.step("run", "Run the bootloader");
    run_step.dependOn(&run_command.step);
}
