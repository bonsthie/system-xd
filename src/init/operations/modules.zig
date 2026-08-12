const std = @import("std");
const system = @import("xd").system;

const Env = system.Env;
const log = std.log.scoped(.module);

const LIST_PATH = "/etc/xd/modules.conf";

pub fn load(env: Env) !void {
    log.debug("Loading modules from {s}", .{ LIST_PATH });
    const file = std.Io.Dir.openFileAbsolute(env.io, LIST_PATH, .{}) catch {
        log.debug("Couldn't open {s}, skipping", .{ LIST_PATH });
        return;
    };
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

        log.debug("Loading module {s}", .{path});
        try system.kernel_module.load(env, path);
    }
}
