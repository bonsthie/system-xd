const std = @import("std");
const linux = @import("linux.zig");
const log = std.log.scoped(.fstab);

const MountFlags = linux.MountFlags;

pub const FsMountFlag = enum(u32) {
    // Automatic mounting at boot or via 'mount -a'
    auto = 1 << 0,
    // Mount manually (not automatically at boot)
    noauto = 1 << 1,
    // Does not block boot if mount fails
    nofail = 1 << 2,
    // Allow any user to mount (implies noexec, nosuid, nodev)
    user = 1 << 3,
    // Only root can mount (default)
    nouser = 1 << 4,
    // Label-based mounting (e.g., LABEL=, UUID= in fstab)
    label = 1 << 5,
    // Use PARTUUID for mounting
    partuuid = 1 << 6,
    // Use PARTLABEL for mounting
    partlabel = 1 << 7,
};

pub const mountFlagsMap = std.ComptimeStringMap(MountFlags, .{
    .{ "ro", MountFlags.MS_RDONLY },
    .{ "rw", 0 }, // Default
    .{ "suid", 0 }, // Default
    .{ "exec", 0 }, // Default
    .{ "async", 0 }, // Default
    .{ "nosuid", MountFlags.MS_NOSUID },
    .{ "nodev", MountFlags.MS_NODEV },
    .{ "noexec", MountFlags.MS_NOEXEC },
    .{ "sync", MountFlags.MS_SYNCHRONOUS },
    .{ "remount", MountFlags.MS_REMOUNT },
    .{ "mandlock", MountFlags.MS_MANDLOCK },
    .{ "write", MountFlags.S_WRITE },
    .{ "append", MountFlags.S_APPEND },
    .{ "immutable", MountFlags.S_IMMUTABLE },
    .{ "noatime", MountFlags.MS_NOATIME },
    .{ "nodiratime", MountFlags.MS_NODIRATIME },
    .{ "bind", MountFlags.MS_BIND },
});

pub const DefaultFsFlags: u32 = @intFromEnum(FsMountFlag.auto) //
| @intFromEnum(FsMountFlag.nouser);

pub const FsFlagsMap = std.ComptimeStringMap(MountFlags, .{
    .{ "default", DefaultFsFlags },
    .{ "auto", FsMountFlag.auto },
    .{ "noauto", FsMountFlag.noauto },
    .{ "nofail", FsMountFlag.nofail },
    .{ "user", FsMountFlag.user },
    .{ "nouser", FsMountFlag.nouser },
    .{ "label", FsMountFlag.label },
    .{ "partuuid", FsMountFlag.partuuid },
    .{ "partlabel", FsMountFlag.partlabel },
});

// The "defaults" option corresponds to: rw, suid, dev, exec, auto, nouser, async.
pub const DefaultMountFlags: u32 = 0;

pub const MountOptions = struct {
    mountFlags: u32 = DefaultMountFlags,
    flags: u32 = DefaultFsFlags,
    vers: f32 = 4.0,
    sec: []const u8 = "krb5",
    rsize: u32 = 65536,
    wsize: u32 = 65536,
};

pub const FstabEntry = struct {
    device: []const u8,
    mount_point: []const u8,
    fstype: []const u8,
    mount_opts: MountOptions,
    dump: u32,
    pass: u32,
};

pub const Fstab = struct {
    entries: std.ArrayList(FstabEntry),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Fstab) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry.device);
            self.allocator.free(entry.mount_point);
            self.allocator.free(entry.fstype);
        }
        self.entries.deinit();
    }

    pub fn print(self: *Fstab) void {
        for (self.entries.items) |entry| {
            log.debug("device {s}", .{entry.device});
            log.debug("mountpoint {s}", .{entry.mount_point});
        }
    }
};

fn parseMountOptions(_: []const u8) MountOptions {
    return MountOptions{};
}

// fstab entry line pattern :
// <file system> <mount point>   <type>  <options>       <dump>  <pass>
fn initFstabEntry(allocator: std.mem.Allocator, line: []const u8) !FstabEntry {
    var it = std.mem.tokenizeAny(u8, line, " \t\n\r");

    var new: FstabEntry = undefined;

    new.device = try allocator.dupe(u8, it.next() orelse return error.fstabInvalidFormating);
    errdefer allocator.free(new.device);
    new.mount_point = try allocator.dupe(u8, it.next() orelse return error.fstabInvalidFormating);
    errdefer allocator.free(new.mount_point);
    new.fstype = try allocator.dupe(u8, it.next() orelse return error.fstabInvalidFormating);
    errdefer allocator.free(new.fstype);
    new.mount_opts = parseMountOptions(it.next() orelse return error.fstabInvalidFormating);
    new.dump = std.fmt.parseInt(u32, it.next() orelse return error.fstabInvalidFormating, 10) catch 0;
    new.pass = std.fmt.parseInt(u32, it.next() orelse return error.fstabInvalidFormating, 10) catch 0;

    return new;
}

pub fn loadFstabEntries(allocator: std.mem.Allocator, filename: []const u8) !Fstab {
    const fd = std.fs.cwd().openFile(filename, .{}) catch |err| {
        log.debug("{s} open fail : {}", .{ filename, err });
        return error.EntriesFileOpenFail;
    };
    defer fd.close();

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var fstab = Fstab{
        .entries = std.ArrayList(FstabEntry).init(allocator),
        .allocator = allocator,
    };
    errdefer fstab.deinit();

    const in_stream = fd.reader();
    while (true) {
        buffer.clearRetainingCapacity();
        in_stream.streamUntilDelimiter(buffer.writer(), '\n', null) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        if (buffer.items[0] == '#') {
            continue;
        }
        log.debug("line {s}", .{buffer.items});
        const entry = try initFstabEntry(allocator, buffer.items);
        try fstab.entries.append(entry);
    }
    fstab.print();
    return fstab;
}
