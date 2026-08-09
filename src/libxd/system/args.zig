const std = @import("std");
const log = std.log.scoped(.args);

pub fn parseKernelArgs(io: std.Io, allocator: std.mem.Allocator) !std.StringHashMap(?[]u8) {
    var map = std.StringHashMap(?[]u8).init(allocator);

    const file = try std.Io.Dir.openFileAbsolute(io, "/proc/cmdline", .{});
    defer file.close(io);

    var read_buffer: [4096]u8 = undefined;
    var file_reader = file.reader(io, &read_buffer);

    const contents = try file_reader.interface.allocRemaining(
        allocator,
        .limited(32 * 1024),
    );
    defer allocator.free(contents);

    var it = std.mem.tokenizeAny(u8, contents, " \t\n\r");
    while (it.next()) |arg| {
        if (arg.len == 0) continue;
        // log.debug("Found thing at {s}", .{arg});
        const eq = std.mem.indexOfScalar(u8, arg, '=') orelse {
            // log.debug("Found no = at {s}", .{arg});
            const allocated_arg = try allocator.dupe(u8, arg);
            // log.debug("Arg: {*}", .{&allocated_arg});
            map.put(allocated_arg, null) catch |err| {
                deinitWrapOptional(map);
                return err;
            };
            continue;
        };
        // log.debug("Found = at {d}", .{eq});
        const key = arg[0..eq];
        const allocated_key = try allocator.dupe(u8, key);
        // log.debug("Key: {*}", .{&allocated_key});
        const val = arg[eq + 1 ..];
        const allocated_val = try allocator.dupe(u8, val);
        // log.debug("Val: {*}", .{&allocated_val});
        // log.debug("Parsed kernel arg: {s}={s}", .{ allocated_key, allocated_val });
        map.put(allocated_key, allocated_val) catch |err| {
            deinitWrapOptional(map);
            return err;
        };
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
        self.*.?.deinit();
        self.* = null;
    }
}
