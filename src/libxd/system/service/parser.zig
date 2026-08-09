const toml = @import("toml");

const Service = @import("service.zig").Service;
const Env = @import("../env.zig").Env;

pub fn fromToml(env :Env, filePath: []const u8) !Service {
    var parser = toml.Parser(Service).init(env.allocator);
    defer parser.deinit();

    var result = try parser.parseFile(env.io, filePath);
    defer result.deinit();

    return result.value;
}
