const std = @import("std");

pub const MessageType = enum {
    reload,
    status,
    start,
    stop,

    pub fn hasTarget(self: MessageType) bool {
        return switch (self) {
            .status, .start, .stop => true,
            else => false,
        };
    }
};

pub const Message = struct {
    msg_type: MessageType,
    state: bool = false,
    message: ?[]const u8 = null,
};

pub const MessageReply = struct {
    status: u8 = 0,
    message: ?[]const u8 = null,
};
