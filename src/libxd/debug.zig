const std = @import("std");
const log = std.log.scoped(.debug);

pub fn dumpFilesystemTree(io: std.Io, path: ?[]const u8) !void {
    if (path) |p| {
        log.info("Dumping filesystem tree at {s}", .{p});
        var dir = try std.Io.Dir.openDirAbsolute(io, p, .{ .iterate = true });
        defer dir.close(io);
        try dumpFilesystemTreeImpl(io, dir, 0);
    } else {
        log.info("Dumping filesystem tree at root", .{});
        var dir = try std.Io.Dir.openDirAbsolute(io, "/", .{ .iterate = true });
        defer dir.close(io);
        try dumpFilesystemTreeImpl(io, dir, 0);
    }
}

fn dumpFilesystemTreeImpl(io: std.Io, dir: std.Io.Dir, depth: usize) !void {
    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        const name = entry.name;
        const is_dir = entry.kind == .directory;
        for (0..depth) |_| {
            std.debug.print("  ", .{});
        }
        if (is_dir) {
            std.debug.print("- {s}/\n", .{name});
            var sub = try std.Io.Dir.openDir(dir, io, name, .{ .iterate = true });
            defer sub.close(io);
            try dumpFilesystemTreeImpl(io, sub, depth + 1);
        } else {
            std.debug.print("- {s}\n", .{name});
        }
    }
}
