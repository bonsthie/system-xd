const std = @import("std");

pub const MessageType = enum {
    reload,
    status,
    start,
    stop,
};

pub const Message = struct {
    msg_type: MessageType,
    target: ?[]const u8 = null,
    state: bool = false,
};

pub const MessageReply = struct {
    status: u8 = 0,
    message: []u8 = "",
};
