const linux = @import("linux.zig");
const log = std.log.scoped(.fstab);

const MountFlags = linux.MountFlags;

const std = @import("std");

//---------------------------------------------------------------------
// Enum for filesystem mount flags.
pub const FsMountFlag = enum(u32) {
    auto = 1 << 0, // Automatic mounting at boot or via 'mount -a'
    noauto = 1 << 1, // Mount manually (not automatically at boot)
    nofail = 1 << 2, // Does not block boot if mount fails
    user = 1 << 3, // Allow any user to mount (implies noexec, nosuid, nodev)
    nouser = 1 << 4, // Only root can mount (default)
    label = 1 << 5, // Label-based mounting (e.g., LABEL=, UUID= in fstab)
    partuuid = 1 << 6, // Use PARTUUID for mounting
    partlabel = 1 << 7, // Use PARTLABEL for mounting
};

//---------------------------------------------------------------------
// Data for Mount Flags map.
const MountFlagsData = .{
    .{ "suid", 0 }, // Default
    .{ "exec", 0 }, // Default
    .{ "async", 0 }, // Default
    .{ "rw", 0 }, // Default
    .{ "ro", @intFromEnum(MountFlags.MS_RDONLY) },
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
};

pub const MountFlagsMap = std.StaticStringMap(u32).initComptime(MountFlagsData);

//---------------------------------------------------------------------
// Data for Filesystem Flags map.
const FsFlagsData = .{
    .{ "default", DefaultFsFlags },
    .{ "auto", @intFromEnum(FsMountFlag.auto) },
    .{ "noauto", @intFromEnum(FsMountFlag.noauto) },
    .{ "nofail", @intFromEnum(FsMountFlag.nofail) },
    .{ "user", @intFromEnum(FsMountFlag.user) },
    .{ "nouser", @intFromEnum(FsMountFlag.nouser) },
    .{ "label", @intFromEnum(FsMountFlag.label) },
    .{ "partuuid", @intFromEnum(FsMountFlag.partuuid) },
    .{ "partlabel", @intFromEnum(FsMountFlag.partlabel) },
};

pub const FsFlagsMap = std.StaticStringMap(u32).initComptime(FsFlagsData);

//---------------------------------------------------------------------
// Default flag values.
pub const DefaultMountFlags: u32 = 0;
pub const DefaultFsFlags: u32 = @intFromEnum(FsMountFlag.auto) | @intFromEnum(FsMountFlag.nouser);

//---------------------------------------------------------------------
// Structures representing filesystem options and fstab entries.
pub const FsOptions = struct {
    mountFlags: u32 = DefaultMountFlags,
    flags: u32 = DefaultFsFlags,
};

pub const FstabEntry = struct {
    device: []const u8,
    mount_options: []const u8,
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
            self.allocator.free(entry.mount_options);
            self.allocator.free(entry.fstype);
        }
        self.entries.deinit(self.allocator);
    }
};

//---------------------------------------------------------------------
// Debug printing for filesystem options using our compile-time arrays.
pub fn debugFsOptions(options: FsOptions) void {
    std.debug.print("==== Filesystem Options Debug ====\n", .{});
    std.debug.print("Mount Flags (raw): 0x{X}\n", .{options.mountFlags});
    std.debug.print("Filesystem Flags (raw): 0x{X}\n", .{options.flags});

    // Print mount flags set.
    std.debug.print("Mount Flags set: ", .{});
    var printed = false;
    inline for (MountFlagsData) |item| {
        if (item[1] != 0 and (options.mountFlags & item[1]) != 0) {
            std.debug.print("{s} ", .{item[0]});
            printed = true;
        }
    }
    if (!printed) {
        std.debug.print("none", .{});
    }
    std.debug.print("\n", .{});

    // Print filesystem flags set.
    std.debug.print("Filesystem Flags set: ", .{});
    printed = false;
    inline for (FsFlagsData) |item| {
        if (options.flags != 0 and ((options.flags & item[1]) != 0)) {
            std.debug.print("{s} ", .{item[0]});
        }
    }

    std.debug.print("\n==================================\n", .{});
}

//---------------------------------------------------------------------
// Debug printing for an fstab entry.
pub fn debugFstabEntry(entry: FstabEntry) void {
    std.debug.print("==== FstabEntry Debug ====\n", .{});
    std.debug.print("Device: {s}\n", .{entry.device});
    std.debug.print("Mount Point: {s}\n", .{entry.mount_options});
    std.debug.print("Filesystem Type: {s}\n", .{entry.fstype});
    std.debug.print("Dump: {d}\n", .{entry.dump});
    std.debug.print("Pass: {d}\n", .{entry.pass});
    debugFsOptions(entry.options);
    std.debug.print("==== End of FstabEntry Debug ====\n", .{});
}

//---------------------------------------------------------------------
// Debug printing for the entire fstab.
pub fn debugFstab(fstab: Fstab) void {
    if (fstab.entries.items.len == 0) {
        std.debug.print("Fstab is empty\n", .{});
        return;
    }
    for (fstab.entries.items) |entry| {
        debugFstabEntry(entry);
    }
}

//---------------------------------------------------------------------
// Example function to update mount options from a string.
fn updateMountOption(mo: *FsOptions, option: []const u8) void {
    std.debug.print("mount option [{s}]\n", .{option});
    if (MountFlagsMap.get(option)) |opt| {
        mo.mountFlags |= opt;
    } else if (FsFlagsMap.get(option)) |opt| {
        mo.flags |= opt;
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
    new.mount_options = try allocator.dupe(u8, it.next() orelse return error.fstabInvalidFormating);
    errdefer allocator.free(new.mount_options);
    new.fstype = try allocator.dupe(u8, it.next() orelse return error.fstabInvalidFormating);
    errdefer allocator.free(new.fstype);
    new.options = parseMountOptions(it.next() orelse return error.fstabInvalidFormating);
    new.dump = std.fmt.parseInt(u32, it.next() orelse return error.fstabInvalidFormating, 10) catch 0;
    new.pass = std.fmt.parseInt(u32, it.next() orelse return error.fstabInvalidFormating, 10) catch 0;

    return new;
}

//---------------------------------------------------------------------
// small fstab parser
// (maybe rm the file name and check if getenv("FSTAB_FILE") exist)
pub fn loadFstabEntries(init: *InitSystem, filename: []const u8) !Fstab {
    const fd = std.Io.Dir.openFileAbsolute(init.io, filename, .{}) catch |err| {
        log.debug("{s} open fail : {}", .{ filename, err });
        return error.EntriesFileOpenFail;
    };
    defer fd.close();

    var buffer = std.ArrayList(u8).initCapacity(init.allocator, 8196) catch unreachable;
    defer buffer.deinit(init.allocator);

    var fstab = Fstab {
        .entries = std.ArrayList(FstabEntry).initCapacity(init.allocator, 10) catch unreachable,
        .allocator = init.allocator,
    };
    errdefer fstab.deinit();

    const in_stream = fd.deprecatedReader();
    while (true) {
        buffer.clearRetainingCapacity();
        in_stream.streamUntilDelimiter(buffer.writer(init.allocator), '\n', null) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        if (buffer.items[0] == '#') {
            continue;
        }
        log.debug("line {s}", .{buffer.items});
        const entry = try initFstabEntry(init.allocator, buffer.items);
        try fstab.entries.append(init.allocator, entry);
    }
    debugFstab(fstab);
    return fstab;
}
