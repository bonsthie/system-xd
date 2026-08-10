const std = @import("std");
const os = std.os.linux;
const log = std.log.scoped(.daemon);

const xd = @import("xd");
const service = xd.service;
const errno = xd.system.errno;
const Env = xd.system.Env;
const ServiceTable = service.ServiceTable;
const syscall = xd.system.syscall;

const message = @import("message.zig");
const Message = message.Message;
const MessageReply = message.MessageReply;
const MessageType = message.MessageType;

var current_server: ?*DaemonServer = null;

pub const SOCKET_PATH = "./run/xd/daemon.sock";
pub const SOCKET_DIR = "./run/xd";

fn signalHandler(sig: os.SIG) callconv(.c) void {
    if (current_server) |server| { 
        if (sig == os.SIG.CHLD) server.reap = true;
        if (sig == os.SIG.INT) server.running = false;
    }
}

pub const DaemonServer = struct {
    socket: os.socket_t,
    services: service.ServiceTable,
    env: Env,
    running: bool = true,
    reap: bool = false,

    pub fn run(self: *DaemonServer) !void {
        current_server = self;

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

    fn handleClient(self: *DaemonServer, client_fd: i32) !void {
        var msg: Message = undefined;
        const msg_bytes = std.mem.asBytes(&msg);

        //TODO: i was tired okay
        // make sure the buffers sent don't contain string addresses but rather actual strings

        while (true) {
            const n_read = os.read(client_fd, msg_bytes.ptr, msg_bytes.len);
            const signed: isize = @bitCast(n_read);
            if (signed < 0) {
                const err_num: usize = @intCast(-signed);
                if (err_num == @intFromEnum(os.E.INTR)) continue;
                std.log.err("read failed, errno={d}", .{err_num});
                return error.SyscallFailed;
            }
            break;
        }

        std.log.info("received message: msg_type={d}", .{
            msg.msg_type,
        });

        var reply = std.mem.zeroes(MessageReply);
        reply.status = 0;
        reply.message = try self.env.allocator.dupe(u8, "Hello, world!");
        defer self.env.allocator.free(reply.message);

        const reply_bytes = std.mem.asBytes(&reply);
   
        while (true) {
            const n_written = os.write(client_fd, reply_bytes.ptr, reply_bytes.len);
            const signed: isize = @bitCast(n_written);
            if (signed < 0) {
                const err_num: usize = @intCast(-signed);
                if (err_num == @intFromEnum(os.E.INTR)) continue;
                std.log.err("write failed, errno={d}", .{err_num});
                return error.SyscallFailed;
            }
            break;
        }
    }

    pub fn deinit(self: *DaemonServer) void {
        self.services.deinit();
        _ = os.close(self.socket);
        current_server = null;
    }
};

pub fn create(env: Env, service_dir: []const u8) !DaemonServer {
    log.info("Creating daemon server", .{});

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
    std.Io.Dir.createDirPath(.cwd(), env.io, SOCKET_DIR) catch {};
    std.Io.Dir.deleteFile(.cwd(), env.io, SOCKET_PATH) catch {};

    log.debug("Binding socket on {s}", .{SOCKET_PATH});
    const addr_len: u32 = @intCast(@offsetOf(os.sockaddr.un, "path") + SOCKET_PATH.len + 1);
    _ = try errno.wrap(os.bind(sock_fd, @ptrCast(&addr), addr_len));
    log.debug("Socket bound", .{});
    _ = try errno.wrap(os.listen(sock_fd, 1));
    log.debug("Socket listening", .{});

    return DaemonServer{
        .socket = sock_fd,
        .services = serviceTable,
        .env = env,
    };
}
