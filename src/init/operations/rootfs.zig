const std = @import("std");
const system = @import("xd").system;

const Cmdline = system.Cmdline;
const Env = system.Env;
const syscall = system.syscall;
const log = std.log.scoped(.rootfs);

pub const RootSpec = struct {
    device: []u8,
    fstype: []u8,

    pub fn deinit(self: *RootSpec, allocator: std.mem.Allocator) void {
        allocator.free(self.device);
        allocator.free(self.fstype);
    }
};

pub fn resolve(env: Env, cmdline: *const Cmdline) !RootSpec {
    const device_spec = cmdline.get("root") orelse return error.RootNotSpecified;
    const fstype = cmdline.get("rootfstype") orelse return error.RootFstypeNotSpecified;

    const device = try system.fstab.resolveDeviceSpec(env.allocator, device_spec);
    errdefer env.allocator.free(device);

    return .{
        .device = device,
        .fstype = try env.allocator.dupe(u8, fstype),
    };
}

pub fn checkAndMount(env: Env, root: *const RootSpec, target: []const u8) !void {
    const device_z = try env.allocator.dupeZ(u8, root.device);
    defer env.allocator.free(device_z);
    const fstype_z = try env.allocator.dupeZ(u8, root.fstype);
    defer env.allocator.free(fstype_z);
    const target_z = try env.allocator.dupeZ(u8, target);
    defer env.allocator.free(target_z);

    try std.Io.Dir.createDirPath(.cwd(), env.io, target);

    log.info("Mounting root {s} ({s}) on {s} read-only", .{ root.device, root.fstype, target });
    try syscall.mount(
        device_z,
        target_z,
        fstype_z,
        @intFromEnum(syscall.MountFlags.MS_RDONLY),
        0,
    );
    try system.fsck.run(env.allocator, root.device, root.fstype);
}

pub fn switchTo(target: [*:0]const u8) !void {
    log.info("Remounting root fs '{s}' read-write", .{target});
    try syscall.remount(target, @intFromEnum(syscall.MountFlags.MS_REMOUNT));
    try syscall.chdir(target);

    log.debug("Moving new root onto /", .{});
    try syscall.mount(".", "/", "none", @intFromEnum(syscall.MountFlags.MS_MOVE), 0);

    log.debug("Chrooting into new root", .{});
    try syscall.chroot(".");
    try syscall.chdir("/");
}
