//! The command management & dispatching system.

const std = @import("std");
const ssm = std.static_string_map;

const xd = @import("xd");
const Env = xd.system.Env;

const commands = @import("commands/root.zig");

const Command = xd.command.Command;
pub const commandMapping = ssm.StaticStringMap(Command).initComptime(.{
    .{ "reload", Command{ .desc = "Reloads the service manager", .func = commands.reload } },
    .{ "start", Command{ .desc = "Starts a service", .func = commands.start } },
    .{ "stop", Command{ .desc = "Stops a service", .func = commands.stop } },
    .{ "status", Command{ .desc = "Gets the status of a service", .func = commands.status } },
    .{ "restart", Command{ .desc = "Restarts a service", .func = commands.restart } },
    .{ "panic", Command{ .desc = ":trollface:", .func = commands.panic, .hidden = true } },
    .{ "daemon", Command{ .desc = "Starts a service daemon", .func = commands.daemon } },
    .{ "help", Command{ .desc = xd.command.defaults.help.desc, .func = help } },
});

pub fn run(env: Env, name: []const u8, args: []const []const u8) !void {
    try xd.command.run(commandMapping, env, name, args);
}

fn help(env: Env, args: []const []const u8) !void {
    try xd.command.defaults.help.run("xd", commandMapping, env, args);
}
