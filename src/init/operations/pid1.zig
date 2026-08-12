const std = @import("std");
const os = std.os.linux;
const log = std.log.scoped(.pid1);
const xd = @import("xd");
const system = xd.system;
const process = system.process;
const Env = system.Env;

const ServiceTable = system.service.ServiceTable;
const TIMEOUT_NS = system.service.table.TIMEOUT_NS;
const syscall = system.syscall;

var daemon_pid: ?os.pid_t = null;

fn intoRebootSyscall(value: os.LINUX_REBOOT.CMD) void {
    log.debug("Sending SIGINT to daemon (pid {d})", .{daemon_pid.?});
    _ = os.kill(daemon_pid.?, os.SIG.INT);
    log.debug("Waiting for daemon to exit", .{});
    if (!ServiceTable.waitForExit(daemon_pid.?, TIMEOUT_NS)) {
        log.warn("Daemon (pid {d}) did not exit in time, sending SIGKILL", .{daemon_pid.?});
        _ = os.kill(daemon_pid.?, os.SIG.KILL);
        _ = ServiceTable.waitForExit(daemon_pid.?, TIMEOUT_NS);
    }
    log.debug("Daemon exited, rebooting (val={d})", .{value});
    syscall.reboot(.MAGIC1, .MAGIC2, value, null) catch |err| {
        log.err("Failed to reboot: {s}", .{@errorName(err)});
    };
    log.debug("That didn't work, rebooting with HALT", .{});
    syscall.reboot(.MAGIC1, .MAGIC2, .HALT, null) catch |err| {
        log.err("Failed to reboot with HALT: {s}", .{@errorName(err)});
    };
    log.debug("That didn't work, looping forever", .{});
    while (true) {
        syscall.reboot(.MAGIC1, .MAGIC2, .HALT, null) catch {};
    }
    unreachable;
}

fn triggerReboot(_: os.SIG) callconv(.c) void {
    intoRebootSyscall(.RESTART);
}

fn triggerShutdown(_: os.SIG) callconv(.c) void {
    intoRebootSyscall(.POWER_OFF);
}

fn reapChildren(_: os.SIG) callconv(.c) void {
    log.info("reaping children", .{});
    while (true) {
        var status: u32 = 0;
        const pid = syscall.waitpid(-1, &status, os.W.NOHANG) catch break;
        if (pid <= 0) break;
    }
}

pub fn setupSignalHandlers() !void {
    const handlers = .{
        .{ os.SIG.INT, triggerReboot },
        .{ os.SIG.TERM, triggerReboot },
        .{ os.SIG.USR1, triggerShutdown },
        .{ os.SIG.USR2, triggerShutdown },
        .{ os.SIG.CHLD, reapChildren },
    };
    inline for (handlers) |handler| {
        _ = syscall.signal(handler[0], handler[1]) catch |err| {
            log.err("Failed to setup SIG{s} handler: {s}", .{ @tagName(handler[0]), @errorName(err) });
        };
    }
}

pub fn disableCad() !void {
    _ = try syscall.reboot(.MAGIC1, .MAGIC2, .CAD_OFF, null);
}

pub fn startAndWatchDaemon(env: Env) !void {
    daemon_pid = try process.spawnFromFd(1, &.{ .native = .{
        .allocator = env.allocator,
        .command = "/sbin/xd",
        .args = &[_][]const u8{ "/sbin/xd", "daemon" },
        .environ = @constCast(env.environ),
    } }, &.{
        .mode = .write_only,
        .ownTty = false,
        .cwd = "/",
    });
    log.info("Started daemon with pid {d}", .{daemon_pid.?});
}

pub fn wait() noreturn {
    var empty_mask: os.sigset_t = std.mem.zeroes(os.sigset_t);
    while (true) syscall.sigsuspend(&empty_mask);
}
