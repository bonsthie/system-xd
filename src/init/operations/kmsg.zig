const std = @import("std");
const xd = @import("xd");
const os = std.os.linux;

const Env = xd.system.Env;

pub fn attach(env: Env) !void {
    const kmsg = try std.Io.Dir.openFileAbsolute(env.io, "/dev/kmsg", .{ .mode = .write_only });
    _ = os.dup2(kmsg.handle, os.STDIN_FILENO);
    _ = os.dup2(kmsg.handle, os.STDOUT_FILENO);
    _ = os.dup2(kmsg.handle, os.STDERR_FILENO);
}
