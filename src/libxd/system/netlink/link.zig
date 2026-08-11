const std = @import("std");
const abi = @import("abi.zig");
const syscall = @import("../syscall.zig");

const Self = @This();

index: u32,

pub fn get(fd: abi.FileDescriptor, sequence: u32, name: []const u8) !Self {
    if (name.len == 0 or std.mem.indexOfScalar(u8, name, 0) != null) {
        return error.InvalidLinkName;
    }
    if (name.len >= abi.INTERFACE_NAME_SIZE) {
        return error.LinkNameTooLong;
    }

    const attribute_length = @sizeOf(abi.Attribute) + name.len + 1;
    const request_length = @sizeOf(abi.LinkMessage) + alignLength(attribute_length);

    var request = std.mem.zeroes(abi.LinkNameRequest);
    request.message = .{
        .header = .{
            .len = @intCast(request_length),
            .type = .RTM_GETLINK,
            .flags = abi.REQUEST,
            .seq = sequence,
            .pid = 0,
        },
        .payload = .{
            .family = abi.UNSPEC,
            .type = 0,
            .index = 0,
            .flags = 0,
            .change = 0,
        },
    };
    request.attribute = .{
        .len = @intCast(attribute_length),
        .type = .{ .link = .IFNAME },
    };
    std.mem.copyForwards(u8, request.value[0..name.len], name);

    var kernel_address: abi.NetlinkAddress = .{
        .pid = 0,
        .groups = 0,
    };
    const request_bytes = std.mem.asBytes(&request)[0..request_length];
    const sent = try syscall.sendto(
        fd,
        request_bytes,
        0,
        @ptrCast(&kernel_address),
        @intCast(@sizeOf(abi.NetlinkAddress)),
    );
    if (sent != request_bytes.len) return error.ShortWrite;

    return receive(fd, sequence);
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

        var offset: usize = 0;
        while (offset < response_length) {
            const message = try readMessage(response[0..response_length], &offset);
            if (message.header.seq != sequence) continue;

            switch (message.header.type) {
                .ERROR => try handleErrorMessage(
                    response[0..response_length],
                    message.offset,
                    message.length,
                ),
                .DONE => return error.LinkNotFound,
                .OVERRUN => return error.ResponseOverrun,
                .RTM_NEWLINK => return parseLinkMessage(
                    response[0..response_length],
                    message,
                ),
                else => {},
            }
        }
    }
}

const Message = struct {
    header: abi.MessageHeader,
    offset: usize,
    length: usize,
};

fn readMessage(response: []const u8, offset: *usize) !Message {
    const message_offset = offset.*;
    const remaining = response.len - message_offset;
    if (remaining < @sizeOf(abi.MessageHeader)) return error.MalformedMessage;

    const header = std.mem.bytesToValue(
        abi.MessageHeader,
        response[message_offset..][0..@sizeOf(abi.MessageHeader)],
    );
    const message_length: usize = header.len;
    if (message_length < @sizeOf(abi.MessageHeader) or message_length > remaining) {
        return error.MalformedMessage;
    }

    const aligned_length = alignLength(message_length);
    if (aligned_length <= remaining) {
        offset.* += aligned_length;
    } else if (message_length == remaining) {
        offset.* = response.len;
    } else {
        return error.MalformedMessage;
    }

    return .{
        .header = header,
        .offset = message_offset,
        .length = message_length,
    };
}

fn parseLinkMessage(response: []const u8, message: Message) !Self {
    if (message.length < @sizeOf(abi.MessageHeader) + @sizeOf(abi.LinkHeader)) {
        return error.MalformedMessage;
    }

    const link_offset = message.offset + @sizeOf(abi.MessageHeader);
    const link_header = std.mem.bytesToValue(
        abi.LinkHeader,
        response[link_offset..][0..@sizeOf(abi.LinkHeader)],
    );
    if (link_header.index <= 0) return error.InvalidLinkIndex;

    return .{ .index = @intCast(link_header.index) };
}

fn handleErrorMessage(response: []const u8, message_offset: usize, message_length: usize) !void {
    if (message_length < @sizeOf(abi.MessageHeader) + @sizeOf(abi.ErrorMessage)) {
        return error.MalformedMessage;
    }

    const error_offset = message_offset + @sizeOf(abi.MessageHeader);
    const error_message = std.mem.bytesToValue(
        abi.ErrorMessage,
        response[error_offset..][0..@sizeOf(abi.ErrorMessage)],
    );
    if (error_message.code == 0) return;

    _ = syscall.errno.wrap(error_message.code) catch |err| {
        if (err == error.NoDevice) return error.LinkNotFound;
        return err;
    };
}

fn alignLength(length: usize) usize {
    return std.mem.alignForward(usize, length, abi.ALIGNMENT);
}
