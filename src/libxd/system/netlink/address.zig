const std = @import("std");
const abi = @import("abi.zig");
const Link = @import("link.zig");
const nl_message = @import("message.zig");

pub const IPv4Address = [4]u8;

pub const Options = struct {
    address: IPv4Address,
    prefix: u8,
};

const IPv4Attribute = extern struct {
    header: abi.Attribute,
    value: IPv4Address,
};

pub fn add(
    fd: abi.FileDescriptor,
    sequence: u32,
    link: Link,
    options: Options,
) !void {
    if (options.prefix > 32) return error.InvalidAddressPrefix;
    if (link.index == 0 or link.index > std.math.maxInt(c_int)) {
        return error.InvalidLinkIndex;
    }

    const Request = nl_message.FixedBuilder(abi.AddressHeader, .{
        .type = IPv4Attribute,
        .count = 2,
    });
    var request = try Request.init(
        .RTM_NEWADDR,
        abi.REQUEST | abi.ACK | abi.CREATE | abi.EXCLUSIVE,
        sequence,
    ).withPayload(.{
        .family = abi.INET,
        .prefix_length = options.prefix,
        .flags = 0,
        .scope = abi.UNIVERSE_SCOPE,
        .index = link.index,
    }).withAttributes(.{
        .{
            .type = .{ .addr = .LOCAL },
            .value = &options.address,
        },
        .{
            .type = .{ .addr = .ADDRESS },
            .value = &options.address,
        },
    });
    try request.send(fd);

    return nl_message.receiveAck(fd, sequence);
}
