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

pub const mountFlagsMap = std.StaticStringMap(u32).initComptime(.{
    .{ "ro", @intFromEnum(MountFlags.MS_RDONLY) },
    .{ "rw", 0 }, // Default
    .{ "suid", 0 }, // Default
    .{ "exec", 0 }, // Default
    .{ "async", 0 }, // Default
    .{ "nosuid", @intFromEnum(MountFlags.MS_NOSUID) },
    .{ "nodev", @intFromEnum(MountFlags.MS_NODEV) },
    .{ "noexec", @intFromEnum(MountFlags.MS_NOEXEC) },
    .{ "sync", @intFromEnum(MountFlags.MS_SYNCHRONOUS) },
    .{ "remount", @intFromEnum(MountFlags.MS_REMOUNT) },
    .{ "mandlock", @intFromEnum(MountFlags.MS_MANDLOCK) },
    .{ "write", @intFromEnum(MountFlags.S_WRITE) },
    .{ "append", @intFromEnum(MountFlags.S_APPEND) },
    .{ "immutable", @intFromEnum(MountFlags.S_IMMUTABLE) },
    .{ "noatime", @intFromEnum(MountFlags.MS_NOATIME) },
    .{ "nodiratime", @intFromEnum(MountFlags.MS_NODIRATIME) },
    .{ "bind", @intFromEnum(MountFlags.MS_BIND) },
});

pub const DefaultFsFlags: u32 = @intFromEnum(FsMountFlag.auto) //
| @intFromEnum(FsMountFlag.nouser);

pub const FsFlagsMap = std.StaticStringMap(u32).initComptime(.{
    .{ "default", DefaultFsFlags },
    .{ "auto", @intFromEnum(FsMountFlag.auto) },
    .{ "noauto", @intFromEnum(FsMountFlag.noauto) },
    .{ "nofail", @intFromEnum(FsMountFlag.nofail) },
    .{ "user", @intFromEnum(FsMountFlag.user) },
    .{ "nouser", @intFromEnum(FsMountFlag.nouser) },
    .{ "label", @intFromEnum(FsMountFlag.label) },
    .{ "partuuid", @intFromEnum(FsMountFlag.partuuid) },
    .{ "partlabel", @intFromEnum(FsMountFlag.partlabel) },
});

// The "defaults" option corresponds to: rw, suid, dev, exec, auto, nouser, async.
pub const DefaultMountFlags: u32 = 0;

pub const FsOptions = struct {
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
    options: FsOptions,
    fstype: []const u8,
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

fn updateMountOption(mo: *FsOptions, option: []const u8) void {
    log.debug("mount option [{s}]", .{option});
    if (mountFlagsMap.get(option)) |opt| {
        mo.mountFlags |= opt;
    } else if (FsFlagsMap.get(option)) |opt| {
        mo.flags |= opt;
    } else {
        // do fsentry with args
        log.debug("not found", .{});
    }
}

fn parseMountOptions(options: []const u8) FsOptions {
    var mo = FsOptions{};

    var it = std.mem.tokenizeAny(u8, options, ",");
    while (it.next()) |opt| {
        updateMountOption(&mo, opt);
    }

    return mo;
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
