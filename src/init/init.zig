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
    root_device: ?[]u8 = null,
    root_fstype: ?[]u8 = null,
    stage2: bool = false,
};

const root_mount = "/mnt";

fn deinitInitSystem(init: *InitSystem) void {
    deinitKernelArgs(&init.args);
    if (init.fstab) |*f| f.deinit();
    if (init.root_device) |d| init.allocator.free(d);
    if (init.root_fstype) |t| init.allocator.free(t);
}

fn getKernelArg(init: *InitSystem, key: []const u8) ?[]const u8 {
    const args = init.args orelse return null;
    const value_ptr = args.getPtr(key) orelse return null;
    return value_ptr.*;
}

fn resolveRoot(init: *InitSystem) !void {
    if (init.root_device != null) return;

    const root_spec = getKernelArg(init, "root") orelse blk: {
        if (init.fstab) |*f| {
            if (fstab.findRootEntry(f)) |entry| break :blk entry.device;
        }
        return error.RootNotSpecified;
    };

    init.root_device = try fstab.resolveDeviceSpec(init.allocator, root_spec);
    errdefer {
        init.allocator.free(init.root_device.?);
        init.root_device = null;
    }

    init.root_fstype = blk: {
        if (getKernelArg(init, "rootfstype")) |t| break :blk try init.allocator.dupe(u8, t);
        if (init.fstab) |*f| {
            if (fstab.findRootEntry(f)) |entry| break :blk try init.allocator.dupe(u8, entry.fstype);
        }
        return error.RootFstypeNotSpecified;
    };
}

fn checkRootIntegrity(init: *InitSystem) !void {
    try resolveRoot(init);

    const device = init.root_device.?;
    const fstype = init.root_fstype.?;

    const device_z = try init.allocator.dupeZ(u8, device);
    defer init.allocator.free(device_z);
    const fstype_z = try init.allocator.dupeZ(u8, fstype);
    defer init.allocator.free(fstype_z);

    try std.Io.Dir.createDirPath(.cwd(), init.io, root_mount);

    const ro_flags = @intFromEnum(zos.MountFlags.MS_RDONLY);
    log.info("Mounting root {s} ({s}) on {s} read-only", .{ device, fstype, root_mount });
    try zos.mount(device_z, root_mount, fstype_z, ro_flags, 0);

    try fsck.fsck(init.allocator, device, fstype);
}

fn execPhase2(init: *InitSystem) !void {
    const exe_path = try init.allocator.dupeZ(u8, "/sbin/init");
    const argv = &[_:null]?[*:0]const u8{ exe_path, "phase2", null };
    const envp = &[_:null]?[*:0]const u8{ "PATH=/usr/sbin:/sbin:/usr/bin:/bin", null };
    try zos.execve(exe_path, argv, envp);
}

fn mountRootAndChroot(init: *InitSystem) !void {
    if (init.root_device == null) try resolveRoot(init);

    log.info("Remounting root fs '{s}' read-write", .{root_mount});
    try zos.remount(root_mount, @intFromEnum(zos.MountFlags.MS_REMOUNT));

    // We're on rootfs (initramfs), which pivot_root() cannot pivot away
    // from (EINVAL: "the current root is on the rootfs mount"). Use the
    // switch_root technique instead: MS_MOVE the new root onto "/",
    // then chroot into it.
    try zos.chdir(root_mount);

    log.debug("Moving new root onto /", .{});
    try zos.mount(".", "/", "none", @intFromEnum(zos.MountFlags.MS_MOVE), 0);

    log.debug("Chrooting into new root", .{});
    try zos.chroot(".");
    try zos.chdir("/");
}

fn mountUserFilesystems(init: *InitSystem) !void {
    const f = &(init.fstab orelse {
        log.warn("No fstab loaded, skipping user mounts", .{});
        return;
    });

    const slog = std.log.scoped(.mount);
    for (f.entries.items) |entry| {
        if (!fstab.shouldAutoMount(entry)) continue;
        if (std.mem.eql(u8, entry.mount_options, "/")) continue;

        slog.info("Mounting {s} on {s} ({s})", .{ entry.device, entry.mount_options, entry.fstype });
        fstab.mountEntry(init.allocator, init.io, entry) catch |err| {
            if (entry.options.flags & @intFromEnum(fstab.FsMountFlag.nofail) != 0) {
                slog.warn("Failed to mount {s}: {s}", .{ entry.mount_options, @errorName(err) });
                continue;
            }
            return err;
        };
    }
}

fn noop(_: *InitSystem) !void {
    log.debug("@ noop", .{});
}

fn createConsole(init: *InitSystem) !void {
    for (1..100) |i| {
        log.debug("Open /dev/console try [{}]", .{i});
        _ = process.newTTYFromName(init.io, "/dev/console", .read_write) catch |err| {
            log.debug("createConsole error {}", .{err});
        };
    }
    return error.failCreateConsole;
}

fn triggerReboot(sig: os.SIG) callconv(.c) void {
    _ = sig;
}

/// Sets-up common signal handlers.
fn setupSignalHandlers(_: *InitSystem) !void {
    _ = zos.signal(os.SIG.INT, triggerReboot) catch |err| {
        log.err("Failed to setup SIGINT handler: {s}", .{@errorName(err)});
    };
}

/// Disables the Ctrl-Alt-Del syskey instantly rebooting the system.
/// Instead, it sends a SIGINT to the init process (that's us!!!).
fn disableCADSyskey(_: *InitSystem) !void {
    _ = try wrapErrno(os.reboot(.MAGIC1, .MAGIC2, .CAD_OFF, null));
}

/// Creates and mounts the common kernel-related filesystems.
///
/// This includes: `/dev`, `/proc`, `/sys`, `/run`, `/tmp`.
fn mountKernelVirtualFileSystems(init: *InitSystem) !void {
    const slog = std.log.scoped(.mount);
    const paths = .{ "/dev", "/proc", "/sys", "/run", "/tmp", "/var" };
    inline for (paths) |path| {
        try std.Io.Dir.createDirPath(.cwd(), init.io, path);
    }

    const mounts = .{
        .{ "dev", "/dev", "devtmpfs", 0, 0 },
        .{ "proc", "/proc", "proc", 0, 0 },
        .{ "sys", "/sys", "sysfs", 0, 0 },
        .{ "tmpfs", "/tmp", "tmpfs", 0, 0 },
        .{ "run", "/run", "tmpfs", 0, 0 },
    };
    inline for (mounts) |mount| {
        slog.debug("+ Mounting {s}", .{mount[1]});
        try zos.mount(mount[0], mount[1], mount[2], mount[3], mount[4]);
    }

    try std.Io.Dir.createDirPath(.cwd(), init.io, "/sys/kernel/debug");
    slog.debug("+ Mounting /sys/kernel/debug", .{});
    try zos.mount("none", "/sys/kernel/debug", "debugfs", 0, 0);

    const symlinkPaths = .{
        .{ "/run", "/var/run" },
        .{ "/proc/self/fd", "/dev/fd" },
    };
    inline for (symlinkPaths) |symlink| {
        slog.debug("+ Linking {s} to target {s}", .{ symlink[1], symlink[0] });
        zos.symlink(symlink[0], symlink[1]) catch |err| switch (err) {
            error.FileExists => {},
            else => return err,
        };
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

const MODULE_LIST = "/modules.xd";

fn loadModule(init: *InitSystem, path: []const u8) !void {
    const slog = std.log.scoped(.load);
    slog.debug("+ Loading module {s}", .{path});
    const file = try std.Io.Dir.openFileAbsolute(init.io, path, .{});
    defer file.close(init.io);

    const fd: os.fd_t = file.handle;
    const empty_params: [*:0]const u8 = "";

    try zos.finit_module(fd, empty_params, 0);
    slog.debug("+ Loaded module {s}", .{path});
}

fn loadRequiredModules(init: *InitSystem) !void {
    const slog = std.log.scoped(.load);
    slog.debug("+ Loading modules from {s}", .{MODULE_LIST});

    const file = try std.Io.Dir.openFileAbsolute(init.io, MODULE_LIST, .{});
    defer file.close(init.io);

    const stat = try file.stat(init.io);
    const size: usize = @intCast(stat.size);

    const contents = try init.allocator.alloc(u8, size);
    defer init.allocator.free(contents);

    const n = try file.readPositionalAll(init.io, contents, 0);
    if (n != size) return error.ShortRead;

    var lines = std.mem.splitScalar(u8, contents[0..n], '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;

        slog.debug("IN THE LINE: '{s}'", .{line});

        loadModule(init, line) catch |err| {
            std.debug.print("failed to load {s}: {}\n", .{ line, err });
            return err;
        };
    }

    slog.debug("+ Loaded all modules", .{});
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

// fn dumpFs(init: *InitSystem) !void {
//     try dbg.dumpFilesystemTree(init.io, null);
// }

fn createTTY(init: *InitSystem) !void {
    _ = try process.spawnProcess(&.{ .io = init.io, .filename = "/dev/tty1" });
    _ = try process.spawnProcess(&.{ .io = init.io, .filename = "/dev/tty2" });
    _ = try process.spawnProcess(&.{ .io = init.io, .filename = "/dev/tty3" });
    _ = try process.spawnProcess(&.{ .io = init.io, .filename = "/dev/tty4" });
    _ = try process.spawnProcess(&.{ .io = init.io, .filename = "/dev/tty5" });
}

const Step = struct {
    msg: []const u8,
    func: *const fn (_: *InitSystem) anyerror!void,
};

pub const phase1Steps = [_]Step{
    .{ .msg = "Mount kernel virtual filesystems", .func = &mountKernelVirtualFileSystems },
    .{ .msg = "Parse kernel arguments", .func = &parseKernelArguments },
    .{ .msg = "Load required kernel modules", .func = &loadRequiredModules },
    .{ .msg = "Set time", .func = &setTime },
    //.{ .msg = "Parse initramfs fstab", .func = &parseFstab },
    .{ .msg = "Integrity check fsroot", .func = &checkRootIntegrity },
    .{ .msg = "Mount fsroot and chroot", .func = &mountRootAndChroot },
    .{ .msg = "Execute the second part of the init system", .func = &execPhase2 },
};

pub const phase2Steps = [_]Step{
    .{ .msg = "Setup signal handlers", .func = &setupSignalHandlers },
    .{ .msg = "Disable CAD syskey", .func = &disableCADSyskey },
    .{ .msg = "Mount kernel virtual filesystems", .func = &mountKernelVirtualFileSystems },
    .{ .msg = "Parse fstab", .func = &parseFstab },
    .{ .msg = "Mount user filesystems", .func = &mountUserFilesystems },
    // .{ .msg = "Open tty's and login", .func = &createTTY }, // will be xd.eamon
    .{ .msg = "Start xd.aemon", .func = &noop },
    // .{ .msg = "Creation of a console", .func = &createConsole },
};

/// The true "main" function, which is where all the init stuff happens.
pub fn cowabunga(steps: []const Step, io: std.Io, allocator: std.mem.Allocator, stage2: bool) anyerror {
    _ = os.setsid();

    var initSystem = InitSystem{ .allocator = allocator, .io = io, .stage2 = stage2 };
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
