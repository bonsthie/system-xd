const xd = @import("xd");
const std = @import("std");
const Env = xd.system.Env;

const config = @import("../config/root.zig");
const default = @import("../default.zig");

pub fn dump(env: Env, args: []const []const u8) !void {
    var loader = config.Loader.init(env);
    defer loader.deinit();

    if (args.len == 0) {
        try loader.loadPath(default.configPath());
    } else {
        for (args) |path| try loader.loadPath(path);
    }

    const configs = loader.items();
    for (configs) |parsed| parsed.value.print();
}
