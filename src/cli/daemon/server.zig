const std = @import("std");
const os = std.os.linux;
const log = std.log.scoped(.daemon);

const xd = @import("xd");
const service = xd.service;
const Env = xd.system.Env;
const ServiceTable = service.ServiceTable;
const syscall = xd.system.syscall;

var current_server: ?*DaemonServer = null;

fn signalHandler(sig: os.SIG) callconv(.c) void {
    if (current_server) |server| { 
        if (sig == os.SIG.CHLD) server.services.reap();
        if (sig == os.SIG.INT) server.shutdown();
        if (sig == os.SIG.USR1) server.processMessage();
    }
}

pub const DaemonServer = struct {
    services: service.ServiceTable,
    env: Env,
    comms_file: []const u8,
    running: bool = true,

    pub fn run(self: *DaemonServer) !void {
        current_server = self;

        log.debug("Initializing services", .{});
        self.services.spawnAll();

        log.info("Running daemon server...", .{});
        var empty_mask: os.sigset_t = std.mem.zeroes(os.sigset_t);
        while (self.running) {
            syscall.sigsuspend(&empty_mask);
        }

        log.debug("Shutting down services", .{});
        // self.services.shutdown();
    }

    pub fn processMessage(self: *DaemonServer) !void {
        log.debug("Processing message", .{});
    }

    pub fn shutdown(self: *DaemonServer) void {
        self.running = false;
    }

    pub fn deinit(self: *DaemonServer) void {
        self.services.deinit();
        current_server = null;
    }
};

pub fn create(env: Env, service_dir: []const u8, communication_file: []const u8) !DaemonServer {
    log.info("Creating daemon server", .{});

    const serviceTable = ServiceTable.create(env, service_dir) catch |err| blk: {
        log.debug("Failed to create service table: {s}", .{@errorName(err)});
        break :blk ServiceTable{ .services = &.{}, .env = env };
    };
    log.debug("Service table: {f}", .{serviceTable});

    inline for (.{ os.SIG.INT, os.SIG.CHLD, os.SIG.USR1 }) |sig| {
        _ = try syscall.signal(sig, signalHandler);
    }
    log.debug("Setup signal hooks", .{});

    return DaemonServer{
        .services = serviceTable,
        .env = env,
        .comms_file = communication_file,
    };
}
