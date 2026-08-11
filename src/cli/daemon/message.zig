const std = @import("std");

pub const MessageType = enum {
    reload,
    status,
    start,
    stop,
    panic,

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
    status: u32 = 0,
    message: ?[]const u8 = null,
};
