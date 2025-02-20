const std = @import("std");
const log = std.log.scoped(.main);
const os = std.os.linux;
const zos = @import("os/linux.zig");
const consts = @import("consts.zig");
const network = @import("network");
const header = @import("format/header.zig");
const init = @import("init.zig");

const customLogFn = @import("log.zig").customLogFn;

pub const std_options = .{
    .logFn = customLogFn,
    .log_level = if (consts.debug) .debug else .info,
};

fn emergencyShell() void {
    const argv = &[_:null]?[*:0]const u8{ "/bin/sh", "-i" };
    const envp = &[_:null]?[*:0]const u8{ "PATH=/usr/sbin:/sbin:/usr/bin:/bin", "HOME=/", "TERM=linux", "XD_RECOVERY_SHELL=1" };

    zos.execve("/bin/sh", argv, envp) catch |err| {
        log.err("Failed to execve /bin/sh: {}, rebooting...", .{err});
    };
    _ = os.sync();
    _ = os.reboot(.MAGIC1, .MAGIC2, .RESTART, null);
}

fn isPid1() !void {
    const pid = os.getpid();
    log.debug("PID: {d}", .{pid});
    if (pid != 1) {
        if (consts.debug) {
            log.debug("Bypassing PID check because program was compiled in debug mode", .{});
        } else {
            log.err("This program must be run as PID 1", .{});
            return error.notPid1;
        }
    }
}

pub fn main() !void {
    header.printHeader(.main);
    try isPid1();
    log.info("got da network {}", .{network});

    init.cowabunga() catch |err| {
        log.err("Caught an unexpected error: {s}", .{@errorName(err)});
        log.err("Dropping you in an emergency shell, you're on your own...", .{});
        emergencyShell();
    };
}
