//! Displays a nice help message.

const std = @import("std");
const log = std.log.scoped(.help);

fn help(_: std.mem.Allocator, _: std.Io, _: []const []const u8) !void {
    log.info("Help command invoked", .{});
}
