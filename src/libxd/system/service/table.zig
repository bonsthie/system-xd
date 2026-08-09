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

pub const ServiceTable = struct {
    services: []Service,
    env: Env,

    pub fn spawnAll(self: *ServiceTable) void {
        for (self.services) |*svc| {
            self.spawn(svc) catch |err| {
                log.err("Failed to spawn service {s}: {s}", .{ svc.name, @errorName(err) });
            };
        }
    }

    fn spawn(self: *ServiceTable, svc: *Service) !void {
        const pid = os.fork();
        if (pid < 0) { // b-but zig has errors built into its type system!!!! yes and i don't have another month to spare so fuck you, C my beloved<3
            log.err("Failed to fork for service {s}", .{svc.name});
            return;
        }
        if (pid == 0) {
            _ = os.setsid();
            if (svc.tty) |tty_path| {
                _ = process.newTTYFromName(self.env.io, tty_path, .read_write, true) catch os.exit(1);
            }
            
            const cPath = try self.env.allocator.dupeZ(u8, svc.path);
            const cArgv = try syscall.toPosixSlice(self.env.allocator, svc.argv);
            const cEnvp = try syscall.toPosixSlice(self.env.allocator, svc.envp);

            try syscall.execve(cPath, cArgv, cEnvp);
            os.exit(1);
        }
        svc.pid = @intCast(pid);
        log.info("Started service {s} (pid {d})", .{ svc.name, svc.pid });
    }

    fn findByPid(self: *ServiceTable, pid: os.pid_t) ?*Service {
        for (self.services) |*svc| {
            if (svc.pid == pid) return svc;
        }
        return null;
    }

    pub fn reap(self: *ServiceTable) void {
        while (true) {
            var status: u32 = 0;
            const pid = syscall.waitpid(-1, &status, os.W.NOHANG) catch break;
            if (pid <= 0) break;

            if (self.findByPid(pid)) |svc| {
                log.warn("Service {s} (pid {d}) exited, status {d}", .{ svc.name, pid, os.W.EXITSTATUS(status) });
                svc.pid = -1;
                switch (svc.restart) {
                    .always => self.spawn(svc) catch |err| {
                        svc.pid = -1;
                        log.err("Failed to spawn service {s}: {s}", .{ svc.name, @errorName(err) });
                    },
                    .never => {},
                }
            } else {
                log.debug("Reaped untracked pid {d}, status {d}", .{ pid, status });
            }
        }
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

        var srvArray = try env.allocator.alloc(Service, size);
        errdefer env.allocator.free(srvArray);

        var i: usize = 0;
        dirIterator = dir.iterate();
        while (try dirIterator.next(env.io)) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, SERVICE_FILE_SUFFIX)) continue;

            const absPath = try std.fs.path.join(env.allocator, &[_][]const u8{ dirName, entry.name });
            defer env.allocator.free(absPath);

            srvArray[i] = try parser.fromToml(env, absPath);
            i += 1;
        }

        return ServiceTable{ .services = srvArray[0..i], .env = env };
    }
};
