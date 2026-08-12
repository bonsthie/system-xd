const std = @import("std");
const log = std.log.scoped(.daemon);

const xd = @import("xd");
const Env = xd.system.Env;

const daemonModule = @import("../daemon/root.zig");

pub const SERVICE_DIR = "/etc/xd/services";

pub fn daemon(env: Env, args: []const []const u8) !void {
    const service_dir = if (args.len > 0) args[0] else SERVICE_DIR;

    var server = daemonModule.server.create(env, service_dir) catch |err| {
        log.err("Failed to create daemon server: {s}", .{@errorName(err)});
        return;
    };
    defer server.deinit();
    server.run() catch |err| {
        log.err("Error while running daemon: {s}", .{@errorName(err)});
        return;
    };
}
