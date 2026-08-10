//! The command management & dispatching system.

const std = @import("std");
const log = std.log.scoped(.command);
const ssm = std.static_string_map;
const meta = std.meta;

const xd = @import("xd");
const Env = xd.system.Env;

const commands = @import("commands/root.zig");

const Command = struct {
    desc: []const u8,
    func: ?*const fn (env: Env, args: []const []const u8) anyerror!void,
};

pub const commandMapping = ssm.StaticStringMap(Command).initComptime(.{
    .{ "reload", Command{ .desc = "Reloads the service manager", .func = commands.reload } },
    .{ "daemon", Command{ .desc = "Starts a service daemon", .func = commands.daemon } },
    .{ "help", Command{ .desc = "Displays a nice help message", .func = commands.help } },
});

pub fn run(env: Env, name: []const u8, args: []const []const u8) !void {
    log.debug("Trying to run command '{s}'", .{name});
    const command = commandMapping.get(name) orelse return error.UnknownCommand;

    if (command.func == null) {
        log.debug("Command '{s}' is not implemented yet", .{name});
        return error.CommandNotImplemented;
    }
    try command.func.?(env, args);
}
