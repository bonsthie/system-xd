const std = @import("std");
const log = std.log.scoped(.daemon);

const xd = @import("xd");
const Env = xd.system.Env;

const daemonModule = @import("../daemon/root.zig");

pub fn daemon(env: Env, _: []const []const u8) !void {
    var server = daemonModule.server.create(env) catch |err| {
        log.err("Failed to create daemon server: {s}", .{@errorName(err)});
        return;
    };
    defer server.deinit();
    server.run() catch |err| {
        log.err("Error while running daemon: {s}", .{@errorName(err)});
        return;
    };
}
