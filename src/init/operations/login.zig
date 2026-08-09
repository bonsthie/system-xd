const system = @import("xd").system;

const Env = system.Env;
const service = system.service;

const login_argv = &[_][]const u8{ "/bin/busybox", "login" };
const login_envp = &[_][]const u8{ "PATH=/usr/sbin:/sbin:/usr/bin:/bin", "HOME=/", "TERM=linux" };

var tty_services = [_]service.Service{
    .{ .name = "console", .path = "/bin/busybox", .argv = login_argv, .envp = login_envp, .tty = "/dev/console" },
    .{ .name = "tty1", .path = "/bin/busybox", .argv = login_argv, .envp = login_envp, .tty = "/dev/tty1" },
    .{ .name = "tty2", .path = "/bin/busybox", .argv = login_argv, .envp = login_envp, .tty = "/dev/tty2" },
    .{ .name = "tty3", .path = "/bin/busybox", .argv = login_argv, .envp = login_envp, .tty = "/dev/tty3" },
    .{ .name = "tty4", .path = "/bin/busybox", .argv = login_argv, .envp = login_envp, .tty = "/dev/tty4" },
};

pub fn start(env: Env) service.ServiceTable {
    var table = service.ServiceTable{ .services = &tty_services, .env = env };
    table.spawnAll();
    return table;
}
