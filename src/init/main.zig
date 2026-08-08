const std = @import("std");
const log = std.log.scoped(.main);
const os = std.os.linux;

const xd = @import("xd");
const format = xd.format;
const logModule = xd.log;
const consts = xd.consts;
const syscall = xd.system.syscall;

const init = @import("init.zig");
const debug = @import("debug.zig");

// do not move this should be in the root of the program folder
pub const std_options: std.Options = .{
    .logFn = logModule.customLogFn,
    .log_level = if (consts.debug) .debug else .info,
};

fn emergencyShell(initError: anyerror) void {
    log.err("Caught an unexpected error: {s}", .{@errorName(initError)});
    log.err("Dropping you in an emergency shell, you're on your own...", .{});

    const argv = &[_:null]?[*:0]const u8{ "/bin/sh", "-i" };
    const envp = &[_:null]?[*:0]const u8{ "PATH=/usr/sbin:/sbin:/usr/bin:/bin", "HOME=/", "TERM=linux", "XD_RECOVERY_SHELL=1" };

    syscall.execve("/bin/sh", argv, envp) catch |err| {
        log.err("Failed to execve /bin/sh: {}, rebooting...", .{err});
    };
    _ = os.sync();
    _ = os.reboot(.MAGIC1, .MAGIC2, .RESTART, null);
}

fn isFirstPhase(proc_init: *const std.process.Init) bool {
    const args = proc_init.minimal.args;
    var iter = args.iterate();
    _ = iter.skip();
    return !iter.skip();
}

const network = @import("network");

pub fn main(proc_init: std.process.Init) !void {
    var err: anyerror = error.noError;

    if (isFirstPhase(&proc_init)) {
        format.header.printHeader();
        try debug.isPid1();

        err = init.cowabunga(&init.phase1Steps, proc_init.io, proc_init.gpa, false);
    } else {
        std.log.info("Running second phase", .{});
        err = init.cowabunga(&init.phase2Steps, proc_init.io, proc_init.gpa, true);
    }

    emergencyShell(err);
}
