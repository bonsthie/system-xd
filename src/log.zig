const std = @import("std");
const log = std.log;

pub fn customLogFn(
    comptime level: log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const prefix = std.fmt.comptimePrint("[{s}/{s}]: ", .{ @tagName(scope), @tagName(level) });
    const writer = std.io.getStdErr().writer();
    writer.print(prefix, .{}) catch unreachable;
    writer.print(format, args) catch unreachable;
    writer.print("\n", .{}) catch unreachable;
}
