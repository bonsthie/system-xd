//! The init system.
const std = @import("std");
const os = std.os.linux;
const consts = @import("consts.zig");
const errnoToError = @import("errno.zig").errnoToError;

fn noop() !void {}

/// Sets-up common signal handlers.
fn setupSignalHandlers() !void {}

/// Disables the Ctrl-Alt-Del syskey instantly rebooting the system.
/// Instead, it sends a SIGINT to the init process (that's us!!!).
fn disableCADSyskey() !void {
    const err = os.reboot(os.LINUX_REBOOT.MAGIC1.MAGIC1, os.LINUX_REBOOT.MAGIC2.MAGIC2, os.LINUX_REBOOT.CMD.CAD_OFF, null);
    _ = try errnoToError(err);
}

/// Creates and mounts the common kernel-related filesystems.
///
/// This includes: `/dev`, `/proc`, `/sys`, `/run`, `/tmp`.
fn mountKernelVirtualFileSystems() !void {
    const paths = .{ "/dev", "/proc", "/sys", "/run", "/tmp", "/var" };
    inline for (paths) |path| {
        try std.fs.cwd().makePath(path);
    }

    const mounts = .{
        .{ "none", "/dev", "devtmpfs", 0, 0 },
        .{ "none", "/proc", "proc", 0, 0 },
        .{ "none", "/sys", "sysfs", 0, 0 },
        .{ "none", "/tmp", "tmpfs", 0, 0 },
        .{ "none", "/run", "tmpfs", 0, 0 },
        .{ "none", "/sys/kernel/debug", "debugfs", 0, 0 },
        //TODO: check if we need cgroups?
        // .{ "none", "/sys/fs/cgroup", "tmpfs", 0, null },
    };
    inline for (mounts) |mount| {
        _ = try errnoToError(os.mount(mount[0], mount[1], mount[2], mount[3], mount[4]));
    }

    const symlinkPaths = .{
        .{ "/run", "/var/run" },
        .{ "/proc/self/fd", "/dev/fd" },
    };
    inline for (symlinkPaths) |symlink| {
        _ = try errnoToError(os.symlink(symlink[0], symlink[1]));
    }
}

/// The true "main" function, which is where all the init stuff happens.
pub fn cowabunga() !void {
    const log = std.log.scoped(.init);

    const steps = .{
        .{ .msg = "Setup signal handlers", .func = &setupSignalHandlers },
        .{ .msg = "Disable CAD syskey", .func = &disableCADSyskey },
        .{ .msg = "Mount kernel virtual filesystems", .func = &mountKernelVirtualFileSystems },
        .{ .msg = "Mount fsroot as read-only & fsck", .func = &noop },
        .{ .msg = "Mount fsroot somewhere and set root (syscall i think? busybox change_root)", .func = &noop },
        .{ .msg = "Mount /etc/fstab", .func = &noop },
        .{ .msg = "Open /dev/console and /dev/tty0", .func = &noop },
        .{ .msg = "Open tty's and login?", .func = &noop },
        .{ .msg = "Start xd.aemon", .func = &noop },
    };

    inline for (steps) |step| {
        log.debug("+ Running {s}", .{step.msg});
        const time = std.time.milliTimestamp();
        if (consts.debug) {
            step.func() catch |err| {
                log.debug("! Caught an unexpected error: {s}, ignoring since debug mode.", .{@errorName(err)});
            };
        } else {
            try step.func();
            const after = std.time.milliTimestamp();
            log.debug("= Done in {d}ms", .{after - time});
        }
    }

    log.debug("Waiting for a signal...", .{});
    while (true) {}
}
