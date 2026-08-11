const xd = @import("xd");
const log = @import("std").log.scoped(.reload);
const Env = xd.system.Env;

const send = @import("root.zig").send;

pub fn reload(env: Env, _: []const []const u8) !void {
    log.info("Reloading service manager", .{});
    try send(env, .{ .msg_type = .reload });
}
