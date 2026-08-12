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

    _ = os.sync();

    const console = os.open("/dev/console", .{ .ACCMODE = .RDWR, .CREAT = false }, 0);
    if (console >= 0) {
        const console_fd: i32 = @intCast(console);
        _ = os.dup2(console_fd, os.STDIN_FILENO);
        _ = os.dup2(console_fd, os.STDOUT_FILENO);
        _ = os.dup2(console_fd, os.STDERR_FILENO);
        _ = os.close(console_fd);
    }

    const fd = os.open("/bin/sh", .{ .ACCMODE = .RDONLY, .CREAT = false }, 0);
    if (fd < 0) {
        log.err("No /bin/sh available, ouchie.", .{});
        syscall.reboot(.MAGIC1, .MAGIC2, .HALT, null) catch {};
        return;
    }
    _ = os.close(@intCast(fd));

    const argv = &[_:null]?[*:0]const u8{ "/bin/busybox", "sh", "-i" };
    const envp = &[_:null]?[*:0]const u8{ "PATH=/usr/sbin:/sbin:/usr/bin:/bin", "HOME=/", "TERM=linux", "XD_RECOVERY_SHELL=1" };

    syscall.execve("/bin/busybox", argv, envp) catch |err| {
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
    const env = xd.system.Env{
        .io = proc_init.io,
        .allocator = proc_init.gpa,
        .environ = proc_init.environ_map,
    };

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
