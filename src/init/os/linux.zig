///
/// small wraper around some linux function
///
const std = @import("std");
const os = std.os;
const linux = std.os.linux;
const wrapErrno = @import("errno.zig").wrapErrno;

pub const MountFlags = enum(u32) {
    MS_RDONLY = 1, // Mount read-only.
    MS_NOSUID = 2, // Ignore suid and sgid bits.
    MS_NODEV = 4, // Disallow access to device special files.
    MS_NOEXEC = 8, // Disallow program execution.
    MS_SYNCHRONOUS = 16, // Writes are synced at once.
    MS_REMOUNT = 32, // Alter flags of a mounted FS.
    MS_MANDLOCK = 64, // Allow mandatory locks on an FS.
    S_WRITE = 128, // Write on file/directory/symlink.
    S_APPEND = 256, // Append-only file.
    S_IMMUTABLE = 512, // Immutable file.
    MS_NOATIME = 1024, // Do not update access times.
    MS_NODIRATIME = 2048, // Do not update directory access times.
    MS_BIND = 4096, // Bind directory at different place.
    MS_MOVE = 8192,
    MS_REC = 16384,
    MS_SILENT = 32768,
    MS_POSIXACL = (1<<16),
    MS_UNBINDABLE = (1<<17),
    MS_PRIVATE = (1<<18),
    MS_SLAVE = (1<<19),
    MS_SHARED = (1<<20),
    MS_RELATIME = (1<<21),
    MS_KERNMOUNT = (1<<22),
    MS_I_VERSION = (1<<23),
    MS_STRICTATIME = (1<<24),
    MS_LAZYTIME = (1<<25),
    MS_NOREMOTELOCK = (1<<27),
    MS_NOSEC = (1<<28),
    MS_BORN = (1<<29),
    MS_ACTIVE = (1<<30),
    MS_NOUSER = (1<<31),
};

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

pub fn mount(special: [*:0]const u8, dir: [*:0]const u8, fstype: ?[*:0]const u8, flags: u32, data: usize) !void {
    _ = try wrapErrno(linux.mount(special, dir, fstype, flags, data));
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
