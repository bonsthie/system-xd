const std = @import("std");
const system = @import("xd").system;

const Env = system.Env;
const log = std.log.scoped(.module);

pub fn loadRequired(env: Env, list_path: []const u8) !void {
    log.debug("+ Loading modules from {s}", .{list_path});

    const file = try std.Io.Dir.openFileAbsolute(env.io, list_path, .{});
    defer file.close(env.io);

    const stat = try file.stat(env.io);
    const contents = try env.allocator.alloc(u8, @intCast(stat.size));
    defer env.allocator.free(contents);

    const count = try file.readPositionalAll(env.io, contents, 0);
    if (count != contents.len) return error.ShortRead;

    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |raw_line| {
        const path = std.mem.trim(u8, raw_line, " \t\r");
        if (path.len == 0) continue;

        log.debug("+ Loading module {s}", .{path});
        try system.kernel_module.load(env, path);
    }
}
