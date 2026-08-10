const std = @import("std");
const os = std.os.linux;
const log = std.log.scoped(.syscall);
const system = @import("xd").system;

const ServiceTable = system.service.ServiceTable;
const syscall = system.syscall;

var active_services: ?*ServiceTable = null;

fn intoRebootSyscall(value: os.LINUX_REBOOT.CMD) void {
    //TODO: send SIGINT to `xd daemon` to trigger a shutdown
    //      wait for it to exit
    //      send SIGQUIT if it take too long

    syscall.reboot(.MAGIC1, .MAGIC2, value, null) catch {};
    syscall.reboot(.MAGIC1, .MAGIC2, .HALT, null) catch {};
    os.exit(1);
    unreachable;
}

fn triggerReboot(_: os.SIG) callconv(.c) void { intoRebootSyscall(.RESTART); }
fn triggerShutdown(_: os.SIG) callconv(.c) void { intoRebootSyscall(.POWER_OFF); }

fn reapChildren(_: os.SIG) callconv(.c) void {
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

pub fn watchServices(services: *ServiceTable) void {
    active_services = services;
}

pub fn wait() noreturn {
    var empty_mask: os.sigset_t = std.mem.zeroes(os.sigset_t);
    while (true) syscall.sigsuspend(&empty_mask);
}
