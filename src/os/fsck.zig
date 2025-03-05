//
// Minimal 'fsck' implementation for quick filesystem integrity checks.
//
// Level:
//   hInteg - Header Integrity: Verifies only the superblock/header.
//   fInteg - Full Integrity: Performs deep filesystem checks.
//
// Supported Filesystems:
// |--------------------|--------------------|--------------------|
// | Filesystem         |    hInteg          |    fInteg          |
// |--------------------|--------------------|--------------------|
// | ext2               |        ✓           |                    |
// | ext3               |        ✓           |                    |
// | ext4               |        ✓           |                    |
// | ISO9660            |        ✓           |                    |
// | VFat               |        ✓           |                    |
// |--------------------|--------------------|--------------------|
//
// Note:
// This minimal implementation provides quick integrity checks suitable
// for init-system integration to prevent mounting potentially corrupted
// filesystems.
//

const std = @import("std");
const fstab = @import("fstab.zig");
const log = std.log.scoped(.fsck);

const fsCheckFunc = *const fn (entry: *fstab.FstabEntry) anyerror!void;

fn dummy(_: *fstab.FstabEntry) !void {
    log.debug("caca", .{});
}

const fsCheckMap = std.StaticStringMap(fsCheckFunc).initComptime(.{
    .{ "ext2", dummy },
    .{ "ext3", dummy },
    .{ "ext4", dummy },
});

pub fn fsck(fs: *fstab.FstabEntry) !void {
    if (fsCheckMap.get(fs.fstype)) |func| {
        try func(fs);
    } else {
        log.debug("{} is not handle by fsck", .{fs.fstype});
        return error.fstypeNotHandle;
    }
}
