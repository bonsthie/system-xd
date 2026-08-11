///
/// small wraper around some linux function
///
const std = @import("std");
const os = std.os;
const linux = std.os.linux;
pub const errno = @import("errno.zig");

const mountMod = @import("mount.zig");
pub const MountFlags = mountMod.Flags;
pub const mount = mountMod.mount;

pub fn symlink(existing: [*:0]const u8, new: [*:0]const u8) !void {
    _ = try errno.wrap(linux.symlink(existing, new));
}

pub fn remount(dir: [*:0]const u8, flags: u32) !void {
    _ = try errno.wrap(linux.mount(@ptrFromInt(0), dir, @ptrFromInt(0), flags, 0));
}

pub fn readlink(path: [*:0]const u8, buf: []u8) !usize {
    const rc = linux.readlink(path, buf.ptr, buf.len);
    return try errno.wrap(rc);
}

pub fn umount2(special: [*:0]const u8, flags: u32) !void {
    _ = try errno.wrap(linux.umount2(special, flags));
}

pub fn chdir(path: [*:0]const u8) !void {
    _ = try errno.wrap(linux.chdir(path));
}

pub fn pivot_root(new_root: [*:0]const u8, put_old: [*:0]const u8) !void {
    _ = try errno.wrap(linux.pivot_root(new_root, put_old));
}

pub fn chroot(path: [*:0]const u8) !void {
    _ = try errno.wrap(linux.chroot(path));
}

pub fn waitpid(pid: linux.pid_t, status: *u32, flags: u32) !linux.pid_t {
    const rc = try errno.wrap(linux.waitpid(pid, status, flags));
    return @intCast(rc);
}

pub fn dup2(oldfd: i32, newfd: i32) !void {
    _ = try errno.wrap(linux.dup2(oldfd, newfd));
}

pub fn execve(path: [*:0]const u8, argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) !void {
    _ = try errno.wrap(linux.execve(path, argv, envp));
}

pub fn ioctl(fd: linux.fd_t, request: u32, arg: usize) !void {
    _ = try errno.wrap(linux.ioctl(fd, request, arg));
}

pub fn socket(domain: u32, socket_type: u32, protocol: u32) !linux.fd_t {
    return @intCast(try errno.wrap(linux.socket(domain, socket_type, protocol)));
}

pub fn bind(fd: linux.fd_t, address: *const linux.sockaddr, length: linux.socklen_t) !void {
    _ = try errno.wrap(linux.bind(fd, address, length));
}

pub fn sendto(
    fd: linux.fd_t,
    buffer: []const u8,
    flags: u32,
    address: ?*const linux.sockaddr,
    address_length: linux.socklen_t,
) !usize {
    return try errno.wrap(linux.sendto(
        fd,
        buffer.ptr,
        buffer.len,
        flags,
        address,
        address_length,
    ));
}

pub fn recvfrom(
    fd: linux.fd_t,
    buffer: []u8,
    flags: u32,
    address: ?*linux.sockaddr,
    address_length: ?*linux.socklen_t,
) !usize {
    return try errno.wrap(linux.recvfrom(
        fd,
        buffer.ptr,
        buffer.len,
        flags,
        address,
        address_length,
    ));
}

pub fn close(fd: linux.fd_t) void {
    _ = linux.close(fd);
}

pub const SigHandlerFn = @TypeOf(@as(linux.Sigaction, undefined).handler.handler);

pub fn signal(sig: linux.SIG, handler: SigHandlerFn) !SigHandlerFn {
    const act = linux.Sigaction{
        .handler = .{ .handler = handler },
        .mask = std.mem.zeroes(linux.sigset_t),
        .flags = 0,
    };
    var old: linux.Sigaction = undefined;
    _ = try errno.wrap(linux.sigaction(sig, &act, &old));
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
    _ = try errno.wrap(rc);
}

const SYS_swapon = 167;

pub fn swapon(path: [*:0]const u8, flags: u32) !void {
    const rc = linux.syscall2(
        @enumFromInt(SYS_swapon),
        @intFromPtr(path),
        flags,
    );
    _ = try errno.wrap(rc);
}

const SYS_sethostname = 170;

pub fn sethostname(name: [*:0]const u8, len: usize) !void {
    const rc = linux.syscall2(
        @enumFromInt(SYS_sethostname),
        @intFromPtr(name),
        @intCast(len),
    );
    _ = try errno.wrap(rc);
}

pub fn reboot(
    magic1: linux.LINUX_REBOOT.MAGIC1,
    magic2: linux.LINUX_REBOOT.MAGIC2,
    command: linux.LINUX_REBOOT.CMD,
    arg: ?*const anyopaque,
) !void {
    _ = try errno.wrap(linux.reboot(magic1, magic2, command, arg));
}

pub fn clock_settime(clock_id: linux.clockid_t, timestamp: *const linux.timespec) !void {
    _ = try errno.wrap(linux.clock_settime(clock_id, timestamp));
}

const SYS_sigsuspend = 130;

pub fn sigsuspend(mask: *const linux.sigset_t) void {
    _ = linux.syscall1(
        @enumFromInt(SYS_sigsuspend),
        @intFromPtr(mask),
    );
}
