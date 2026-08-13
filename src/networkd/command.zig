//! The command management & dispatching system.

const std = @import("std");
const ssm = std.static_string_map;

const xd = @import("xd");
const Env = xd.system.Env;

const commands = @import("commands/root.zig");

const Command = xd.command.Command;
pub const commandMapping = ssm.StaticStringMap(Command).initComptime(.{
    .{ "help", Command{ .desc = xd.command.defaults.help.desc, .func = help } },
    .{ "load", Command{ .desc = "Loads network configuration from <path>...", .func = commands.load } },
    .{ "dump", Command{ .desc = "Dumps network configuration from <path>...", .func = commands.dump } },
});

pub fn run(env: Env, name: []const u8, args: []const []const u8) !void {
    try xd.command.run(commandMapping, env, name, args);
}

fn help(env: Env, args: []const []const u8) !void {
    try xd.command.defaults.help.run("xd-networkd", commandMapping, env, args);
}
