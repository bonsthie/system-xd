const std = @import("std");
const xd = @import("xd");
const Env = xd.system.Env;
const daemon = @import("../daemon/root.zig");
const message = daemon.message;
const Message = message.Message;
const MessageType = message.MessageType;

// Commands

pub const help = @import("help.zig").help;
pub const daemon = @import("daemon.zig").daemon;
pub const reload = @import("reload.zig").reload;

// Helpers

pub fn send(env: Env, msg: Message) !void {
    const pidFile = try std.Io.Dir.openFileAbsolute(env.io, "/var/run/xd.pid", .{});
    defer pidFile.close(env.io);

    var reader = pidFile.reader(env.io);
    defer reader.close();
    const pid = try reader.interface.readIntLittle(u32);
}
