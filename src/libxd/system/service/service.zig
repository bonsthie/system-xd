const std = @import("std");
const os = std.os.linux;

pub const RestartPolicy = enum {
    always,
    never,
};

pub const Service = struct {
    name: []const u8,
    path: []const u8,
    argv: []const []const u8 = &.{},
    envp: []const []const u8 = &.{},
    restart: RestartPolicy = .always,
    tty: ?[]const u8 = null, // if set, open+claim this tty before exec

    fn formatArray(writer: *std.Io.Writer, array: []const []const u8) !void {
        try writer.print("[", .{});
        var i: usize = 0;
        for (array) |arg| {
            if (i > 0) try writer.print(", ", .{});
            try writer.print("\"{s}\"", .{arg});
            i += 1;
        }
        try writer.print("]", .{});
    }

    pub fn format(self: Service, writer: *std.Io.Writer) !void {
        try writer.print("{s} = {{\n", .{self.name});
        try writer.print("    .path = {s},\n", .{self.path});
        try writer.print("    .argv = ", .{});
        try formatArray(writer, self.argv);
        try writer.print(",\n", .{});
        try writer.print("    .envp = ", .{});
        try formatArray(writer, self.envp);
        try writer.print(",\n", .{});
        try writer.print("    .restart = {s},\n", .{@tagName(self.restart)});
        if (self.tty) |tty| {
            try writer.print("    .tty = {s},\n", .{tty});
        }
        try writer.print("}}\n", .{});
    }
};
