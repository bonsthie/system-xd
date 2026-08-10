const std = @import("std");

pub fn toPosixString(allocator: std.mem.Allocator, string: []const u8) ![:0]u8 {
    return allocator.dupeZ(u8, string);
}

pub fn freePosixString(allocator: std.mem.Allocator, string: ?[:0]u8) void {
    if (string) |value| {
        allocator.free(value);
    }
}

pub fn toPosixSlice(allocator: std.mem.Allocator, strings: []const []const u8) ![:null]?[*:0]u8 {
    var ptrs = try allocator.allocSentinel(?[*:0]u8, strings.len, null);
    var initialized: usize = 0;
    errdefer {
        for (ptrs[0..initialized]) |string| {
            freePosixString(allocator, std.mem.span(string.?));
        }
        allocator.free(ptrs);
    }

    for (strings, 0..) |string, i| {
        ptrs[i] = (try toPosixString(allocator, string)).ptr;
        initialized += 1;
    }

    return ptrs;
}

pub fn freePosixSlice(allocator: std.mem.Allocator, strings: [:null]?[*:0]u8) void {
    for (strings) |string| {
        freePosixString(allocator, std.mem.span(string.?));
    }
    allocator.free(strings);
}

pub fn toPosixEnviron(allocator: std.mem.Allocator, environ: *const std.process.Environ.Map) !std.process.Environ.PosixBlock {
    return environ.createPosixBlock(allocator, .{});
}

pub fn freePosixEnviron(allocator: std.mem.Allocator, environ: std.process.Environ.PosixBlock) void {
    environ.deinit(allocator);
}
