const std = @import("std");
const log = std.log.scoped(.main);
const os = std.os.linux;
const zos = @import("os/linux.zig");
const init = @import("init.zig");
const debug = @import("debug.zig");

const format = @import("xd").format;

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

fn isFirstPhase(proc_init: *const std.process.Init) bool {
    const args = proc_init.minimal.args;
    const iter = args.iterator();
    _ = iter.skip();
    return !iter.skip();
}

const network = @import("network");

pub fn main(proc_init: std.process.Init) !void {
    var err: anyerror = error.noError;

    if (isFirstPhase(&proc_init)) {
        format.header.printHeader();
        try debug.isPid1();

        err = init.cowabunga(&init.phase1Steps, proc_init.io, proc_init.allocator);
    } else {
        err = init.cowabunga(&init.phase1Steps, proc_init.io, proc_init.allocator);
    }

    emergencyShell(err);
}
