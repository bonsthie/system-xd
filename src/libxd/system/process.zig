const std = @import("std");
const log = std.log.scoped(.process);
const os = std.os.linux;
const syscall = @import("syscall.zig");

const errno = @import("errno.zig");

const OpenMode = std.Io.Dir.OpenFileOptions.Mode;

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
            return error.TTYClaimFail;
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
