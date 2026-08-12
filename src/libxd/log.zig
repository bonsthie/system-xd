const std = @import("std");
const log = std.log;

var log_io = std.Io.Threaded.init_single_threaded;

var log_err = std.Io.File.stderr();
var log_out = std.Io.File.stdout();

pub fn customLogFn(
    comptime level: log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const io = log_io.io();
    const prefix = std.fmt.comptimePrint("[{s}/{s}]: ", .{ @tagName(scope), @tagName(level) });
    var buffer: [256]u8 = undefined;
    var writer = (if (level == .warn or level == .err) log_err else log_out).writerStreaming(io, &buffer);
    writer.interface.print(prefix, .{}) catch {};
    writer.interface.print(format, args) catch {};
    writer.interface.print("\n", .{}) catch {};
    writer.interface.flush() catch {};
}
