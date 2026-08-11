const std = @import("std");
const os = std.os.linux;
const syscall = @import("../syscall.zig");
const log = std.log.scoped(.service);
const process = @import("../process.zig");

const service = @import("service.zig");
const parser = @import("parser.zig");
const Env = @import("../env.zig").Env;

pub const RestartPolicy = service.RestartPolicy;
pub const Service = service.Service;

const SERVICE_FILE_SUFFIX = ".service.toml";

pub const ServiceData = struct {
    decl: Service,
    pid: os.pid_t = -1,
    running: bool = false,
};

pub const ServiceTable = struct {
    services: []ServiceData,
    env: Env,

    pub fn spawnAll(self: *ServiceTable) void {
        var i: usize = 0;
        for (self.services) |*svc| {
            self.spawn(svc) catch |err| {
                log.err("Failed to spawn service {s}: {s}", .{ svc.decl.name, @errorName(err) });
                i += 1;
                continue;
            };
            svc.running = true;
            i += 1;
        }
    }

    fn spawn(self: *ServiceTable, svc: *ServiceData) !void {
        var environ = try self.buildEnviron(&svc.decl);
        defer environ.deinit();

        const exec: process.Exec = .{ .native = .{
            .allocator = self.env.allocator,
            .command = svc.decl.path,
            .args = svc.decl.argv,
            .environ = &environ,
        } };
        const config: process.Config = .{};

        svc.pid = if (svc.decl.tty) |tty|
            try process.spawnFromName(self.env.io, tty, &exec, &config)
        else
            try process.spawn(&exec, &config);
        svc.running = true;
        log.info("Started service {s} (pid {d})", .{ svc.decl.name, svc.pid });
    }

    fn buildEnviron(self: *const ServiceTable, decl: *const Service) !std.process.Environ.Map {
        var environ: std.process.Environ.Map = if (decl.clear_env)
            std.process.Environ.Map.init(self.env.allocator)
        else
            try self.env.environ.clone(self.env.allocator);
        errdefer environ.deinit();

        if (decl.clear_env) {
            try environ.array_hash_map.ensureUnusedCapacity(self.env.allocator, decl.envp.len);
        }

        for (decl.envp) |entry| {
            const eq_pos = std.mem.indexOfScalar(u8, entry, '=') orelse {
                log.warn("skipping malformed environment entry (no '='): {s}", .{entry});
                continue;
            };

            try environ.put(entry[0..eq_pos], entry[eq_pos + 1 ..]);
        }

        return environ;
    }

    fn findByPid(self: *ServiceTable, pid: os.pid_t) ?*ServiceData {
        for (self.services) |*svc| {
            if (svc.pid == pid) return svc;
        }
        return null;
    }

    pub fn findByName(self: *ServiceTable, name: []const u8) ?*ServiceData {
        for (self.services) |*svc| {
            if (std.mem.eql(u8, svc.decl.name, name)) return svc;
        }
        return null;
    }

    pub fn reap(self: *ServiceTable, allow_restart: bool) void {
        while (true) {
            var status: u32 = 0;
            const pid = syscall.waitpid(-1, &status, os.W.NOHANG) catch break;
            if (pid <= 0) break;

            if (!allow_restart) continue;

            if (self.findByPid(pid)) |svc| {
                log.warn("Service {s} (pid {d}) exited, status {d}", .{ svc.decl.name, pid, os.W.EXITSTATUS(status) });
                svc.pid = -1;
                svc.running = false;
                switch (svc.decl.restart) {
                    .always => self.spawn(svc) catch |err| {
                        log.err("Failed to spawn service {s}: {s}", .{ svc.decl.name, @errorName(err) });
                    },
                    .never => {},
                }
            } else {
                log.debug("Reaped untracked pid {d}, status {d}", .{ pid, status });
            }
        }
    }

    pub fn shutdown(self: *ServiceTable) void {
        for (self.services) |*svc| {
            if (svc.running) {
                log.warn("Shutting down service {s} (pid {d})", .{ svc.decl.name, svc.pid });
                _ = os.kill(svc.pid, os.SIG.TERM);
            }
        }
        self.reap(false);
    }

    pub fn deinit(self: *ServiceTable) void {
        self.env.allocator.free(self.services);
    }

    pub fn create(env: Env, dirName: []const u8) !ServiceTable {
        try std.Io.Dir.createDirPath(.cwd(), env.io, dirName);

        const dir = try std.Io.Dir.openDir(.cwd(), env.io, dirName, .{ .iterate = true });
        defer dir.close(env.io);

        var size: usize = 0;
        var dirIterator = dir.iterate();
        while (try dirIterator.next(env.io)) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, SERVICE_FILE_SUFFIX)) continue;
            size += 1;
        }

        var srvArray = try env.allocator.alloc(ServiceData, size);
        errdefer env.allocator.free(srvArray);

        var i: usize = 0;
        dirIterator = dir.iterate();
        while (try dirIterator.next(env.io)) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, SERVICE_FILE_SUFFIX)) continue;

            const absPath = try std.fs.path.join(env.allocator, &[_][]const u8{ dirName, entry.name });
            defer env.allocator.free(absPath);

            const decl = parser.fromToml(env, absPath) catch {
                log.warn("Failed to parse service {s}", .{absPath});
                continue;
            };

            var good = true;
            for (0..i) |j| {
                if (std.mem.eql(u8, srvArray[j].decl.name, decl.name)) {
                    log.warn("Service named {s} already exists", .{decl.name});
                    good = false;
                    break;
                }
            }
            if (!good) continue;

            srvArray[i] = .{ .decl = decl, .running = false, .pid = -1 };
            i += 1;
        }
        size = i;
        i = 0;

        const services = try env.allocator.alloc(ServiceData, size);
        errdefer env.allocator.free(services);
        for (services) |*svc| {
            svc.* = srvArray[i];
            i += 1;
        }
        env.allocator.free(srvArray);

        return ServiceTable{ .services = services, .env = env };
    }

    pub fn format(self: ServiceTable, writer: *std.Io.Writer) !void {
        try writer.print("services = [\n", .{});
        var i: usize = 0;
        for (self.services) |svc| {
            if (i > 0) try writer.print(",\n", .{});
            try svc.decl.format(writer);
            i += 1;
        }
        try writer.print("]", .{});
    }
};
