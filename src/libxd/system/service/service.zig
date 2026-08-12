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
    clear_env: bool = false,
    envp: []const []const u8 = &.{},
    restart: RestartPolicy = .always,
    tty: ?[]const u8 = null, // if set, open+claim this tty before exec
    stoppable: bool = true,

    fn sliceEql(a: []const []const u8, b: []const []const u8) bool {
        if (a.len != b.len) return false;
        for (a, b) |x, y| {
            if (!std.mem.eql(u8, x, y)) return false;
        }
        return true;
    }

    pub fn eql(self: Service, other: Service) bool {
        if (!std.mem.eql(u8, self.name, other.name)) return false;
        if (!std.mem.eql(u8, self.path, other.path)) return false;
        if (!sliceEql(self.argv, other.argv)) return false;
        if (self.clear_env != other.clear_env) return false;
        if (!sliceEql(self.envp, other.envp)) return false;
        if (self.restart != other.restart) return false;
        if (self.stoppable != other.stoppable) return false;

        const tty_eql = blk: {
            if (self.tty == null and other.tty == null) break :blk true;
            if (self.tty == null or other.tty == null) break :blk false;
            break :blk std.mem.eql(u8, self.tty.?, other.tty.?);
        };
        if (!tty_eql) return false;

        return true;
    }

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
        try writer.print("    .stoppable = {s},\n", .{if (self.stoppable) "true" else "false"});
        try writer.print("}}\n", .{});
    }
};
