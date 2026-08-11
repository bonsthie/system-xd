const xd = @import("xd");
const log = @import("std").log.scoped(.status);
const Env = xd.system.Env;

const send = @import("root.zig").send;

pub fn status(env: Env, args: []const []const u8) !void {
    if (args.len != 1) {
        log.err("Usage: xd status <service name>", .{});
        return;
    }
    log.info("Getting status of service '{s}'", .{args[0]});
    try send(env, .{ .msg_type = .status, .message = args[0] });
}
