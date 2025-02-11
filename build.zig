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
pub fn createCmdScript(b: *std.Build, comptime cmds: anytype) ?*std.Build.Step {
    var lastStep: ?*std.Build.Step = null;

    inline for (cmds) |cmd| {
        const cmd_slice = cmd[0..];
        const cmdStep = b.addSystemCommand(cmd_slice);
        if (lastStep) |prev| {
            cmdStep.step.dependOn(prev);
        }
        lastStep = &cmdStep.step;
    }

    return lastStep;
}

fn fetchLinuxKernel(b: *Build) *step {
    return createCmdScript(b, .{ //
        [_][]const u8{ "wget", KERNEL_URL },
        [_][]const u8{ "tar", "xvf", KERNEL_TAR },
        [_][]const u8{ "rm", "-rf", KERNEL_TAR },
        [_][]const u8{ "mv", KERNEL_NAME, KERNEL_DIR },
    }) orelse @panic("failed to create the fetchLinuxKernel script");
}

fn buildKernel(b: *Build) *step {
    return createCmdScript(b, .{ //
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

// run the kernel in qemu
// you can render in the tty with -Dtty
fn runSteps(b: *Build) *step {
    const run = b.step("run", "run qemu with the custom linux kernel");
    const tty_enabled = b.option(bool, "tty", "Enable TTY mode") orelse false;

    var qemu_cmd: []const []const u8 = undefined;
    if (tty_enabled == false) {
        qemu_cmd = &[_][]const u8{ "qemu-system-x86_64", "-kernel", KERNEL, "-initrd", INITRAMFS };
    } else {
        qemu_cmd = &[_][]const u8{ "qemu-system-x86_64", "-kernel", KERNEL, "-initrd", INITRAMFS, "-append", "console=ttyS0" };
    }

    run.dependOn(&b.addSystemCommand(qemu_cmd).step);

    return run;
}

fn cleanKernel(b: *Build) *step {
    const clean = b.step("clean-kernel", "rm all the file of the kernel install");
    const cmds = createCmdScript(b, .{ //
        [_][]const u8{ "rm", "-rf", KERNEL_DIR },
    }) orelse @panic("failed to create the cleanKernel script");

    clean.dependOn(cmds);

    return clean;
}

pub fn build(b: *Build) void {
    const exe = b.addExecutable(.{
        .name = NAME,
        .root_source_file = b.path(ENTRY_FILE),
        .target = b.host,
    });

    b.installArtifact(exe);

    const kbuild = buildKernelSteps(b);
    const run = runSteps(b);
    run.dependOn(kbuild);

    _ = cleanKernel(b);
}
