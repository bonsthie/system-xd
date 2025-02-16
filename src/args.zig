const std = @import("std");

pub fn parseKernelArgs(allocator: std.mem.Allocator) !std.AutoHashMap([]u8, []u8) {
    var map = std.AutoHashMap([]u8, []u8).init(allocator);

    const file = try std.fs.openFileAbsolute("/proc/cmdline", .{});
    defer file.close();

    const contents = try file.reader().readAllAlloc(allocator, 32 * 1024);
    defer allocator.free(contents);

    var it = std.mem.split(u8, contents, " \t\n");
    while (it.next()) |arg| {
        if (arg.len == 0) continue;
        const eq = std.mem.indexOfScalar(u8, arg, '=') orelse continue;
        const key = arg[0..eq];
        const allocated_key = try allocator.dupe(u8, key);
        const val = arg[eq + 1 ..];
        const allocated_val = try allocator.dupe(u8, val);
        map.put(allocated_key, allocated_val) catch |err| {
            deinit(map);
            return err;
        };
    }

    return map;
}

pub fn deinit(self: std.AutoHashMap([]u8, []u8)) void {
    var it = self.iterator();
    while (it.next()) |entry| {
        self.allocator.free(entry.key);
        self.allocator.free(entry.value);
    }
}
