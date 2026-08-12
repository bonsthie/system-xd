const std = @import("std");
const abi = @import("abi.zig");
const address = @import("address.zig");
const nl_message = @import("message.zig");
const syscall = @import("../syscall.zig");

const Self = @This();

fd: abi.FileDescriptor,
sequence: u32,

pub const Link = @import("link.zig");

pub const IPv4Address = address.IPv4Address;
pub const AddressOptions = address.Options;

pub const RouteOptions = struct {
    interface: Link,
    gateway: IPv4Address,
};

const IPv4RouteAttribute = extern struct {
    header: abi.Attribute,
    value: [4]u8,
};

pub fn init() !Self {
    const fd = try syscall.socket(
        abi.NETLINK,
        abi.RAW | abi.CLOEXEC,
        abi.ROUTE,
    );
    errdefer syscall.close(fd);

    var nl_address: abi.NetlinkAddress = .{
        .pid = 0,
        .groups = 0,
    };
    try syscall.bind(
        fd,
        @ptrCast(&nl_address),
        @intCast(@sizeOf(abi.NetlinkAddress)),
    );

    return .{
        .fd = fd,
        .sequence = 0,
    };
}

pub fn deinit(self: *Self) void {
    syscall.close(self.fd);
    self.* = undefined;
}

pub fn getLink(self: *Self, name: []const u8) !Link {
    const sequence = self.nextSequence();
    return Link.get(self.fd, sequence, name);
}

// For a u32, incrementing 4_294_967_295 wraps to 0 instead of causing an overflow panic. The next line skips zero:
fn nextSequence(self: *Self) u32 {
    self.sequence +%= 1;
    if (self.sequence == 0) self.sequence = 1;
    return self.sequence;
}

pub fn setLink(self: *Self, link: Link) !void {
    const sequence = self.nextSequence();
    return link.set(self.fd, sequence);
}

pub fn addAddress(self: *Self, link: Link, options: AddressOptions) !void {
    const sequence = self.nextSequence();
    return address.add(self.fd, sequence, link, options);
}

pub fn addRoute(self: *Self, options: RouteOptions) !void {
    const sequence = self.nextSequence();
    if (options.interface.index == 0 or
        options.interface.index > std.math.maxInt(c_int))
    {
        return error.InvalidLinkIndex;
    }

    const interface_index = options.interface.index;
    const Request = nl_message.FixedBuilder(abi.RouteHeader, .{
        .type = IPv4RouteAttribute,
        .count = 2,
    });
    var request = try Request.init(
        .RTM_NEWROUTE,
        abi.REQUEST | abi.ACK | abi.CREATE | abi.EXCLUSIVE,
        sequence,
    ).withPayload(.{
        .family = abi.INET,
        .destination_length = 0,
        .source_length = 0,
        .tos = 0,
        .table = abi.MAIN_TABLE,
        .protocol = abi.BOOT_PROTOCOL,
        .scope = abi.UNIVERSE_SCOPE,
        .type = abi.UNICAST_ROUTE,
        .flags = 0,
    }).withAttributes(.{
        .{
            .type = .{ .route = .GATEWAY },
            .value = &options.gateway,
        },
        .{
            .type = .{ .route = .OIF },
            .value = std.mem.asBytes(&interface_index),
        },
    });
    try request.send(self.fd);

    return nl_message.receiveAck(self.fd, sequence);
}
