const std = @import("std");
const log = std.log.scoped(.enable);
const xd = @import("xd");
const Env = xd.system.Env;

const send = @import("root.zig").send;
const SERVICE_DIR = @import("daemon.zig").SERVICE_DIR;

pub fn enable(env: Env, args: []const []const u8) !void {
    if (args.len < 1) {
        log.err("Usage: xd enable <service name>", .{});
    }
    const service_name = args[0];
    const target_dir = if (args.len > 1) args[1] else SERVICE_DIR;
    const dir = try std.Io.Dir.openDir(.cwd(), env.io, target_dir, .{});
    defer dir.close(env.io);

    const filename_enabled = try std.fmt.allocPrint(env.allocator, "{s}.service.toml", .{service_name});
    defer env.allocator.free(filename_enabled);
    const filename_disabled = try std.fmt.allocPrint(env.allocator, "{s}.service.disabled.toml", .{service_name});
    defer env.allocator.free(filename_disabled);

    std.Io.Dir.rename(dir, filename_disabled, dir, filename_enabled, env.io) catch |err| {
        log.err("Failed to enable service file: {s}", .{@errorName(err)});
        return;
    };
    try send(env, .{ .msg_type = .reload });
    log.info("Enabled service '{s}'", .{service_name});
}
