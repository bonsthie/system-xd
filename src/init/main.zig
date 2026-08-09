const std = @import("std");
const log = std.log.scoped(.main);
const os = std.os.linux;

const xd = @import("xd");
const format = xd.format;
const logModule = xd.log;
const consts = xd.consts;
const syscall = xd.system.syscall;

const phase = @import("phase/phase.zig");
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
    syscall.reboot(.MAGIC1, .MAGIC2, .RESTART, null) catch {};
}

fn isFirstPhase(proc_init: *const std.process.Init) bool {
    const args = proc_init.minimal.args;
    var iter = args.iterate();
    _ = iter.skip();
    return !iter.skip();
}

const network = @import("network");

pub fn main(proc_init: std.process.Init) !void {
    const env = xd.system.Env{ .io = proc_init.io, .allocator = proc_init.gpa };

    if (isFirstPhase(&proc_init)) {
        format.header.printHeader();
        try debug.isPid1();

        phase.run(.initramfs, env) catch |err| {
            emergencyShell(err);
            return;
        };
        emergencyShell(error.Phase1Returned);
        return;
    }

    std.log.info("Running second phase", .{});
    phase.run(.system, env) catch |err| {
        emergencyShell(err);
        return;
    };
}
