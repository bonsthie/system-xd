const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const Util = @import("build-system/util.zig");

const SRC_DIR = "src/";
const ENTRY_FILE = SRC_DIR ++ "main.zig";
const NAME = "init";

const INITRAMFS = "initramfs.cpio";

//TODO: Use an alpine or artix image to test
const KERNEL_NAME = "linux-6.6.76";
const KERNEL_DIR = "kernel." ++ KERNEL_NAME;
const KERNEL_TAR = KERNEL_NAME ++ ".tar.xz";
const KERNEL_URL = "https://cdn.kernel.org/pub/linux/kernel/v6.x/" ++ KERNEL_TAR;
const KERNEL = KERNEL_DIR ++ "/arch/x86/boot/bzImage";

fn fetchLinuxKernel(b: *Build) *Step {
    return Util.createCmdScript(b, null, .{ //
        [_][]const u8{ "wget", KERNEL_URL },
        [_][]const u8{ "tar", "xvf", KERNEL_TAR },
        [_][]const u8{ "rm", "-rf", KERNEL_TAR },
        [_][]const u8{ "mv", KERNEL_NAME, KERNEL_DIR },
    }) orelse @panic("failed to create the fetchLinuxKernel script");
}

fn buildKernel(b: *Build) *Step {
    return Util.createCmdScript(b, null, .{ //
        [_][]const u8{ "make", "-C", KERNEL_DIR, "defconfig" },
        [_][]const u8{ "make", "-C", KERNEL_DIR, "-j16" },
    }) orelse @panic("failed to create the buildKernel script");
}

// fetch and build the kernel if not already done
fn buildKernelSteps(b: *Build) *Step {
    const buildKernelStep = b.step("kernel", "fetch and build the linux kernel [" ++ KERNEL_NAME ++ "]");

    _ = std.fs.cwd().statFile(KERNEL) catch {
        const kernelBuildSteps = buildKernel(b);

        _ = std.fs.cwd().statFile(KERNEL_DIR) catch {
            kernelBuildSteps.dependOn(fetchLinuxKernel(b));
        };

        buildKernelStep.dependOn(kernelBuildSteps);
    };
    return buildKernelStep;
}

fn copyInitramfsStep(b: *Build, exe: *Step.Compile) *Step.WriteFile {
    const cpyStep = b.addWriteFiles();
    _ = cpyStep.addCopyFile(exe.getEmittedBin(), NAME);
    cpyStep.step.dependOn(&exe.step);
    return cpyStep;
}

fn initRamfsStep(b: *Build, exe: *Step.Compile) struct { step: *Step, dir: *const Build.LazyPath } {
    const tramfs = b.step("initramfs", "init the tramfs");
    const copyStep = copyInitramfsStep(b, exe);

    const cmds = Util.createCmdScript(b, &copyStep.getDirectory(), .{ //
        [_][]const u8{ "bash", "-c", "echo " ++ NAME ++ " | cpio -H newc -o > " ++ INITRAMFS }, //
        [_][]const u8{ "rm", "-f", NAME },
    }) orelse @panic("failed to create the init tramfs script");
    cmds.dependOn(&copyStep.step);

    tramfs.dependOn(cmds);

    return .{ .step = tramfs, .dir = &copyStep.getDirectory() };
}

fn cleanKernel(b: *Build) *Step {
    const clean = b.step("clean-kernel", "rm all the file of the kernel install");
    const cmds = Util.createCmdScript(b, null, .{ //
        [_][]const u8{ "rm", "-rf", KERNEL_DIR },
        [_][]const u8{ "rm", "-f", KERNEL_TAR ++ "*" },
    }) orelse @panic("failed to create the cleanKernel script");

    clean.dependOn(cmds);

    return clean;
}

pub fn addQemuSystemCommand(b: *Build, initramfsPath: *const Build.LazyPath) *Step {
    const qemuRunStep = b.step("run", "run qemu with the custom linux kernel");
    const tty_enabled = b.option(bool, "tty", "Enable TTY mode") orelse false;
    const runStep = Step.Run.create(b, "run qemu");
    qemuRunStep.dependOn(&runStep.step);

    if (tty_enabled) {
        runStep.addArg("gnome-terminal");
        runStep.addArg("--");
    }
    runStep.addArg("qemu-system-x86_64");
    runStep.addArg("-kernel");
    runStep.addArg(KERNEL); // TODO: Compile the kernel in zig-cache and use addArgFile instead
    runStep.addArg("-initrd");
    runStep.addFileArg(initramfsPath.path(b, INITRAMFS));
    if (tty_enabled) {
        runStep.addArg("-nographic");
        runStep.addArg("-append");
        runStep.addArg("console=ttyS0");
    }
    return qemuRunStep;
}

const target = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .none };

pub fn build(b: *Build) void {
    const exe = b.addExecutable(.{
        .name = NAME,
        .root_source_file = b.path(ENTRY_FILE),
        .target = b.resolveTargetQuery(target),
    });
    b.installArtifact(exe);

    const kbuild = buildKernelSteps(b);

    const initRamfs = initRamfsStep(b, exe);

    const run = addQemuSystemCommand(b, initRamfs.dir);
    run.dependOn(kbuild);
    run.dependOn(initRamfs.step);

    _ = cleanKernel(b);

    const xdCli = b.addExecutable(.{
        .name = "xd",
        .root_source_file = b.path("src/cli/xd.zig"),
        .target = b.resolveTargetQuery(target),
    });
    b.installArtifact(xdCli);
}
