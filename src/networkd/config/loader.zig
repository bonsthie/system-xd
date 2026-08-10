const std = @import("std");
const toml = @import("toml");

const xd = @import("xd");
const Config = @import("config.zig");
const Env = xd.system.Env;
const Dir = std.Io.Dir;
const Self = @This();

const max_config_size = 1024 * 1024;

pub const ParsedConfig = toml.Parsed(Config);

env: Env,
parsed_configs: std.ArrayList(ParsedConfig) = .empty,

pub fn init(env: Env) Self {
    return .{ .env = env };
}

pub fn deinit(self: *Self) void {
    for (self.parsed_configs.items) |parsed| parsed.deinit();
    self.parsed_configs.deinit(self.env.allocator);
    self.* = undefined;
}

pub fn items(self: *const Self) []const ParsedConfig {
    return self.parsed_configs.items;
}

pub fn loadPath(self: *Self, path: []const u8) !void {
    const stat = try Dir.statFile(.cwd(), self.env.io, path, .{});

    switch (stat.kind) {
        .directory => try self.loadFolder(path),
        .file => try self.loadFile(.cwd(), path),
        else => return error.UnsupportedFileType,
    }
}

fn loadFolder(self: *Self, path: []const u8) !void {
    const dir = try Dir.openDir(.cwd(), self.env.io, path, .{ .iterate = true });
    defer dir.close(self.env.io);

    var iterator = dir.iterate();
    while (try iterator.next(self.env.io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".toml")) continue;
        try self.loadFile(dir, entry.name);
    }
}

fn loadFile(self: *Self, dir: Dir, path: []const u8) !void {
    const parsed = try self.parseFile(dir, path);
    self.parsed_configs.append(self.env.allocator, parsed) catch |err| {
        parsed.deinit();
        return err;
    };
}

fn parseFile(self: *Self, dir: Dir, path: []const u8) !ParsedConfig {
    var parser = toml.Parser(Config).init(self.env.allocator);
    defer parser.deinit();

    const content = try dir.readFileAlloc(
        self.env.io,
        path,
        self.env.allocator,
        .limited(max_config_size),
    );
    defer self.env.allocator.free(content);

    const parsed = try parser.parseString(content);
    errdefer parsed.deinit();

    try parsed.value.validate();
    return parsed;
}
