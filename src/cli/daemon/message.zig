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
