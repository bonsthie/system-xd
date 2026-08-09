const std = @import("std");

const log = std.log.scoped(.step);

pub fn Step(comptime Context: type) type {
    return struct {
        msg: []const u8,
        func: *const fn (*Context) anyerror!void,

        pub fn run(self: @This(), ctx: *Context) !void {
            log.info("+ Running {s}", .{self.msg});

            self.func(ctx) catch |err| {
                log.err("{s} failed: {s}", .{ self.msg, @errorName(err) });
                return err;
            };
        }
    };
}

pub fn runAll(
    comptime Context: type,
    ctx: *Context,
    steps: []const Step(Context),
) !void {
    for (steps) |current| {
        try current.run(ctx);
    }
}
