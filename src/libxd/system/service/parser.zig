const toml = @import("toml");

const Service = @import("service.zig").Service;
const Env = @import("../env.zig").Env;

pub fn fromToml(env: Env, filePath: []const u8) !Service {
    var parser = toml.Parser(Service).init(env.allocator);
    defer parser.deinit();

    return (try parser.parseFile(env.io, filePath)).value;
}
