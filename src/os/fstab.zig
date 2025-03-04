const std = @import("std");
const log = std.log.scoped(.fstab);

pub const MountFlag = enum(u32) {
    // "auto": The filesystem will be mounted automatically at boot or via 'mount -a'
    auto = 1 << 0,
    // "noauto": The filesystem will only be mounted on demand
    noauto = 1 << 1,
    // "discard": Enables TRIM on SSDs (not recommended in some cases)
    discard = 1 << 2,
    // "nofail": Does not block boot if the partition is unavailable
    nofail = 1 << 3,
    // "rw": Mounts the filesystem in read-write mode
    rw = 1 << 4,
    // "ro": Mounts the filesystem in read-only mode
    ro = 1 << 5,
    // "relatime": Updates the atime relatively (when the file is modified)
    relatime = 1 << 6,
    // "noatime": Does not update the atime on inodes
    noatime = 1 << 7,
    // "user": Allows any user to mount (implies noexec, nosuid, nodev)
    user = 1 << 8,
    // "nouser": Only root can mount (default option)
    nouser = 1 << 9,
    // "sync": I/O operations are performed synchronously
    sync = 1 << 10,
    // "async": I/O operations are performed asynchronously
    @"async" = 1 << 11,
    // "suid": Allows suid and sgid bits (to temporarily elevate privileges)
    suid = 1 << 12,
    // "nosuid": Blocks suid and sgid bits
    nosuid = 1 << 13,
    // "exec": Allows execution of binaries on the partition
    exec = 1 << 14,
    // "noexec": Prevents execution of binaries
    noexec = 1 << 15,
    // "dev": Interprets special files (devices) on the partition
    dev = 1 << 16,
    // "acl": Enables ACL management
    acl = 1 << 17,
};

pub const DefaultMountFlags: u32 = @intFromEnum(MountFlag.rw) //
| @intFromEnum(MountFlag.suid) //
| @intFromEnum(MountFlag.dev) //
| @intFromEnum(MountFlag.exec) //
| @intFromEnum(MountFlag.auto) //
| @intFromEnum(MountFlag.nouser) //
| @intFromEnum(MountFlag.@"async");

pub const MountOptions = struct {
    flags: u32 = DefaultMountFlags,
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
    _ = it.next();
    new.mount_opts = MountOptions{}; // need to parse elem;
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
        log.debug("line {s}", .{buffer.items});
        const entry = try initFstabEntry(allocator, buffer.items);
        try fstab.entries.append(entry);
    }
    fstab.print();
    return fstab;
}
