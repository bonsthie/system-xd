const std = @import("std");
const log = std.log.scoped(.disable);
const xd = @import("xd");
const Env = xd.system.Env;

const send = @import("root.zig").send;
const SERVICE_DIR = @import("daemon.zig").SERVICE_DIR;

pub fn disable(env: Env, args: []const []const u8) !void {
    if (args.len < 1) {
        log.err("Usage: xd disable <service name>", .{});
        return;
    }
    const service_name = args[0];
    const target_dir = if (args.len > 1) args[1] else SERVICE_DIR;
    const dir = try std.Io.Dir.openDir(.cwd(), env.io, target_dir, .{});
    defer dir.close(env.io);

    const filename_enabled = try std.fmt.allocPrint(env.allocator, "{s}.service.toml", .{service_name});
    defer env.allocator.free(filename_enabled);
    const filename_disabled = try std.fmt.allocPrint(env.allocator, "{s}.service.disabled.toml", .{service_name});
    defer env.allocator.free(filename_disabled);

    std.Io.Dir.rename(dir, filename_enabled, dir, filename_disabled, env.io) catch |err| {
        log.err("Failed to disable service file: {s}", .{@errorName(err)});
        return;
    };
    try send(env, .{ .msg_type = .reload });
    log.info("Disabled service '{s}'", .{service_name});
}
