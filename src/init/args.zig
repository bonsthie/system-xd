const std = @import("std");
const log = std.log.scoped(.args);

pub fn parseKernelArgs(allocator: std.mem.Allocator) !std.StringHashMap(?[]u8) {
    var map = std.StringHashMap(?[]u8).init(allocator);
    errdefer {
        var it = map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            if (entry.value_ptr.*) |v| allocator.free(v);
        }
        map.deinit();
    }

    const file = try std.fs.openFileAbsolute("/proc/cmdline", .{});
    defer file.close();

    const contents = try file.deprecatedReader().readAllAlloc(allocator, 32 * 1024);
    defer allocator.free(contents);

    var it = std.mem.tokenizeAny(u8, contents, " \t\n\r");
    while (it.next()) |arg| {
        if (arg.len == 0) continue;

        const raw_key, const raw_val = if (std.mem.indexOfScalar(u8, arg, '=')) |eq|
            .{ arg[0..eq], @as(?[]const u8, arg[eq + 1 ..]) }
        else
            .{ arg, @as(?[]const u8, null) };

        const allocated_key = try allocator.dupe(u8, raw_key);
        const gop = try map.getOrPut(allocated_key);

        if (gop.found_existing) {
            allocator.free(allocated_key);
            if (gop.value_ptr.*) |old_val| allocator.free(old_val);
        }

        gop.value_ptr.* = if (raw_val) |v| try allocator.dupe(u8, v) else null;
    }

    return map;
}

inline fn deinitWrapOptional(map: std.StringHashMap(?[]u8)) void {
    var possible_map: ?std.StringHashMap(?[]u8) = map;
    deinitKernelArgs(&possible_map);
}

pub fn deinitKernelArgs(self: *?std.StringHashMap(?[]u8)) void {
    if (self.*) |map| {
        var it = map.iterator();
        while (it.next()) |entry| {
            map.allocator.free(entry.key_ptr.*);
            if (entry.value_ptr.*) |val| {
                map.allocator.free(val);
            }
        }
    }
    self.*.?.deinit();
}
