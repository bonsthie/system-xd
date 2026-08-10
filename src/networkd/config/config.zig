const std = @import("std");
const Self = @This();

match: Match,
network: Network = .{},
route: ?[]Route = null,

pub fn validate(self: Self) !void {
    if (self.route) |routes| {
        for (routes) |route| try route.validate();
    }
}

pub fn format(self: Self, writer: *std.Io.Writer) !void {
    try writer.print("Config {{\n", .{});
    try writer.print("    .match = {{ .name = \"{s}\" }},\n", .{self.match.name});
    try writer.print("    .network = {{\n", .{});
    try writer.print("        .required = {},\n", .{self.network.required});
    try writer.print("        .addresses = ", .{});
    if (self.network.addresses) |addresses| {
        try writer.print("[", .{});
        for (addresses, 0..) |address, index| {
            if (index > 0) try writer.print(", ", .{});
            try writer.print("\"{s}\"", .{address});
        }
        try writer.print("]", .{});
    } else {
        try writer.print("null", .{});
    }
    try writer.print(",\n    }},\n", .{});
    try writer.print("    .route = ", .{});

    if (self.route) |routes| {
        try writer.print("[\n", .{});
        for (routes) |route| {
            try writer.print("        {{ .destination = ", .{});
            try formatOptionalString(writer, route.destination);
            try writer.print(", .gateway = ", .{});
            try formatOptionalString(writer, route.gateway);
            try writer.print(" }},\n", .{});
        }
        try writer.print("    ]", .{});
    } else {
        try writer.print("null", .{});
    }
    try writer.print(",\n}}", .{});
}

pub fn print(self: Self) void {
    std.debug.print("{f}\n", .{self});
}

fn formatOptionalString(writer: *std.Io.Writer, value: ?[]const u8) !void {
    if (value) |string| {
        try writer.print("\"{s}\"", .{string});
    } else {
        try writer.print("null", .{});
    }
}

pub const Match = struct {
    name: []const u8,
};

pub const Network = struct {
    required: bool = false,
    addresses: ?[]const []const u8 = null,
};

pub const Route = struct {
    destination: ?[]const u8 = null,
    gateway: ?[]const u8 = null,

    pub fn validate(self: Route) !void {
        if (self.destination == null and self.gateway == null) return error.EmptyRoute;
    }
};
