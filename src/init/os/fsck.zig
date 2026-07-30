const std = @import("std");
const fstab = @import("fstab.zig");
const log = std.log.scoped(.fsck);

// { .name = "e2fsck", .file_bytes = @embedFile("./tools/e2fsck") }
const FsCheckProgram = struct {
    name: []const u8,
    file_bytes: []const u8,
};

const e2fsck = FsCheckProgram{ .name = "e2fsck", .file_bytes = @embedFile("./tools/e2fsck") };
const fsckFat = FsCheckProgram{ .name = "fsck.fat", .file_bytes = @embedFile("./tools/fsck.fat") };

const fsCheckMap = std.StaticStringMap(*FsCheckProgram).initComptime(.{
    .{ "ext2", &e2fsck },
    .{ "ext3", &e2fsck },
    .{ "ext4", &e2fsck },
    .{ "fat32", &fsckFat },
    .{ "fat16", &fsckFat },
    .{ "vfat", &fsckFat },
    .{ "fat", &fsckFat },
});

fn ensureProgramExists(io: std.Io, program: *FsCheckProgram) !void {
    if (program.file_bytes.len == 0) {
        log.err("No program found for {s}", .{program.name});
        return error.NoProgram;
    }

    // Try and drop the program in /tmp/<name>
    const tmp = try std.Io.Dir.openFileAbsolute(io, "/tmp", .{ .mode = .write_only });
    defer tmp.close(io);
}

fn fsckWithProgram(io: std.Io, fs: *fstab.FstabEntry, program: *FsCheckProgram) !void {
    try ensureProgramExists(io, program);

    const programPath = try std.fs.path.join(io, &.{ "/tmp", program.name });
    const argv = &[_:null]?[*:0]const u8{
        programPath,
        fs.device,
        fs.mountpoint,
    };
    const process = try std.process.spawn(&.{ .argv = argv, .stdin = .ignore, .stdout = .ignore, .stderr = .ignore});
    const term = try process.wait();
    const exitcode = term.exited;
    if (exitcode != 0) {
        log.err("Failed to run fsck on {s}: {s}", .{ fs.mountpoint, exitcode });
    }
}

pub fn fsck(io: std.Io, fs: *fstab.FstabEntry) void {
    if (fsCheckMap.get(fs.fstype)) |checkProgram| {
        log.debug("Running fsck on {s}", .{fs.mountpoint});
        try fsckWithProgram(io, fs, checkProgram) catch |err| {
            log.err("Failed to run fsck on {s}: {s}", .{ fs.mountpoint, err });
        };
    } else {
        log.debug("{} is not handled by fsck, skipping...", .{fs.fstype});
    }
}
