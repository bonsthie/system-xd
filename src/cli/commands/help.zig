//! Displays a nice help message.

const std = @import("std");
const log = std.log.scoped(.help);
const mapping = @import("../command.zig").commandMapping;

const xd = @import("xd");
const Env = xd.system.Env;

pub fn help(_: Env, _: []const []const u8) !void {
    log.info("Usage: xd <command> [<args>]", .{});
    for (mapping.keys()) |key| {
        log.info("\t{s}\t\t{s}", .{ key, mapping.get(key).?.desc });
    }
}
