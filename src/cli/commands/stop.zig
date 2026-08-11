const xd = @import("xd");
const log = @import("std").log.scoped(.stop);
const Env = xd.system.Env;

const send = @import("root.zig").send;

pub fn stop(env: Env, args: []const []const u8) !void {
    if (args.len != 1) {
        log.err("Usage: xd stop <service name>", .{});
        return;
    }
    try send(env, .{ .msg_type = .stop, .message = args[0] });
}
