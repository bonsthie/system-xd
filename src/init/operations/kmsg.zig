const std = @import("std");
const xd = @import("xd");

const Env = xd.system.Env;

pub fn attach(env: Env) !void {
    const kmsg = try std.Io.Dir.openFileAbsolute(env.io, "/dev/kmsg", .{ .mode = .write_only });
    xd.log.setLogTarget(kmsg);
}
