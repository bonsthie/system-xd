const std = @import("std");
const log = std.log.scoped(.process);
const os = std.os.linux;
const syscall = @import("syscall.zig");

const errno = @import("errno.zig");

const OpenMode = std.Io.Dir.OpenFileOptions.Mode;

pub const Error = error{
    WriteFuncFailedWriteTTY,
    SizeWriteTestTTY,
    NewTTYOpenFail,
    ForkFailedTTY,
};

var loginPath: ?[*:0]const u8 = null;
var loginArgs: ?[*:null]const ?[*:0]const u8 = null;

pub const Config = struct {
    io: std.Io,
    command: ?[*:0]const u8 = null,
    args: ?[*:null]const ?[*:0]const u8 = null,
    mode: OpenMode = .read_write,
    newProcess: bool = true,

    filename: ?[]const u8 = null,
    fd: i32 = 0,
};

fn writeTestTTY(fd: i32) !void {
    const ret = errno.wrap(os.write(fd, "\x00\x00\x00\x00\n", 5)) catch {
        return error.WriteFuncFailedWriteTTY;
    };

    if (ret == 5) {
        return;
    } else {
        log.debug("Fail only {} bytes write on 5 in fd[{}]", .{ ret, fd });
        return error.SizeWriteTestTTY;
    }
}

pub fn newTTY(fd: i32, mode: OpenMode, claim_ctty: bool) !i32 {
    if (mode == .read_only or mode == .read_write) {
        try syscall.dup2(fd, os.STDIN_FILENO);
    }
    if (mode == .write_only or mode == .read_write) {
        try syscall.dup2(fd, os.STDOUT_FILENO);
        try syscall.dup2(fd, os.STDERR_FILENO);
        const seq = "\x1b[2J\x1b[H";
        _ = os.write(fd, seq, seq.len);
    }

    if (claim_ctty) {
        const TIOCSCTTY: u32 = 0x540E;
        syscall.ioctl(fd, TIOCSCTTY, 0) catch |err| {
            log.err("TIOCSCTTY failed on fd {d}: {s}", .{ fd, @errorName(err) });
            return err;
        };
    }

    return fd;
}

pub fn newTTYFromName(io: std.Io, file: []const u8, mode: OpenMode, claim_ctty: bool) !i32 {
    const fd_file = std.Io.Dir.openFileAbsolute(io, file, .{ .mode = mode }) catch |err| {
        log.debug("{s} open fail : {}", .{ file, err });
        return error.NewTTYOpenFail;
    };
    defer if (fd_file.handle > 2) fd_file.close(io);
    const ret = try newTTY(fd_file.handle, mode, claim_ctty);
    log.info("{s} is created successfully", .{file});
    return ret;
}

fn getDefaultCommand() [*:0]const u8 {
    if (loginPath == null)
        loginPath = "/bin/busybox".ptr;
    return loginPath.?;
}

fn getDefaultArgs() [*:null]const ?[*:0]const u8 {
    const default = &[_:null]?[*:0]const u8{ "login", null };
    if (loginArgs == null)
        loginArgs = default;
    return loginArgs.?;
}

pub fn spawn(config: *const Config) !usize {
    const pid = if (config.newProcess) os.fork() else 0;

    if (pid < -1) {
        return error.ForkFailedTTY;
    } else if (pid == 0) {
        _ = os.setsid();

        if (config.fd != 0) {
            _ = try newTTY(config.fd, config.mode);
        } else {
            _ = try newTTYFromName(config.io, config.filename.?, config.mode);
        }
        // TODO set term attribute ?

        const command = config.command orelse getDefaultCommand();
        const args = config.args orelse getDefaultArgs();
        const envp = &[_:null]?[*:0]const u8{ "PATH=/usr/sbin:/sbin:/usr/bin:/bin", "HOME=/", "TERM=linux", "XD_RECOVERY_SHELL=1" };
        try syscall.execve(command, args, envp);
        os.exit(1);
    }
    return pid;
}
