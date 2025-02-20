///
/// small wraper around some linux function
///
const std = @import("std");
const os = std.os;
const linux = std.os.linux;
const wrapErrno = @import("errno.zig").wrapErrno;

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

pub fn dup2(oldfd: i32, newfd: i32) !void {
    _ = try wrapErrno(linux.dup2(oldfd, newfd));
}

pub fn execve(path: [*:0]const u8, argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) !void {
    _ = try wrapErrno(linux.execve(path, argv, envp));
}

pub fn ioctl(fd: os.linux.fd_t, request: u32, arg: usize) !void {
    _ = try wrapErrno(linux.ioctl(fd, request, arg));
}
