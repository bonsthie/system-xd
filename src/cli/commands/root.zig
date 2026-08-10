const std = @import("std");
const os = std.os.linux;
const xd = @import("xd");
const errno = xd.system.errno;
const Env = xd.system.Env;
const message = @import("../daemon/root.zig").message;
const Message = message.Message;
const MessageReply = message.MessageReply;
const MessageType = message.MessageType;
const SOCKET_PATH = @import("../daemon/server.zig").SOCKET_PATH;

// Commands

pub const daemon = @import("daemon.zig").daemon;
pub const reload = @import("reload.zig").reload;

// Helpers

pub fn send(_: Env, msg: Message) !void {
    const sock_fd_raw = os.socket(os.AF.UNIX, os.SOCK.SEQPACKET, 0);
    const sock_fd: i32 = @intCast(try errno.wrap(sock_fd_raw));
    defer _ = os.close(sock_fd);

    var addr: os.sockaddr.un = std.mem.zeroes(os.sockaddr.un);
    addr.family = os.AF.UNIX;
    @memcpy(addr.path[0..SOCKET_PATH.len], SOCKET_PATH);

    const addr_len: u32 = @intCast(@offsetOf(os.sockaddr.un, "path") + SOCKET_PATH.len + 1);
    _ = try errno.wrap(os.connect(sock_fd, @ptrCast(&addr), addr_len));

    const msg_bytes = std.mem.asBytes(&msg);
    const n_written = os.write(sock_fd, msg_bytes.ptr, msg_bytes.len);
    _ = try errno.wrap(n_written);

    var reply: MessageReply = undefined;
    const reply_bytes = std.mem.asBytes(&reply);
    const n_read = os.read(sock_fd, reply_bytes.ptr, reply_bytes.len);
    _ = try errno.wrap(n_read);

    const msg_len = std.mem.indexOfScalar(u8, reply.message, 0) orelse reply.message.len;
    std.log.info("daemon replied: status={d} message={s}", .{
        reply.status,
        reply.message[0..msg_len],
    });
}
