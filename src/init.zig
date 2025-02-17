//! The init system.
const std = @import("std");
const os = std.os.linux;
const consts = @import("consts.zig");
const wrapErrno = @import("errno.zig").wrapErrno;
const dbg = @import("debug.zig");
const log = std.log.scoped(.init);
const argsModule = @import("args.zig");
const parseKernelArgs = argsModule.parseKernelArgs;
const deinitKernelArgs = argsModule.deinitKernelArgs;

const InitSystem = struct {
    allocator: std.mem.Allocator,
    args: ?std.StringHashMap(?[]u8) = null,
};

fn noop(_: *InitSystem) !void {
    log.debug("@ noop", .{});
}

/// Sets-up common signal handlers.
fn setupSignalHandlers(_: *InitSystem) !void {}

/// Disables the Ctrl-Alt-Del syskey instantly rebooting the system.
/// Instead, it sends a SIGINT to the init process (that's us!!!).
fn disableCADSyskey(_: *InitSystem) !void {
    const err = os.reboot(os.LINUX_REBOOT.MAGIC1.MAGIC1, os.LINUX_REBOOT.MAGIC2.MAGIC2, os.LINUX_REBOOT.CMD.CAD_OFF, null);
    _ = try wrapErrno(err);
}

/// Creates and mounts the common kernel-related filesystems.
///
/// This includes: `/dev`, `/proc`, `/sys`, `/run`, `/tmp`.
fn mountKernelVirtualFileSystems(_: *InitSystem) !void {
    const slog = std.log.scoped(.mount);
    const paths = .{ "/dev", "/proc", "/sys", "/run", "/tmp", "/var" };
    inline for (paths) |path| {
        try std.fs.cwd().makePath(path);
    }

    const mounts = .{
        .{ "dev", "/dev", "devtmpfs", 0, 0 },
        .{ "proc", "/proc", "proc", 0, 0 },
        .{ "sys", "/sys", "sysfs", 0, 0 },
        .{ "tmpfs", "/tmp", "tmpfs", 0, 0 },
        .{ "run", "/run", "tmpfs", 0, 0 },
        .{ "none", "/sys/kernel/debug", "debugfs", 0, 0 },
        //TODO: check if we need cgroups?
        // .{ "none", "/sys/fs/cgroup", "tmpfs", 0, null },
    };
    inline for (mounts) |mount| {
        slog.debug("+ Mounting {s}", .{mount[1]});
        _ = try wrapErrno(os.mount(mount[0], mount[1], mount[2], mount[3], mount[4]));
    }

    const symlinkPaths = .{
        .{ "/run", "/var/run" },
        .{ "/proc/self/fd", "/dev/fd" },
    };
    inline for (symlinkPaths) |symlink| {
        slog.debug("+ Linking {s} to target {s}", .{ symlink[1], symlink[0] });
        _ = try wrapErrno(os.symlink(symlink[0], symlink[1]));
    }
}

fn parseKernelArguments(system: *InitSystem) !void {
    system.args = parseKernelArgs(system.allocator) catch |err| {
        log.err("Failed to parse kernel args: {s}", .{@errorName(err)});
        return err;
    };

    var it = system.args.?.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.*) |val| {
            log.debug("Parsed kernel arg: {s}={s}", .{ entry.key_ptr.*, val });
            continue;
        }
        log.debug("Parsed kernel arg: {s}", .{entry.key_ptr.*});
    }
}

fn dumpFs(_: *InitSystem) !void {
    try dbg.dumpFilesystemTree(null);
}

/// The true "main" function, which is where all the init stuff happens.
pub fn cowabunga() !void {
    _ = os.setsid();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var initSystem = InitSystem{ .allocator = allocator };
    defer deinitKernelArgs(&initSystem.args);

    // var args = parseKernelArgs(allocator) catch |err| {
    //     log.err("Failed to parse kernel args: {s}", .{@errorName(err)});
    //     return err;
    // };
    // defer deinitKernelArgs(&args);
    // log.debug("Parsed kernel args: {}", .{args});

    const steps = .{
        .{ .msg = "Setup signal handlers", .func = &setupSignalHandlers },
        .{ .msg = "Disable CAD syskey", .func = &disableCADSyskey },
        .{ .msg = "Mount kernel virtual filesystems", .func = &mountKernelVirtualFileSystems },
        .{ .msg = "Parse kernel arguments", .func = &parseKernelArguments },
        .{ .msg = "Integrity check fsroot", .func = &noop },
        .{ .msg = "Mount fsroot and chroot", .func = &noop },
        .{ .msg = "Mount user filesystems", .func = &noop },
        // .{ .msg = "Open /dev/console and /dev/tty0", .func = &noop },
        .{ .msg = "Start xd.aemon", .func = &noop },
        .{ .msg = "Open tty's and login", .func = &noop },
    };

    inline for (steps) |step| {
        log.info("+ Running {s}", .{step.msg});
        const before = std.time.milliTimestamp();

        step.func(&initSystem) catch |err| {
            log.err("! Caught an unexpected error: {s}" ++ (if (consts.debug) ". (debug ignore)" else ""), .{@errorName(err)});
            if (!consts.debug) {
                return err;
            }
        };

        const after = std.time.milliTimestamp();
        log.debug("= Done in {d}ms", .{after - before});
    }

    log.debug("Dropping you to a shell for testing...", .{});
    return error.DropToShell;
    // while (true) {}
}
