const std = @import("std");
const system = @import("xd").system;

const Env = system.Env;
const Fstab = system.fstab.Fstab;
const syscall = system.syscall;
const log = std.log.scoped(.mount);

pub fn kernelVirtualFilesystems(env: Env) !void {
    const paths = .{ "/dev", "/proc", "/sys", "/run", "/tmp", "/var" };
    inline for (paths) |path| {
        try std.Io.Dir.createDirPath(.cwd(), env.io, path);
    }

    const mounts = .{
        .{ "dev", "/dev", "devtmpfs", 0, 0 },
        .{ "proc", "/proc", "proc", 0, 0 },
        .{ "sys", "/sys", "sysfs", 0, 0 },
        .{ "tmpfs", "/tmp", "tmpfs", 0, 0 },
        .{ "run", "/run", "tmpfs", 0, 0 },
    };
    inline for (mounts) |mount| {
        log.debug("+ Mounting {s}", .{mount[1]});
        try syscall.mount(mount[0], mount[1], mount[2], mount[3], mount[4]);
    }

    try std.Io.Dir.createDirPath(.cwd(), env.io, "/sys/kernel/debug");
    log.debug("+ Mounting /sys/kernel/debug", .{});
    try syscall.mount("none", "/sys/kernel/debug", "debugfs", 0, 0);

    const symlinks = .{
        .{ "/run", "/var/run" },
        .{ "/proc/self/fd", "/dev/fd" },
    };
    inline for (symlinks) |symlink| {
        log.debug("+ Linking {s} to target {s}", .{ symlink[1], symlink[0] });
        syscall.symlink(symlink[0], symlink[1]) catch |err| switch (err) {
            error.FileExists => {},
            else => return err,
        };
    }
}

pub fn configuredFilesystems(env: Env, fstab: *const Fstab) !void {
    for (fstab.entries.items) |entry| {
        if (!system.fstab.shouldAutoMount(entry, true)) continue;
        if (std.mem.eql(u8, entry.mount_options, "/")) continue;

        log.info("Mounting {s} on {s} ({s})", .{ entry.device, entry.mount_options, entry.fstype });
        system.fstab.mountEntry(env.allocator, env.io, entry) catch |err| {
            if (entry.options.flags & @intFromEnum(system.fstab.FsMountFlag.nofail) != 0) {
                log.warn("Failed to mount {s}: {s}", .{ entry.mount_options, @errorName(err) });
                continue;
            }
            return err;
        };
    }
}
