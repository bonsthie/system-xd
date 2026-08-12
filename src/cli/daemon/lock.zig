const std = @import("std");
const log = std.log.scoped(.lock);
const errno = @import("xd").system.errno;
const os = std.os.linux;
const posix = std.posix;

pub fn acquire(lock_path: [*:0]const u8) !os.fd_t {
    log.debug("Acquiring lockfile", .{});
    const _fd = try errno.wrap(os.open(lock_path, .{ .ACCMODE = .RDWR, .CREAT = true }, 0o644));
    const fd: os.fd_t = @intCast(_fd);
    errdefer _ = os.close(fd);

    _ = try errno.wrap(os.flock(fd, posix.LOCK.EX | posix.LOCK.NB));
    _ = os.ftruncate(fd, 0);
    var pid_buf: [16]u8 = undefined;
    const pid_str = try std.fmt.bufPrint(&pid_buf, "{d}\n", .{os.getpid()});
    _ = os.write(fd, pid_str.ptr, pid_str.len);

    return fd;
}

pub fn release(fd: i32) !void {
    log.debug("Releasing lockfile", .{});
    _ = os.ftruncate(fd, 0);
    _ = os.close(fd);
}
