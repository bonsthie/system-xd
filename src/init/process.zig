const std = @import("std");
const log = std.log.scoped(.process);
const os = std.os.linux;
const zos = @import("os/linux.zig");
const fs = std.fs;
const OpenMode = std.Io.Dir.OpenFileOptions.Mode;

const wrapErrno = @import("os/errno.zig").wrapErrno;

pub const Error = error{
    WriteFuncFailedWriteTTY,
    SizeWriteTestTTY,
    NewTTYOpenFail,
    ForkFailedTTY,
};

var loginPath: ?[*:0]const u8 = null;
var loginArgs: ?[*:null]const ?[*:0]const u8 = null;

pub const ProcessConfig = struct {
    command: ?[*:0]const u8 = null,
    args: ?[*:null]const ?[*:0]const u8 = null,
    mode: OpenMode = .read_write,
    newProcess: bool = true,

    filename: ?[]const u8 = null,
    fd: i32 = 0,
};

fn writeTestTTY(fd: i32) !void {
    const ret = wrapErrno(os.write(fd, "\x00\x00\x00\x00\n", 5)) catch {
        return error.writeFuncFaildWriteTTY;
    };

    if (ret == 5) {
        return;
    } else {
        log.debug("Fail only {} bytes write on 5 in fd[{}]", .{ ret, fd });
        return error.sizeWriteTestTTY;
    }
}

pub fn newTTY(fd: i32, mode: OpenMode) !i32 {
    log.debug("dup {}", .{mode});
    if (mode == .read_only or mode == .read_write) {
        try zos.dup2(fd, os.STDIN_FILENO);
    }

    if (mode == .write_only or mode == .read_write) {
        try zos.dup2(fd, os.STDOUT_FILENO);
        try writeTestTTY(os.STDOUT_FILENO);
        try zos.dup2(fd, os.STDERR_FILENO);
        try writeTestTTY(os.STDERR_FILENO);
    }

    // set the /dev/console as the controling terminal
    const TIOCSCTTY: u32 = 0x540E; // can't find it in os. (skill issue)
    // _ = try wrapErrno(os.ioctl(fd, TIOCSCTTY, 0)); // mark as error even when working ??
    _ = os.ioctl(fd, TIOCSCTTY, 0);

    return fd;
}

pub fn newTTYFromName(file: []const u8, mode: OpenMode) !i32 {
    const fd = fs.cwd().openFile(file, .{ .mode = mode }) catch |err| {
        log.debug("{s} open fail : {}", .{ file, err });
        return error.newTTYOpenFail;
    };
    defer if (fd.handle > 2) fd.close();
    const ret = try newTTY(fd.handle, mode);
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

pub fn spawnProcess(
    config: *const ProcessConfig,
) !usize {
    const pid = if (config.newProcess) os.fork() else 0;

    if (pid < -1) {
        return error.ForkFailedTTY;
    } else if (pid == 0) {
        _ = os.setsid();

        if (config.fd != 0) {
            _ = try newTTY(config.fd, config.mode);
        } else {
            _ = try newTTYFromName(config.filename.?, config.mode);
        }
        // TODO set term attribute ?

        const command = config.command orelse getDefaultCommand();
        const args = config.args orelse getDefaultArgs();
        const envp = &[_:null]?[*:0]const u8{ "PATH=/usr/sbin:/sbin:/usr/bin:/bin", "HOME=/", "TERM=linux", "XD_RECOVERY_SHELL=1" };
        try zos.execve(command, args, envp);
        os.exit(1);
    }
    return pid;
}
