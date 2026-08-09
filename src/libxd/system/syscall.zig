///
/// small wraper around some linux function
///
const std = @import("std");
const os = std.os;
const linux = std.os.linux;
pub const errno = @import("errno.zig");
const wrapErrno = errno.wrapErrno;

pub const MountFlags = @import("mount.zig").Flags;
pub const mount = @import("mount.zig").mount;

pub fn toPosixSlice(allocator: std.mem.Allocator, strings: [][]const u8) ![*:0]const [*:0]const u8 {
    const len = strings.len;
    var ptrs = try allocator.alloc([*:0]const u8, len + 1);

    for (strings, 0..) |s, i| {
        ptrs[i] = try allocator.dupeZ(u8, s);
    }
    ptrs[len] = null;

    return ptrs.ptr;
}

pub fn symlink(existing: [*:0]const u8, new: [*:0]const u8) !void {
    _ = try wrapErrno(linux.symlink(existing, new));
}

pub fn remount(dir: [*:0]const u8, flags: u32) !void {
    _ = try wrapErrno(linux.mount(@ptrFromInt(0), dir, @ptrFromInt(0), flags, 0));
}

pub fn readlink(path: [*:0]const u8, buf: []u8) !usize {
    const rc = linux.readlink(path, buf.ptr, buf.len);
    return try wrapErrno(rc);
}

pub fn umount2(special: [*:0]const u8, flags: u32) !void {
    _ = try wrapErrno(linux.umount2(special, flags));
}

pub fn chdir(path: [*:0]const u8) !void {
    _ = try wrapErrno(linux.chdir(path));
}

pub fn pivot_root(new_root: [*:0]const u8, put_old: [*:0]const u8) !void {
    _ = try wrapErrno(linux.pivot_root(new_root, put_old));
}

pub fn chroot(path: [*:0]const u8) !void {
    _ = try wrapErrno(linux.chroot(path));
}

pub fn waitpid(pid: linux.pid_t, status: *u32, flags: u32) !linux.pid_t {
    const rc = try wrapErrno(linux.waitpid(pid, status, flags));
    return @intCast(rc);
}

pub fn dup2(oldfd: i32, newfd: i32) !void {
    _ = try wrapErrno(linux.dup2(oldfd, newfd));
}

pub fn execve(path: [*:0]const u8, argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) !void {
    _ = try wrapErrno(linux.execve(path, argv, envp));
}

pub fn ioctl(fd: linux.fd_t, request: u32, arg: usize) !void {
    _ = try wrapErrno(linux.ioctl(fd, request, arg));
}

pub const SigHandlerFn = @TypeOf(@as(linux.Sigaction, undefined).handler.handler);

pub fn signal(sig: linux.SIG, handler: SigHandlerFn) !SigHandlerFn {
    const act = linux.Sigaction{
        .handler = .{ .handler = handler },
        .mask = std.mem.zeroes(linux.sigset_t),
        .flags = 0,
    };
    var old: linux.Sigaction = undefined;
    _ = try wrapErrno(linux.sigaction(sig, &act, &old));
    return old.handler.handler;
}

const SYS_finit_module = 313; // x86_64

pub fn finit_module(fd: linux.fd_t, param_values: [*:0]const u8, flags: u32) !void {
    const rc = linux.syscall3(
        @enumFromInt(SYS_finit_module),
        @intCast(fd),
        @intFromPtr(param_values),
        flags,
    );
    _ = try wrapErrno(rc);
}

const SYS_swapon = 167;

pub fn swapon(path: [*:0]const u8, flags: u32) !void {
    const rc = linux.syscall2(
        @enumFromInt(SYS_swapon),
        @intFromPtr(path),
        flags,
    );
    _ = try wrapErrno(rc);
}

const SYS_sethostname = 170;

pub fn sethostname(name: [*:0]const u8, len: usize) !void {
    const rc = linux.syscall2(
        @enumFromInt(SYS_sethostname),
        @intFromPtr(name),
        @intCast(len),
    );
    _ = try wrapErrno(rc);
}

pub fn reboot(
    magic1: linux.LINUX_REBOOT.MAGIC1,
    magic2: linux.LINUX_REBOOT.MAGIC2,
    command: linux.LINUX_REBOOT.CMD,
    arg: ?*const anyopaque,
) !void {
    _ = try wrapErrno(linux.reboot(magic1, magic2, command, arg));
}

pub fn clock_settime(clock_id: linux.clockid_t, timestamp: *const linux.timespec) !void {
    _ = try wrapErrno(linux.clock_settime(clock_id, timestamp));
}

const SYS_sigsuspend = 130;

pub fn sigsuspend(mask: *const linux.sigset_t) void {
    _ = linux.syscall1(
        @enumFromInt(SYS_sigsuspend),
        @intFromPtr(mask),
    );
}
