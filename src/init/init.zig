//! The init system.
const std = @import("std");
const zos = @import("os/linux.zig");
const fstab = @import("os/fstab.zig");
const fsck = @import("os/fsck.zig");
const os = std.os.linux;
const dbg = @import("debug.zig");
const log = std.log.scoped(.init);
const argsModule = @import("args.zig");
const process = @import("process.zig");

const consts = @import("xd").consts;

const wrapErrno = @import("os/errno.zig").wrapErrno;
const parseKernelArgs = argsModule.parseKernelArgs;
const deinitKernelArgs = argsModule.deinitKernelArgs;

pub const InitSystem = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    args: ?std.StringHashMap(?[]u8) = null,
    fstab: ?fstab.Fstab = null,
};

fn deinitInitSystem(init: *InitSystem) void {
    deinitKernelArgs(&init.args);
    if (init.fstab) |*f| f.deinit();
}

fn noop(_: *InitSystem) !void {
    log.debug("@ noop", .{});
}

fn createConsole(_: *InitSystem) !void {
    for (1..100) |i| {
        log.debug("Open /dev/console try [{}]", .{i});
        _ = process.newTTYFromName("/dev/console", .read_write) catch |err| {
            log.debug("createConsole error {}", .{err});
        };
    }
    return error.failCreateConsole;
}

/// Sets-up common signal handlers.
fn setupSignalHandlers(_: *InitSystem) !void {}

/// Disables the Ctrl-Alt-Del syskey instantly rebooting the system.
/// Instead, it sends a SIGINT to the init process (that's us!!!).
fn disableCADSyskey(_: *InitSystem) !void {
    const err = os.reboot(.MAGIC1, .MAGIC2, .CAD_OFF, null);
    _ = try wrapErrno(err);
}

/// Creates and mounts the common kernel-related filesystems.
///
/// This includes: `/dev`, `/proc`, `/sys`, `/run`, `/tmp`.
fn mountKernelVirtualFileSystems(init: *InitSystem) !void {
    const slog = std.log.scoped(.mount);
    const paths = .{ "/dev", "/proc", "/sys", "/run", "/tmp", "/var" };
    inline for (paths) |path| {
        const file = try std.Io.Dir.createFileAbsolute(init.io, path, .{});
        // we don't need to use the file
        file.close(init.io);
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
        try zos.mount(mount[0], mount[1], mount[2], mount[3], mount[4]);
    }

    const symlinkPaths = .{
        .{ "/run", "/var/run" },
        .{ "/proc/self/fd", "/dev/fd" },
    };
    inline for (symlinkPaths) |symlink| {
        slog.debug("+ Linking {s} to target {s}", .{ symlink[1], symlink[0] });
        try zos.symlink(symlink[0], symlink[1]);
    }
}

fn setTime(init: *InitSystem) !void {
    const t = std.Io.Clock.now(.real, init.io);
    if (t.toSeconds() > 0) {
        // TODO use t.formatNumber for the print
        std.log.info("time : {}", .{t});
        return;
    }
    std.log.info("time is not set", .{});
    std.log.info("setting default time", .{});
}

fn parseFstab(init: *InitSystem) !void {
    init.fstab = try fstab.loadFstabEntries(init, "/etc/fstab");
}

fn parseKernelArguments(system: *InitSystem) !void {
    system.args = parseKernelArgs(system.io, system.allocator) catch |err| {
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

fn createTTY(_: *InitSystem) !void {
    _ = try process.spawnProcess(&.{ .filename = "/dev/tty1" });
    _ = try process.spawnProcess(&.{ .filename = "/dev/tty2" });
    _ = try process.spawnProcess(&.{ .filename = "/dev/tty3" });
    _ = try process.spawnProcess(&.{ .filename = "/dev/tty4" });
    _ = try process.spawnProcess(&.{ .filename = "/dev/tty5" });
}

const Step = struct {
    msg: []const u8,
    func: *const fn (_: *InitSystem) anyerror!void,
};

pub const phase1Steps = [_]Step{
    .{ .msg = "Setup signal handlers", .func = &setupSignalHandlers },
    .{ .msg = "Disable CAD syskey", .func = &disableCADSyskey },
    .{ .msg = "Mount kernel virtual filesystems", .func = &mountKernelVirtualFileSystems },
    .{ .msg = "Parse kernel arguments", .func = &parseKernelArguments },
    .{ .msg = "Set time", .func = &setTime },
    .{ .msg = "parse initramfs fstab", .func = &parseFstab },
    .{ .msg = "Integrity check fsroot", .func = &noop },
    .{ .msg = "Mount fsroot and chroot", .func = &noop },
    .{ .msg = "execute the second part of the init system", .func = &noop },
};

pub const phase2Steps = [_]Step{
    .{ .msg = "Parse fstab", .func = &parseFstab },
    .{ .msg = "Mount user filesystems", .func = &noop },
    .{ .msg = "Open tty's and login", .func = &createTTY }, // will be xd.eamon
    .{ .msg = "Start xd.aemon", .func = &noop },
    // .{ .msg = "Creation of a console", .func = &createConsole },
};

/// The true "main" function, which is where all the init stuff happens.
pub fn cowabunga(steps: []const Step, io: std.Io, allocator: std.mem.Allocator) anyerror {
    _ = os.setsid();

    var initSystem = InitSystem{ .allocator = allocator, .io = io };
    defer deinitInitSystem(&initSystem);

    // var args = parseKernelArgs(allocator) catch |err| {
    //     log.err("Failed to parse kernel args: {s}", .{@errorName(err)});
    //     return err;
    // };
    // defer deinitKernelArgs(&args);
    // log.debug("Parsed kernel args: {}", .{args});

    for (steps) |step| {
        log.info("+ Running {s}", .{step.msg});
        const before = std.Io.Clock.now(.real, io).toMilliseconds();

        step.func(&initSystem) catch |err| {
            log.err("! Caught an unexpected error: {s}" ++ (if (consts.debug) ". (debug ignore)" else ""), .{@errorName(err)});
            if (!consts.debug) {
                return err;
            }
        };

        const after = std.Io.Clock.now(.real, io).toMilliseconds();
        log.debug("= Done in {d}ms", .{after - before});
    }

    log.debug("Dropping you to a shell for testing...", .{});
    return error.DropToShell;
    // while (true) {}
}
