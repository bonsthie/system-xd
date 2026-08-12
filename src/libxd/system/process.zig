const std = @import("std");
const log = std.log.scoped(.process);
const os = std.os.linux;
const syscall = @import("syscall.zig");
const posix = @import("../posix.zig");

const errno = @import("errno.zig");

const OpenMode = std.Io.Dir.OpenFileOptions.Mode;

pub const Error = error{
    WriteFuncFailedWriteTTY,
    SizeWriteTestTTY,
    NewTTYOpenFail,
    ForkFailed,
};

var loginPath: ?[*:0]const u8 = null;
var loginArgs: ?[*:null]const ?[*:0]const u8 = null;

pub const ExecNative = struct {
    allocator: std.mem.Allocator,
    command: []const u8,
    args: []const []const u8 = &.{},
    environ: *const std.process.Environ.Map,

    pub fn toPosix(self: *const ExecNative) !ExecPosixOwned {
        const command = try posix.toPosixString(self.allocator, self.command);
        errdefer posix.freePosixString(self.allocator, command);

        const args = try posix.toPosixSlice(self.allocator, self.args);
        errdefer posix.freePosixSlice(self.allocator, args);

        const environ = try posix.toPosixEnviron(self.allocator, self.environ);
        errdefer posix.freePosixEnviron(self.allocator, environ);

        return .{
            .allocator = self.allocator,
            .command = command,
            .args = args,
            .environ = environ,
        };
    }
};

pub const ExecPosix = struct {
    command: ?[*:0]const u8 = null,
    args: ?[*:null]const ?[*:0]const u8 = null,
    envp: ?[*:null]const ?[*:0]const u8 = null,
};

const ExecPosixOwned = struct {
    allocator: std.mem.Allocator,
    command: [:0]u8,
    args: [:null]?[*:0]u8,
    environ: std.process.Environ.PosixBlock,

    pub fn borrow(self: *const ExecPosixOwned) ExecPosix {
        return .{
            .command = self.command.ptr,
            .args = self.args.ptr,
            .envp = self.environ.slice.ptr,
        };
    }

    pub fn deinit(self: *ExecPosixOwned) void {
        posix.freePosixString(self.allocator, self.command);
        posix.freePosixSlice(self.allocator, self.args);
        posix.freePosixEnviron(self.allocator, self.environ);

        self.* = undefined;
    }
};

pub const Exec = union(enum) {
    posix: ExecPosix,
    native: ExecNative,
};

pub const Config = struct {
    mode: OpenMode = .read_write,
    newProcess: bool = true,
    cwd: ?[*:0]const u8 = null,
    ownTty: bool = true,
};

const TTY = union(enum) {
    none,
    fd: i32,
    name: struct {
        io: std.Io,
        path: []const u8,
    },
};

pub fn spawn(exec: *const Exec, config: *const Config) !os.pid_t {
    return spawnWithTTY(.none, exec, config);
}

pub fn spawnFromFd(fd: i32, exec: *const Exec, config: *const Config) !os.pid_t {
    return spawnWithTTY(.{ .fd = fd }, exec, config);
}

pub fn spawnFromName(io: std.Io, name: []const u8, exec: *const Exec, config: *const Config) !os.pid_t {
    return spawnWithTTY(.{ .name = .{ .io = io, .path = name } }, exec, config);
}

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
    }

    if (claim_ctty) {
        const seq = "\x1b[2J\x1b[H";
        _ = os.write(fd, seq, seq.len);
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
    return try newTTY(fd_file.handle, mode, claim_ctty);
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

fn spawnWithTTY(tty: TTY, exec: *const Exec, config: *const Config) !os.pid_t {
    switch (exec.*) {
        .native => |*native_exec| {
            var owned = try native_exec.toPosix();
            defer owned.deinit();

            const posix_exec = owned.borrow();
            return spawnPosixWithTTY(tty, &posix_exec, config);
        },
        .posix => |*posix_exec| return spawnPosixWithTTY(tty, posix_exec, config),
    }
}

fn spawnPosixWithTTY(tty: TTY, exec: *const ExecPosix, config: *const Config) !os.pid_t {
    const pid = if (config.newProcess)
        errno.wrap(os.fork()) catch return error.ForkFailed
    else
        0;

    if (pid == 0) {
        _ = os.setsid();

        switch (tty) {
            .none => {},
            .fd => |fd| _ = try newTTY(fd, config.mode, config.ownTty),
            .name => |name| _ = try newTTYFromName(name.io, name.path, config.mode, config.ownTty),
        }
        // TODO set term attribute ?

        const command = exec.command orelse getDefaultCommand();
        const args = exec.args orelse getDefaultArgs();
        const default_envp = &[_:null]?[*:0]const u8{ "PATH=/usr/sbin:/sbin:/usr/bin:/bin", "HOME=/", "TERM=linux", "XD_RECOVERY_SHELL=1" };
        const envp = exec.envp orelse default_envp;

        if (config.cwd) |cwd| {
            syscall.chdir(cwd) catch {};
        }

        try syscall.execve(command, args, envp);
        os.exit(1);
    }
    return @intCast(pid);
}
