//! Reusable command dispatching and default commands.

const std = @import("std");
const log = std.log.scoped(.command);

const Env = @import("system/env.zig").Env;

pub const Command = struct {
    desc: []const u8,
    func: ?*const fn (env: Env, args: []const []const u8) anyerror!void,
};

pub const CommandMap = std.StaticStringMap(Command);

pub const defaults = struct {
    pub const help = struct {
        pub const desc = "Displays a nice help message";

        pub fn run(
            program_name: []const u8,
            command_mapping: CommandMap,
            _: Env,
            _: []const []const u8,
        ) !void {
            log.info("Usage: {s} <command> [<args>]", .{program_name});
            for (command_mapping.keys()) |name| {
                log.info("\t{s}\t\t{s}", .{ name, command_mapping.get(name).?.desc });
            }
        }
    };
};

pub fn run(
    command_mapping: CommandMap,
    env: Env,
    name: []const u8,
    args: []const []const u8,
) !void {
    log.debug("Trying to run command '{s}'", .{name});
    const command = command_mapping.get(name) orelse return error.UnknownCommand;

    const command_func = command.func orelse {
        log.debug("Command '{s}' is not implemented yet", .{name});
        return error.CommandNotImplemented;
    };
    try command_func(env, args);
}
