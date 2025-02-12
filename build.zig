const std = @import("std");
const Build = std.Build;
const step = Build.Step;

const SRC_DIR = "src/";
const ENTRY_FILE = SRC_DIR ++ "init.zig";
const NAME = "init";

const KERNEL_NAME = "linux-6.6.76";
const KERNEL_DIR = "kernel." ++ KERNEL_NAME;
const KERNEL_TAR = KERNEL_NAME ++ ".tar.xz";
const KERNEL_URL = "https://cdn.kernel.org/pub/linux/kernel/v6.x/" ++ KERNEL_TAR;
const KERNEL = KERNEL_DIR ++ "/arch/x86/boot/bzImage";

const INITRAMFS = "initramfs.cpio";

// create a chain of system command that depend on each other
// b : the base build system
// cmds list of cmd ex .{
//      [_][]const u8{ "echo", "foo" },
//      [_][]const u8{ "echo", "bar" }
// }
//
pub fn createCmdScript(b: *std.Build, cwd: ?*const Build.LazyPath, comptime cmds: anytype) ?*std.Build.Step {
    var lastStep: ?*std.Build.Step = null;

    inline for (cmds) |cmd| {
        const cmd_slice = cmd[0..];
        const cmdStep = b.addSystemCommand(cmd_slice);
        if (cwd) |cwdPath| {
            cmdStep.setCwd(cwdPath.*);
        }
        if (lastStep) |prev| {
            cmdStep.step.dependOn(prev);
        }
        lastStep = &cmdStep.step;
    }

    return lastStep;
}

fn fetchLinuxKernel(b: *Build) *step {
    return createCmdScript(b, null, .{ //
        [_][]const u8{ "wget", KERNEL_URL },
        [_][]const u8{ "tar", "xvf", KERNEL_TAR },
        [_][]const u8{ "rm", "-rf", KERNEL_TAR },
        [_][]const u8{ "mv", KERNEL_NAME, KERNEL_DIR },
    }) orelse @panic("failed to create the fetchLinuxKernel script");
}

fn buildKernel(b: *Build) *step {
    return createCmdScript(b, null, .{ //
        [_][]const u8{ "make", "-C", KERNEL_DIR, "defconfig" },
        [_][]const u8{ "make", "-C", KERNEL_DIR, "-j16" },
    }) orelse @panic("failed to create the buildKernel script");
}

// fetch and build the kernel if not already done
fn buildKernelSteps(b: *Build) *step {
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

pub fn addQemuSystemCommand(b: *Build, initramfsPath: *const Build.LazyPath) *step {
    const qemuRunStep = b.step("run", "run qemu with the custom linux kernel");
    const tty_enabled = b.option(bool, "tty", "Enable TTY mode") orelse false;
    const runStep = step.Run.create(b, "run qemu");
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

fn copyInitramfsStep(b: *Build, exe: *step.Compile) *step.WriteFile {
    const cpyStep = b.addWriteFiles();
    _ = cpyStep.addCopyFile(exe.getEmittedBin(), NAME);
    cpyStep.step.dependOn(&exe.step);
    return cpyStep;
}

fn initRamfsStep(b: *Build, exe: *step.Compile) struct { step: *step, dir: *const Build.LazyPath } {
    const tramfs = b.step("initramfs", "init the tramfs");
    const copyStep = copyInitramfsStep(b, exe);

    const cmds = createCmdScript(b, &copyStep.getDirectory(), .{ //
        [_][]const u8{ "bash", "-c", "echo " ++ NAME ++ " | cpio -H newc -o > " ++ INITRAMFS }, //
        [_][]const u8{ "rm", "-f", NAME },
    }) orelse @panic("failed to create the init tramfs script");
    cmds.dependOn(&copyStep.step);

    tramfs.dependOn(cmds);

    return .{ .step = tramfs, .dir = &copyStep.getDirectory() };
}

fn cleanKernel(b: *Build) *step {
    const clean = b.step("clean-kernel", "rm all the file of the kernel install");
    const cmds = createCmdScript(b, null, .{ //
        [_][]const u8{ "rm", "-rf", KERNEL_DIR },
        [_][]const u8{ "rm", "-f", KERNEL_TAR ++ "*" },
    }) orelse @panic("failed to create the cleanKernel script");

    clean.dependOn(cmds);

    return clean;
}

pub fn build(b: *Build) void {
    const exe = b.addExecutable(.{
        .name = NAME,
        .root_source_file = b.path(ENTRY_FILE),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .none }),
    });
    b.installArtifact(exe);

    const kbuild = buildKernelSteps(b);

    const initRamfs = initRamfsStep(b, exe);

    const run = addQemuSystemCommand(b, initRamfs.dir);
    run.dependOn(kbuild);
    run.dependOn(initRamfs.step);

    _ = cleanKernel(b);
}
