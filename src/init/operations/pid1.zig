const std = @import("std");
const os = std.os.linux;
const system = @import("xd").system;

const ServiceTable = system.service.ServiceTable;
const syscall = system.syscall;

var active_services: ?*ServiceTable = null;

fn triggerReboot(_: os.SIG) callconv(.c) void {}

fn reapChildren(_: os.SIG) callconv(.c) void {
    if (active_services) |services| services.reap();
}

pub fn setupSignalHandlers() !void {
    _ = try syscall.signal(os.SIG.INT, triggerReboot);
    _ = try syscall.signal(os.SIG.CHLD, reapChildren);
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
