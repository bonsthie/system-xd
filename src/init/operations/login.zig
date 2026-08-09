const system = @import("xd").system;

const Env = system.Env;
const service = system.service;

const login_argv = &[_][]const u8{ "/bin/busybox", "login" };
const login_envp = &[_][]const u8{ "PATH=/usr/sbin:/sbin:/usr/bin:/bin", "HOME=/", "TERM=linux" };

var services = [_]service.ServiceData {
    .{ .decl = .{ .name = "console", .path = "/bin/busybox", .argv = login_argv, .envp = login_envp, .restart = .always, .tty = "/dev/console" }, .running = false, .pid = -1 },
    .{ .decl = .{ .name = "tty1",    .path = "/bin/busybox", .argv = login_argv, .envp = login_envp, .restart = .always, .tty = "/dev/tty1"    }, .running = false, .pid = -1 },
    .{ .decl = .{ .name = "tty2",    .path = "/bin/busybox", .argv = login_argv, .envp = login_envp, .restart = .always, .tty = "/dev/tty2"    }, .running = false, .pid = -1 },
    .{ .decl = .{ .name = "tty3",    .path = "/bin/busybox", .argv = login_argv, .envp = login_envp, .restart = .always, .tty = "/dev/tty3"    }, .running = false, .pid = -1 },
    .{ .decl = .{ .name = "tty4",    .path = "/bin/busybox", .argv = login_argv, .envp = login_envp, .restart = .always, .tty = "/dev/tty4"    }, .running = false, .pid = -1 },
};

pub fn start(env: Env) service.ServiceTable {
    var table = service.ServiceTable{ .services = &services, .env = env };
    table.spawnAll();
    return table;
}
