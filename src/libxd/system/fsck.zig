const std = @import("std");
const os = std.os.linux;
const syscall = @import("syscall.zig");
const log = std.log.scoped(.fsck);

const fsCheckMap = std.StaticStringMap([*:0]const u8).initComptime(.{
    .{ "ext2", "/e2fsck" },
    .{ "ext3", "/e2fsck" },
    .{ "ext4", "/e2fsck" },
    .{ "vfat", "/fsck.fat" },
    .{ "fat", "/fsck.fat" },
    .{ "fat16", "/fsck.fat" },
    .{ "fat32", "/fsck.fat" },
});

fn isExtFs(fstype: []const u8) bool {
    return std.mem.eql(u8, fstype, "ext2") or
        std.mem.eql(u8, fstype, "ext3") or
        std.mem.eql(u8, fstype, "ext4");
}

pub fn fsck(allocator: std.mem.Allocator, device: []const u8, fstype: []const u8) !void {
    const program = fsCheckMap.get(fstype) orelse {
        log.debug("No fsck program for {s}, skipping", .{fstype});
        return;
    };

    const device_z = try allocator.dupeZ(u8, device);
    defer allocator.free(device_z);

    log.info("Running {s} on {s}", .{ program, device });

    const pid = os.fork();
    if (pid < 0) return error.ForkFailed;
    if (pid == 0) {
        const argv: [*:null]const ?[*:0]const u8 = if (isExtFs(fstype))
            &[_:null]?[*:0]const u8{ program, "-f", "-y", device_z, null }
        else
            &[_:null]?[*:0]const u8{ program, "-a", device_z, null };
        const envp = &[_:null]?[*:0]const u8{null};
        syscall.execve(program, argv, envp) catch os.exit(1);
        os.exit(1);
    }

    var status: u32 = 0;
    _ = try syscall.waitpid(@intCast(pid), &status, 0);
    if (os.W.IFEXITED(status) and os.W.EXITSTATUS(status) != 0) {
        log.err("fsck on {s} exited with code {}", .{ device, os.W.EXITSTATUS(status) });
        return error.FsckFailed;
    }
}
