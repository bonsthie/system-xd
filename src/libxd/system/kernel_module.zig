const std = @import("std");

const Env = @import("env.zig").Env;
const syscall = @import("syscall.zig");

pub fn load(env: Env, path: []const u8) !void {
    const file = try std.Io.Dir.openFileAbsolute(env.io, path, .{});
    defer file.close(env.io);

    try syscall.finit_module(file.handle, "", 0);
}
