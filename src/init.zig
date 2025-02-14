//! The init system.
const std = @import("std");
const os = std.os.linux;
const consts = @import("consts.zig");
const errnoToError = @import("errno.zig").errnoToError;

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
    const paths = [_][]const u8{ "/dev", "/proc", "/sys", "/run", "/tmp", "/var" };
    for (paths) |path| {
        try std.fs.cwd().makePath(path);
    }
    _ = try errnoToError(os.mount("none", "/dev", "devtmpfs", 0, 0));
    _ = try errnoToError(os.mount("none", "/proc", "proc", 0, 0));
    _ = try errnoToError(os.mount("none", "/sys", "sysfs", 0, 0));
    _ = try errnoToError(os.mount("none", "/tmp", "tmpfs", 0, 0));
    _ = try errnoToError(os.mount("none", "/run", "tmpfs", 0, 0));
    _ = try errnoToError(os.mount("none", "/sys/kernel/debug", "debugfs", 0, 0));
    _ = try errnoToError(os.symlink("/run", "/var/run"));
    //TODO: check if we need cgroups?
    // _ = try errnoToError(os.mount("none", "/sys/fs/cgroup", "tmpfs", 0, null));
    _ = try errnoToError(os.symlink("/proc/self/fd", "/dev/fd"));
}

/// The true "main" function, which is where all the init stuff happens.
pub fn cowabunga() !void {
    const log = std.log.scoped(.cowabunga);
    log.debug("Cowabunga!", .{});

    const Step = struct {
        msg: []const u8,
        func: *const fn () anyerror!void,
    };
    const steps = [_]Step{
        .{ .msg = "Setup signal handlers", .func = setupSignalHandlers },
        .{ .msg = "Disable CAD syskey", .func = disableCADSyskey },
        .{ .msg = "Mount kernel virtual filesystems", .func = mountKernelVirtualFileSystems },
    };
    for (steps) |step| {
        log.debug("> Running {s}", .{step.msg});
        const time = std.time.milliTimestamp();
        if (consts.debug) {
            step.func() catch |err| {
                log.debug("!> Caught an unexpected error: {s}", .{@errorName(err)});
                continue;
            };
        } else {
            try step.func();
        }
        const after = std.time.milliTimestamp();
        log.debug("< Done in {d}ms", .{after - time});
    }

    log.debug("Waiting for a signal...", .{});
    while (true) {}
}
