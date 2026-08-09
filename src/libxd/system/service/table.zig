const std = @import("std");
const os = std.os.linux;
const syscall = @import("../syscall.zig");
const log = std.log.scoped(.service);
const process = @import("../process.zig");

const service = @import("service.zig");

pub const RestartPolicy = service.RestartPolicy;
pub const Service = service.Service;

pub const ServiceTable = struct {
    services: []Service,
    io: std.Io,

    pub fn spawnAll(self: *ServiceTable) void {
        for (self.services) |*svc| self.spawn(svc);
    }

    fn spawn(self: *ServiceTable, svc: *Service) void {
        const pid = os.fork();
        if (pid < 0) { // b-but zig has errors built into its type system!!!! yes and i don't have another month to spare so fuck you, C my beloved<3
            log.err("Failed to fork for service {s}", .{svc.name});
            return;
        }
        if (pid == 0) {
            _ = os.setsid();
            if (svc.tty) |tty_path| {
                _ = process.newTTYFromName(self.io, tty_path, .read_write, true) catch os.exit(1);
            }
            syscall.execve(svc.path, svc.argv, svc.envp) catch {};
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
                    .always => self.spawn(svc),
                    .never => {},
                }
            } else {
                log.debug("Reaped untracked pid {d}, status {d}", .{ pid, status });
            }
        }
    }
};
