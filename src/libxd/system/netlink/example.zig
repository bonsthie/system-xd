const netlink = @import("root.zig");

fn simpleExample() !void {
    var rtnl = try netlink.Route.init();
    defer rtnl.deinit();

    const link = try rtnl.getLink("eth0");

    try rtnl.setLink(link);

    try rtnl.addAddress(link, .{
        .address = .{ 192, 168, 1, 42 },
        .prefix = 24,
    });

    try rtnl.addRoute(.{
        .interface = link,
        .gateway = .{ 192, 168, 1, 1 },
    });
}
