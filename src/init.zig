const std = @import("std");
const fs = std.fs;
const log = std.log;

fn walk(dir: fs.Dir, i: u32) anyerror!void {
    var it = dir.iterate();
    loop: {
        while (it.next()) |entry| {
            if (entry) |e| {
                if (e.kind == fs.File.Kind.directory) {
                    const sub_dir = try dir.openDir(e.name, .{ .iterate = true });
                    std.debug.print("{s}/\n", .{e.name});
                    try walk(sub_dir, i + 1);
                } else {
                    var stdout = std.io.getStdOut().writer();
                    for (0..(i * 2)) |_| {
                        try stdout.writeByte(' ');
                    }
                    std.debug.print("{s}\n", .{e.name});
                }
            } else {
                break :loop;
            }
        } else |err| {
            log.err("err: {}", .{err});
            break :loop;
        }
    }
}

pub fn main() !void {
    log.info("system-xd", .{});

    const dir = try fs.openDirAbsolute("/", .{ .iterate = true });

    std.debug.print("Directory structure:\n", .{});
    try walk(dir, 0);

    while (true) {}
}
