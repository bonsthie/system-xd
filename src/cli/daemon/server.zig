const std = @import("std");
const os = std.os.linux;
const log = std.log.scoped(.daemon);

const xd = @import("xd");
const service = xd.service;
const errno = xd.system.errno;
const Env = xd.system.Env;
const ServiceTable = service.ServiceTable;
const syscall = xd.system.syscall;

const lock = @import("lock.zig");
const messageModule = @import("message.zig");
const Message = messageModule.Message;
const MessageReply = messageModule.MessageReply;
const MessageType = messageModule.MessageType;

var current_server: ?*DaemonServer = null;

pub const SOCKET_DIR = "/tmp"; //TODO: "/run/xd";
pub const SOCKET_PATH = SOCKET_DIR ++ "/xdaemon.sock";
pub const LOCKFILE_PATH: [*:0]const u8 = SOCKET_DIR ++ "/xdaemon.pid";

fn signalHandler(sig: os.SIG) callconv(.c) void {
    if (current_server) |server| {
        if (sig == os.SIG.CHLD) server.reap = true;
        if (sig == os.SIG.INT) server.running = false;
    }
}

var buffer: [1024]u8 = std.mem.zeroes([1024]u8);

pub const DaemonServer = struct {
    socket: os.socket_t,
    lock_fd: i32,
    services: service.ServiceTable,
    env: Env,
    running: bool = true,
    reap: bool = false,

    pub fn run(self: *DaemonServer) !void {
        current_server = self;
        defer lock.release(self.lock_fd) catch {};

        log.debug("Initializing services", .{});
        self.services.spawnAll();

        log.info("Running daemon server...", .{});
        while (self.running) {
            if (self.reap) self.services.reap(self.running);
            self.reap = false;
            const client_fd_raw = os.accept(self.socket, null, null);
            const signed: isize = @bitCast(client_fd_raw);
            if (signed < 0) {
                const err_num: usize = @intCast(-signed);
                if (err_num == @intFromEnum(os.E.INTR)) continue;
                std.log.err("accept failed, errno={d}", .{err_num});
                continue;
            }
            const client_fd: i32 = @intCast(signed);
            defer _ = os.close(client_fd);
            log.info("New client connected, fd={d}", .{client_fd});
            self.handleClient(client_fd) catch |err| {
                log.err("Failed to handle client, fd={d}, err={}", .{ client_fd, err });
                continue;
            };
        }
        if (self.reap) self.services.reap(self.running);

        log.debug("Shutting down services", .{});
        self.services.shutdown();

        log.debug("Shutdown complete", .{});
    }

    fn read(client_fd: i32, buf: [*]u8, size: usize) !usize {
        var n_read: usize = 0;
        while (n_read < size) {
            const signed: isize = @intCast(os.read(client_fd, buf[n_read..], size - n_read));
            if (signed == 0) break;
            if (signed < 0) {
                const err_num: usize = @intCast(-signed);
                if (err_num == @intFromEnum(os.E.INTR)) continue;
                std.log.err("read failed, errno={d}", .{err_num});
                return error.SyscallFailed;
            }
            n_read += @intCast(signed);
        }
        return n_read;
    }

    fn write(client_fd: i32, buf: [*]const u8, size: usize) !usize {
        var n_written: usize = 0;
        while (n_written < size) {
            const signed: isize = @bitCast(os.write(client_fd, buf[n_written..], size - n_written));
            if (signed == 0) break;
            if (signed < 0) {
                const err_num: usize = @intCast(-signed);
                if (err_num == @intFromEnum(os.E.INTR)) continue;
                std.log.err("write failed, errno={d}", .{err_num});
                return error.SyscallFailed;
            }
            n_written += @intCast(signed);
        }
        return n_written;
    }

    fn handleClient(self: *DaemonServer, client_fd: i32) !void {
        var msg: Message = std.mem.zeroes(Message);
        defer if (msg.message) |m| self.env.allocator.free(m);

        const msg_bytes = std.mem.asBytes(&msg);
        const nread = try read(client_fd, msg_bytes.ptr, msg_bytes.len);

        log.debug("Received message (sz={}): {{ .type = {any}, .state = {} }}", .{ nread, msg.msg_type, msg.state });

        if (msg.message != null) {
            var len: usize = 0;
            const len_bytes = std.mem.asBytes(&len);
            _ = try read(client_fd, len_bytes.ptr, len_bytes.len);
            const message = try self.env.allocator.alloc(u8, len);
            _ = try read(client_fd, message.ptr, len);
            msg.message = message;
        }

        const reply = self.processMessage(msg) catch |err| blk: {
            log.err("Failed to process message: {s}", .{@errorName(err)});
            break :blk MessageReply{ .status = 1, .message = "Failed to process message" };
        };

        const replyBytes = std.mem.asBytes(&reply);
        _ = try write(client_fd, replyBytes.ptr, replyBytes.len);

        if (reply.message != null) {
            const len_bytes = std.mem.asBytes(&reply.message.?.len);
            _ = try write(client_fd, len_bytes.ptr, len_bytes.len);
            _ = try write(client_fd, reply.message.?.ptr, reply.message.?.len);
        }
    }

    fn processMessage(self: *DaemonServer, msg: Message) !MessageReply {
        const ok = struct {
            fn ok(m: MessageReply) MessageReply {
                return .{ .status = 0, .message = m.message };
            }
        }.ok;
        const err = struct {
            fn err(m: MessageReply) MessageReply {
                return .{ .status = 1, .message = m.message };
            }
        }.err;

        if (msg.msg_type == .panic) {
            _ = os.kill(1, os.SIG.FPE);
            return err(.{ .message = "systemd be like" });
        }

        if (msg.msg_type == .reload) {
            // self.reload();
            return ok(.{ .message = "reloaded" });
        }

        std.debug.assert(msg.msg_type.hasTarget());

        const target = msg.message.?;
        const srv = self.services.findByName(target) orelse return err(.{ .message = "Service not found" });
        const status = srv.running;

        if (msg.msg_type == .status) {
            if (status) return .{ .status = @intCast(srv.pid), .message = "running" };
            return ok(.{ .message = "stopped" });
        }
        if (msg.msg_type == .start or msg.msg_type == .stop) {
            if (status and msg.msg_type == .stop) {
                log.debug("Stopping service {s}", .{srv.decl.name});
                if (!srv.decl.stoppable) {
                    return err(.{ .message = "Service is not stoppable" });
                }
                self.services.stop(srv);
                return ok(.{ .message = "Service stopped" });
            }
            if (!status and msg.msg_type == .start) {
                log.debug("Spawning service {s}", .{srv.decl.name});
                self.services.spawn(srv) catch |e| {
                    log.err("Failed to spawn service {s}: {s}", .{ srv.decl.name, @errorName(e) });
                    return err(.{ .message = "Failed to start service" });
                };
                return ok(.{ .message = "Service started" });
            }
            return err(.{ .message = "Service already in desired state" });
        }

        return err(.{ .message = "Invalid message type" });
    }

    pub fn deinit(self: *DaemonServer) void {
        self.services.deinit();
        _ = os.close(self.socket);
        current_server = null;
    }
};

pub fn create(env: Env, service_dir: []const u8) !DaemonServer {
    log.info("Creating daemon server", .{});

    std.Io.Dir.createDirPath(.cwd(), env.io, SOCKET_DIR) catch {};

    const lock_fd = lock.acquire(LOCKFILE_PATH) catch |err| {
        log.err("Couldn't acquire lockfile, is another daemon running?", .{});
        return err;
    };

    log.debug("Creating service table at {s}", .{service_dir});
    var serviceTable = ServiceTable.create(env, service_dir) catch |err| blk: {
        log.debug("Failed to create service table: {s}", .{@errorName(err)});
        break :blk ServiceTable{ .services = &.{}, .env = env };
    };
    errdefer serviceTable.deinit();
    log.debug("Service table: {f}", .{serviceTable});

    log.debug("Setting up signal hooks", .{});
    inline for (.{ os.SIG.INT, os.SIG.CHLD }) |sig| {
        _ = try syscall.signal(sig, signalHandler);
    }

    log.debug("Setting up socket", .{});
    const socket_fd = try errno.wrap(os.socket(os.AF.UNIX, os.SOCK.SEQPACKET, 0));
    const sock_fd: i32 = @intCast(socket_fd);
    errdefer _ = os.close(sock_fd);
    log.debug("Socket fd: {d}", .{sock_fd});

    var addr: os.sockaddr.un = std.mem.zeroes(os.sockaddr.un);
    addr.family = os.AF.UNIX;
    @memcpy(addr.path[0..SOCKET_PATH.len], SOCKET_PATH);
    std.Io.Dir.deleteFile(.cwd(), env.io, SOCKET_PATH) catch {};

    log.debug("Binding socket on {s}", .{SOCKET_PATH});
    const addr_len: u32 = @intCast(@offsetOf(os.sockaddr.un, "path") + SOCKET_PATH.len + 1);
    _ = try errno.wrap(os.bind(sock_fd, @ptrCast(&addr), addr_len));
    log.debug("Socket bound", .{});
    _ = try errno.wrap(os.listen(sock_fd, 1));
    log.debug("Socket listening", .{});

    return DaemonServer{
        .socket = sock_fd,
        .lock_fd = lock_fd,
        .services = serviceTable,
        .env = env,
    };
}
