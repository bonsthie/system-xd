const xd = @import("xd");
const Env = xd.system.Env;

const send = @import("root.zig").send;

pub fn reload(env: Env, _: []const []const u8) !void {
    try send(env, .{ .msg_type = .reload });
}
