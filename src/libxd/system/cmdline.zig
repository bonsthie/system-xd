const std = @import("std");
const args = @import("args.zig");
const log = std.log.scoped(.cmdline);

const Env = @import("env.zig").Env;

pub const Cmdline = struct {
    values: ?std.StringHashMap(?[]u8) = null,

    pub fn load(env: Env) !Cmdline {
        return .{
            .values = try args.parseKernelArgs(
                env.io,
                env.allocator,
            ),
        };
    }

    pub fn get(self: *const Cmdline, key: []const u8) ?[]const u8 {
        const values = self.values orelse return null;
        return values.get(key) orelse null;
    }

    pub fn deinit(self: *Cmdline) void {
        args.deinitKernelArgs(&self.values);
    }
};
