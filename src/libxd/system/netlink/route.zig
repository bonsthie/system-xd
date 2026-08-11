const abi = @import("abi.zig");
const syscall = @import("../syscall.zig");

const Self = @This();

fd: abi.FileDescriptor,
sequence: u32,

pub const Link = @import("link.zig");

pub const IPv4Address = [4]u8;

pub const AddressOptions = struct {
    address: IPv4Address,
    prefix: u8,
};

pub const RouteOptions = struct {
    interface: Link,
    gateway: IPv4Address,
};

pub fn init() !Self {
    const fd = try syscall.socket(
        abi.NETLINK,
        abi.RAW | abi.CLOEXEC,
        abi.ROUTE,
    );
    errdefer syscall.close(fd);

    var address: abi.NetlinkAddress = .{
        .pid = 0,
        .groups = 0,
    };
    try syscall.bind(
        fd,
        @ptrCast(&address),
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
    _ = self;
    _ = link;
    _ = options;
    return error.NotImplemented;
}

pub fn addRoute(self: *Self, options: RouteOptions) !void {
    _ = self;
    _ = options;
    return error.NotImplemented;
}
