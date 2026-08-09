const std = @import("std");
const os = std.os.linux;
const log = std.log.scoped(.syscall);
const system = @import("xd").system;

const ServiceTable = system.service.ServiceTable;
const syscall = system.syscall;

var active_services: ?*ServiceTable = null;

//TODO: wire those
fn triggerReboot(_: os.SIG) callconv(.c) void {}
fn triggerShutdown(_: os.SIG) callconv(.c) void {}
fn triggerHalt(_: os.SIG) callconv(.c) void {}

fn reapChildren(_: os.SIG) callconv(.c) void {
    if (active_services) |services| services.reap();
}

pub fn setupSignalHandlers() !void {
    const handlers = .{
        .{ os.SIG.INT, triggerReboot },
        .{ os.SIG.TERM, triggerReboot },
        .{ os.SIG.USR1, triggerShutdown },
        .{ os.SIG.USR2, triggerHalt },
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
