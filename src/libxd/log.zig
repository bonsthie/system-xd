const std = @import("std");
const log = std.log;
const consts = @import("consts.zig");

var log_io: std.Io.Threaded = std.Io.Threaded.init_single_threaded;

var log_target: std.Io.File = std.Io.File.stderr();

pub fn setLogTarget(file: std.Io.File) void {
    std.log.info("Setting log target to {}", .{file.handle});
    log_target = file;
}

pub fn customLogFn(
    comptime level: log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const io = log_io.io();
    const prefix = std.fmt.comptimePrint("[{s}/{s}]: ", .{ @tagName(scope), @tagName(level) });
    var buffer: [256]u8 = undefined;
    var writer = log_target.writerStreaming(io, &buffer);
    writer.interface.print(prefix, .{}) catch unreachable;
    writer.interface.print(format, args) catch unreachable;
    writer.interface.print("\n", .{}) catch unreachable;
    writer.interface.flush() catch unreachable;
}
