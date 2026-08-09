//! The command management & dispatching system.

const std = @import("std");
const log = std.log.scoped(.command);
const ssm = std.static_string_map;
const meta = std.meta;

const commands = @import("commands/root.zig");

const CommandFn = *const fn (gpa: std.mem.Allocator, io: std.Io, args: []const []const u8) anyerror!void;

fn generateCommands(comptime root: anytype) void {
    const data = @typeInfo(root).@"struct".fields;
    inline for (data) |decl| {
        const name = decl.name;
        @compileLog("Found command '{s}'", .{name});
        if (decl.is_pub and decl.is_export and decl.data == .Var) {
        }
    }
}

comptime {
    generateCommands(commands);
}

const commandMapping = ssm.StaticStringMap(?CommandFn).initComptime(.{});

pub fn run(gpa: std.mem.Allocator, io: std.Io, name: []const u8, args: []const []const u8) !void {
    log.debug("Trying to run command '{s}'", .{name});
    const command = commandMapping.get(name) orelse return error.UnknownCommand;

    if (command != null) {
        try command.?(gpa, io, args);
    }
}
