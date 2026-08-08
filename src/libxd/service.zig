const std = @import("std");
const os = std.os.linux;

pub const RestartPolicy = enum {
    always,
    never,
};

pub const Service = struct {
    name: []const u8,
    path: [*:0]const u8,
    argv: [*:null]const ?[*:0]const u8,
    envp: [*:null]const ?[*:0]const u8,
    restart: RestartPolicy = .always,
    tty: ?[]const u8 = null, // if set, open+claim this tty before exec

    pid: os.pid_t = -1,
};
