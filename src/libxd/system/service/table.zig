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

pub const SERVICE_FILE_SUFFIX = ".service.toml";
pub const SERVICE_FILE_SUFFIX_DISABLED = ".service.disabled.toml";
pub const TIMEOUT_NS: i64 = 10 * std.time.ns_per_s;

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
            i += 1;
        }
    }

    pub fn spawn(self: *ServiceTable, svc: *ServiceData) !void {
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

    pub fn stop(self: *ServiceTable, svc: *ServiceData) void {
        if (!svc.running or svc.pid <= 0) return;

        log.info("Stopping service {s} (pid {d})", .{ svc.decl.name, svc.pid });
        _ = os.kill(svc.pid, os.SIG.TERM);

        if (!waitForExit(self.env, svc.pid, TIMEOUT_NS)) {
            log.warn("Service {s} (pid {d}) did not exit in time, sending SIGKILL", .{ svc.decl.name, svc.pid });
            _ = os.kill(svc.pid, os.SIG.KILL);
            _ = waitForExit(self.env, svc.pid, TIMEOUT_NS);
        }

        svc.running = false;
        svc.pid = -1;
    }

    pub fn waitForExit(env: Env, pid: os.pid_t, timeout_ns_budget: i64) bool {
        const poll_interval_ns: i64 = 50 * std.time.ns_per_ms;
        var elapsed: i64 = 0;

        while (elapsed < timeout_ns_budget) {
            var status: u32 = 0;
            const ret_pid = syscall.waitpid(pid, &status, os.W.NOHANG) catch break;
            if (ret_pid == pid) return true;

            env.io.sleep(.fromNanoseconds(poll_interval_ns), .real) catch {};
            elapsed += poll_interval_ns;
        }
        return false;
    }

    pub fn stopAll(self: *ServiceTable) void {
        for (self.services) |*svc| {
            if (!svc.running or svc.pid <= 0) continue;
            log.info("Stopping service {s} (pid {d})", .{ svc.decl.name, svc.pid });
            _ = os.kill(svc.pid, os.SIG.TERM);
        }

        const start = std.Io.Clock.now(.real, self.env.io);
        for (self.services) |*svc| {
            if (!svc.running or svc.pid <= 0) continue;
            const now = std.Io.Clock.now(.real, self.env.io);
            const elapsed_ns = (now.toSeconds() - start.toSeconds()) * std.time.ns_per_s; // adjust to actual nsec-precision accessor if available
            const remaining = TIMEOUT_NS - elapsed_ns;
            if (remaining > 0) _ = waitForExit(self.env, svc.pid, remaining);
        }

        for (self.services) |*svc| {
            if (!svc.running or svc.pid <= 0) continue;
            log.warn("Service {s} (pid {d}) did not exit in time, sending SIGKILL", .{ svc.decl.name, svc.pid });
            _ = os.kill(svc.pid, os.SIG.KILL);
            var status: u32 = 0;
            _ = syscall.waitpid(svc.pid, &status, 0) catch {};
            svc.running = false;
            svc.pid = -1;
        }
    }

    pub fn shutdown(self: *ServiceTable) void {
        self.stopAll();
    }

    pub fn deinit(self: *ServiceTable) void {
        self.env.allocator.free(self.services);
    }

    pub fn create(env: Env, dirName: []const u8) !ServiceTable {
        log.debug("Creating service table at {s}", .{dirName});
        try std.Io.Dir.createDirPath(.cwd(), env.io, dirName);

        const dir = try std.Io.Dir.openDir(.cwd(), env.io, dirName, .{ .iterate = true });
        defer dir.close(env.io);

        log.debug("Initial iteration", .{});
        var size: usize = 0;
        var dirIterator = dir.iterate();
        while (try dirIterator.next(env.io)) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, SERVICE_FILE_SUFFIX)) continue;
            log.debug("Found candidate: {s}", .{entry.name});
            size += 1;
        }
        log.debug("Found {d} candidates", .{size});

        var srvArray = try env.allocator.alloc(ServiceData, size);
        errdefer env.allocator.free(srvArray);

        var i: usize = 0;
        log.debug("Iterating over {d} candidates", .{size});
        dirIterator = dir.iterate();
        while (try dirIterator.next(env.io)) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, SERVICE_FILE_SUFFIX)) continue;

            const absPath = try std.fs.path.join(env.allocator, &[_][]const u8{ dirName, entry.name });
            defer env.allocator.free(absPath);

            log.debug("Parsing service {s}", .{absPath});
            const decl = parser.fromToml(env, absPath) catch {
                log.warn("Failed to parse service {s}", .{absPath});
                continue;
            };

            // log.debug("Checking for duplicate service", .{});
            var good = true;
            for (0..i) |j| {
                if (j == i) break;
                // log.debug("Checking against {d}", .{j});
                if (std.mem.eql(u8, srvArray[j].decl.name, decl.name)) {
                    log.warn("Service named {s} already exists", .{decl.name});
                    good = false;
                    break;
                }
            }
            if (!good) continue;

            // log.debug("decl={*}", .{&decl});
            // log.debug("decl.name={*}", .{&decl.name});
            // log.debug("decl.name.len={d}", .{decl.name.len});
            // log.debug("first char addr={*}", .{&decl.name[0]});
            // for (0..decl.name.len) |j| log.debug("decl.name[{d}]={c}", .{ j, decl.name[j] });
            // for (decl.name) |c| log.debug("c={c}", .{c});

            log.debug("Adding service {s} at {d}", .{ decl.name, i });
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
