const errno = @import("errno.zig");
const linux = @import("std").os.linux;

pub const Flags = enum(u32) {
    MS_RDONLY = 1, // Mount read-only.
    MS_NOSUID = 2, // Ignore suid and sgid bits.
    MS_NODEV = 4, // Disallow access to device special files.
    MS_NOEXEC = 8, // Disallow program execution.
    MS_SYNCHRONOUS = 16, // Writes are synced at once.
    MS_REMOUNT = 32, // Alter flags of a mounted FS.
    MS_MANDLOCK = 64, // Allow mandatory locks on an FS.
    S_WRITE = 128, // Write on file/directory/symlink.
    S_APPEND = 256, // Append-only file.
    S_IMMUTABLE = 512, // Immutable file.
    MS_NOATIME = 1024, // Do not update access times.
    MS_NODIRATIME = 2048, // Do not update directory access times.
    MS_BIND = 4096, // Bind directory at different place.
    MS_MOVE = 8192,
    MS_REC = 16384,
    MS_SILENT = 32768,
    MS_POSIXACL = (1 << 16),
    MS_UNBINDABLE = (1 << 17),
    MS_PRIVATE = (1 << 18),
    MS_SLAVE = (1 << 19),
    MS_SHARED = (1 << 20),
    MS_RELATIME = (1 << 21),
    MS_KERNMOUNT = (1 << 22),
    MS_I_VERSION = (1 << 23),
    MS_STRICTATIME = (1 << 24),
    MS_LAZYTIME = (1 << 25),
    MS_NOREMOTELOCK = (1 << 27),
    MS_NOSEC = (1 << 28),
    MS_BORN = (1 << 29),
    MS_ACTIVE = (1 << 30),
    MS_NOUSER = (1 << 31),
};

pub fn mount(special: [*:0]const u8, dir: [*:0]const u8, fstype: ?[*:0]const u8, flags: u32, data: usize) !void {
    _ = try errno.wrap(linux.mount(special, dir, fstype, flags, data));
}
