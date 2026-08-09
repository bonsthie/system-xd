const std = @import("std");
const os = std.os.linux;
const log = std.log.scoped(.daemon);

const xd = @import("xd");
const service = xd.service;
const Env = xd.system.Env;
const ServiceTable = service.ServiceTable;

const SERVICE_DIR = if (!xd.consts.debug) "/etc/xd/services" else "./example";

pub const DaemonServer = struct {
    socket: os.socket_t,
    services: service.ServiceTable,
    env: Env,

    pub fn run(self: *DaemonServer) !void {
        _ = self;
        log.info("Running daemon server", .{});
    }
};

pub fn create(env: Env) !DaemonServer {
    log.info("Creating daemon server", .{});
    const serviceTable = ServiceTable.create(env, SERVICE_DIR) catch |err| blk: {
        log.debug("Failed to create service table: {s}", .{@errorName(err)});
        break :blk ServiceTable{ .services = &.{}, .env = env };
    };

    log.debug("Service table: {any}", .{serviceTable});

    return DaemonServer{
        .socket = 0,
        .services = serviceTable,
        .env = env,
    };
}
