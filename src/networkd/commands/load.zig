const xd = @import("xd");
const std = @import("std");
const Env = xd.system.Env;
const netlink = xd.system.netlink;
const networkd = @import("networkd");

pub fn load(env: Env, args: []const []const u8) !void {
    var loader = networkd.Loader.init(env);
    defer loader.deinit();

    if (args.len == 0) {
        try loader.loadPath(networkd.configPath());
    } else {
        for (args) |path| try loader.loadPath(path);
    }

    var rtnl = try netlink.Route.init();
    defer rtnl.deinit();

    const configs = loader.items();
    for (configs) |parsed| {
        const loaded_config = parsed.value;
        const link = rtnl.getLink(loaded_config.match.name) catch |err| {
            if (err == error.LinkNotFound and !loaded_config.network.required) {
                continue;
            }
            return err;
        };

        try rtnl.setLink(link);

        if (loaded_config.network.addresses) |addresses| {
            for (addresses) |text| {
                try rtnl.addAddress(
                    link,
                    try netlink.AddressOptions.parse(text),
                );
            }
        }

        if (loaded_config.route) |routes| {
            for (routes) |route| {
                try rtnl.addRoute(try netlink.RouteOptions.parse(
                    link,
                    route.destination,
                    route.gateway,
                ));
            }
        }
    }
}
