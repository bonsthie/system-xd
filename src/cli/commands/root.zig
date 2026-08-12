const std = @import("std");
const os = std.os.linux;
const log = std.log.scoped(.socket);
const xd = @import("xd");
const errno = xd.system.errno;
const Env = xd.system.Env;
const messageModule = @import("../daemon/root.zig").message;
const Message = messageModule.Message;
const MessageReply = messageModule.MessageReply;
const MessageType = messageModule.MessageType;
const SOCKET_PATH = @import("../daemon/server.zig").SOCKET_PATH;

// Commands

pub const daemon = @import("daemon.zig").daemon;
pub const panic = @import("panic.zig").panic;
pub const reload = @import("reload.zig").reload;
pub const start = @import("start.zig").start;
pub const stop = @import("stop.zig").stop;
pub const restart = @import("restart.zig").restart;
pub const status = @import("status.zig").status;
pub const enable = @import("enable.zig").enable;
pub const disable = @import("disable.zig").disable;

// Helpers

pub fn send(env: Env, msg: Message) !void {
    const sock_fd_raw = os.socket(os.AF.UNIX, os.SOCK.SEQPACKET, 0);
    const sock_fd: i32 = @intCast(try errno.wrap(sock_fd_raw));
    defer _ = os.close(sock_fd);

    var addr: os.sockaddr.un = std.mem.zeroes(os.sockaddr.un);
    addr.family = os.AF.UNIX;
    @memcpy(addr.path[0..SOCKET_PATH.len], SOCKET_PATH);

    const addr_len: u32 = @intCast(@offsetOf(os.sockaddr.un, "path") + SOCKET_PATH.len + 1);
    _ = try errno.wrap(os.connect(sock_fd, @ptrCast(&addr), addr_len));

    {
        const msg_bytes = std.mem.asBytes(&msg);
        var nwritten = try errno.wrap(os.write(sock_fd, msg_bytes.ptr, msg_bytes.len));
        log.debug("Sent message (sz={}): {{ .type = {any}, .state = {} }}", .{ nwritten, msg.msg_type, msg.state });

        if (msg.message != null) {
            const len_bytes = std.mem.asBytes(&msg.message.?.len);
            nwritten = try errno.wrap(os.write(sock_fd, len_bytes.ptr, len_bytes.len));
            log.debug("Sent string len (sz={})", .{nwritten});
            nwritten = try errno.wrap(os.write(sock_fd, msg.message.?.ptr, msg.message.?.len));
            log.debug("Sent string (sz={}) '{s}'", .{ nwritten, msg.message.? });
        }
    }

    {
        var reply = std.mem.zeroes(MessageReply);
        defer if (reply.message) |m| env.allocator.free(m);

        const reply_bytes = std.mem.asBytes(&reply);
        _ = try errno.wrap(os.read(sock_fd, reply_bytes.ptr, reply_bytes.len));

        if (reply.message != null) {
            var len: usize = 0;
            const len_bytes = std.mem.asBytes(&len);
            _ = try errno.wrap(os.read(sock_fd, len_bytes.ptr, len_bytes.len));
            const message = try env.allocator.alloc(u8, len);
            _ = try errno.wrap(os.read(sock_fd, message.ptr, len));
            reply.message = message;
        }

        std.log.info("daemon replied: status={d} message={s}", .{
            reply.status,
            reply.message orelse "null",
        });
    }
}
