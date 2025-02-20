const std = @import("std");
const os = std.os.linux;
const consts = @import("consts.zig");
const log = std.log.scoped(.debug);
const fs = std.fs;

pub fn dumpFilesystemTree(path: ?[]const u8) !void {
    if (path) |p| {
        log.info("Dumping filesystem tree at {s}", .{p});
        var dir = try fs.openDirAbsolute(p, .{ .iterate = true });
        defer dir.close();
        try dumpFilesystemTreeImpl(dir, 0);
    } else {
        log.info("Dumping filesystem tree at root", .{});
        var dir = try fs.openDirAbsolute("/", .{ .iterate = true });
        defer dir.close();
        try dumpFilesystemTreeImpl(dir, 0);
    }
}

fn dumpFilesystemTreeImpl(dir: fs.Dir, depth: usize) !void {
    var it = dir.iterate();
    while (it.next()) |e| {
        if (e) |entry| {
            const name = entry.name;
            const is_dir = entry.kind == .directory;
            for (0..depth) |_| {
                std.debug.print("  ", .{});
            }
            if (is_dir) {
                std.debug.print("- {s}/\n", .{name});
                var sub = try dir.openDir(name, .{ .iterate = true });
                defer sub.close();
                try dumpFilesystemTreeImpl(sub, depth + 1);
            } else {
                std.debug.print("- {s}\n", .{name});
            }
        } else {
            break;
        }
    } else |err| {
        log.err("Failed to iterate over directory {}: {}", .{ dir, err });
    }
}

pub fn isPid1() !void {
    const pid = os.getpid();
    log.debug("PID: {d}", .{pid});
    if (pid != 1) {
        if (consts.debug) {
            log.debug("Bypassing PID check because program was compiled in debug mode", .{});
        } else {
            log.err("This program must be run as PID 1", .{});
            return error.notPid1;
        }
    }
}
