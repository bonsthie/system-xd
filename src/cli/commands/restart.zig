const xd = @import("xd");
const log = @import("std").log.scoped(.restart);
const Env = xd.system.Env;

const send = @import("root.zig").send;

pub fn restart(env: Env, args: []const []const u8) !void {
    if (args.len != 1) {
        log.err("Usage: xd restart <service name>", .{});
        return;
    }
    try send(env, .{ .msg_type = .stop, .message = args[0] });
    try send(env, .{ .msg_type = .start, .message = args[0] });
}
