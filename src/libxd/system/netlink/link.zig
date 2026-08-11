const std = @import("std");
const abi = @import("abi.zig");
const nl_message = @import("message.zig");
const syscall = @import("../syscall.zig");

const Self = @This();

index: u32,

const NameAttribute = extern struct {
    header: abi.Attribute,
    value: [abi.INTERFACE_NAME_SIZE]u8,
};

pub fn get(fd: abi.FileDescriptor, sequence: u32, name: []const u8) !Self {
    if (name.len == 0 or std.mem.indexOfScalar(u8, name, 0) != null) {
        return error.InvalidLinkName;
    }
    if (name.len >= abi.INTERFACE_NAME_SIZE) {
        return error.LinkNameTooLong;
    }

    const Request = nl_message.FixedBuilder(abi.LinkHeader, .{
        .type = NameAttribute,
    });
    var request = try Request.init(.RTM_GETLINK, abi.REQUEST, sequence)
        .withPayload(.{
            .family = abi.UNSPEC,
            .type = 0,
            .index = 0,
            .flags = 0,
            .change = 0,
        })
        .withAttributes(.{
        .{
            .type = .{ .link = .IFNAME },
            .value = name,
        },
    });
    try request.send(fd);

    return receive(fd, sequence);
}

pub fn set(self: Self, fd: abi.FileDescriptor, sequence: u32) !void {
    const index = std.math.cast(c_int, self.index) orelse {
        return error.InvalidLinkIndex;
    };
    if (index == 0) return error.InvalidLinkIndex;

    const link_up: u32 = @as(u16, @bitCast(std.os.linux.IFF{
        .UP = true,
    }));

    const Request = nl_message.FixedBuilder(abi.LinkHeader, .{
        .type = NameAttribute,
        .count = 0,
    });
    var request = try Request.init(
        .RTM_SETLINK,
        abi.REQUEST | abi.ACK,
        sequence,
    ).withPayload(.{
        .family = abi.UNSPEC,
        .type = 0,
        .index = index,
        .flags = link_up,
        .change = link_up,
    });

    try request.send(fd);

    return receiveAck(fd, sequence);
}

fn receiveAck(fd: abi.FileDescriptor, sequence: u32) !void {
    var response: [64 * 1024]u8 = undefined;

    while (true) {
        const response_length = try syscall.recvfrom(
            fd,
            &response,
            0,
            null,
            null,
        );
        if (response_length == 0) return error.MalformedMessage;

        var reader = nl_message.Reader.init(response[0..response_length]);
        while (try reader.next()) |message| {
            if (message.header.seq != sequence) continue;

            return switch (message.header.type) {
                .ERROR => message.checkError(),
                .OVERRUN => error.ResponseOverrun,
                else => error.UnexpectedMessage,
            };
        }
    }
}

fn receive(fd: abi.FileDescriptor, sequence: u32) !Self {
    var response: [64 * 1024]u8 = undefined;

    while (true) {
        const response_length = try syscall.recvfrom(
            fd,
            &response,
            0,
            null,
            null,
        );
        if (response_length == 0) return error.MalformedMessage;

        var reader = nl_message.Reader.init(response[0..response_length]);
        while (try reader.next()) |message| {
            if (message.header.seq != sequence) continue;

            switch (message.header.type) {
                .ERROR => {
                    message.checkError() catch |err| {
                        if (err == error.NoDevice) return error.LinkNotFound;
                        return err;
                    };
                    return error.UnexpectedAck;
                },
                .DONE => return error.LinkNotFound,
                .OVERRUN => return error.ResponseOverrun,
                .RTM_NEWLINK => return parseLinkMessage(message),
                else => {},
            }
        }
    }
}

fn parseLinkMessage(message: nl_message.View) !Self {
    const link_header = try message.payload(abi.LinkHeader);
    if (link_header.index <= 0) return error.InvalidLinkIndex;

    return .{ .index = @intCast(link_header.index) };
}
