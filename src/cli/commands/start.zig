const xd = @import("xd");
const log = @import("std").log.scoped(.start);
const Env = xd.system.Env;

const send = @import("root.zig").send;

pub fn start(env: Env, args: []const []const u8) !void {
    if (args.len != 1) {
        log.err("Usage: xd start <service name>", .{});
        return;
    }
    try send(env, .{ .msg_type = .start, .message = args[0] });
}
