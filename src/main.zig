const std = @import("std");
const log = std.log.scoped(.main);
const os = std.os.linux;
const zos = @import("os/linux.zig");
const consts = @import("consts.zig");
const network = @import("network");
const init = @import("init.zig");
const debug = @import("debug.zig");

const header = @import("format/header.zig");
const _ = @import("log.zig");

fn emergencyShell(initError: anyerror) void {
    log.err("Caught an unexpected error: {s}", .{@errorName(initError)});
    log.err("Dropping you in an emergency shell, you're on your own...", .{});

    const argv = &[_:null]?[*:0]const u8{ "/bin/sh", "-i" };
    const envp = &[_:null]?[*:0]const u8{ "PATH=/usr/sbin:/sbin:/usr/bin:/bin", "HOME=/", "TERM=linux", "XD_RECOVERY_SHELL=1" };

    zos.execve("/bin/sh", argv, envp) catch |err| {
        log.err("Failed to execve /bin/sh: {}, rebooting...", .{err});
    };
    _ = os.sync();
    _ = os.reboot(.MAGIC1, .MAGIC2, .RESTART, null);
}

fn isFirstPhase() bool {
    var args = std.process.args();
    defer args.deinit();
    _ = args.skip();
    return !args.skip();
}

pub fn main() !void {
    var err: anyerror = error.noError;

    if (isFirstPhase()) {
        header.printHeader(.main);
        try debug.isPid1();

        log.info("got da network {}", .{network});

        err = init.cowabunga(&init.phase1Steps);
    } else {
        err = init.cowabunga(&init.phase1Steps);
    }

    emergencyShell(err);
}
