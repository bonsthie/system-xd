const std = @import("std");

pub const Config = struct {
    match: Match,
    network: Network,
    route: []Route,

    pub fn format(self: Config, writer: *std.Io.Writer) !void {
        try writer.print("Config {{\n", .{});
        try writer.print("    .match = {{ .name = \"{s}\" }},\n", .{self.match.name});
        try writer.print("    .network = {{\n", .{});
        try writer.print("        .required = {},\n", .{self.network.required});
        try writer.print("        .addresses = [", .{});
        for (self.network.addresses, 0..) |address, index| {
            if (index > 0) try writer.print(", ", .{});
            try writer.print("\"{s}\"", .{address});
        }
        try writer.print("],\n    }},\n", .{});
        try writer.print("    .route = [\n", .{});
        for (self.route) |route| {
            try writer.print(
                "        {{ .destination = \"{s}\", .gateway = \"{s}\" }},\n",
                .{ route.destination, route.gateway },
            );
        }
        try writer.print("    ],\n}}", .{});
    }

    pub fn print(self: Config) void {
        std.debug.print("{f}\n", .{self});
    }
};

pub const Match = struct {
    name: []const u8,
};

pub const Network = struct {
    required: bool,
    addresses: []const []const u8,
};

pub const Route = struct {
    destination: []const u8,
    gateway: []const u8,
};

pub const ConfigLoader = @import("loader.zig");
