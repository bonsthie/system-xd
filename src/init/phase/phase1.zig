const system = @import("xd").system;
const Env = system.Env;
const Cmdline = system.Cmdline;
const RootSpec = @import("root.zig").RootSpec;

pub const Ctx = struct {
    env: Env,
    cmdline: ?Cmdline = null,
    root: ?RootSpec = null,

    pub fn init(env: *Env) !void {}


};

pub const phase1Steps = [_]Step{
    .{ .msg = "Mount kernel virtual filesystems", .func = &mountKernelVirtualFileSystems },
    .{ .msg = "Attach /dev/kmsg", .func = &attachKmsg },
    .{ .msg = "Parse kernel arguments", .func = &parseKernelArguments },
    .{ .msg = "Load required kernel modules", .func = &loadRequiredModules },
    //.{ .msg = "Parse initramfs fstab", .func = &parseFstab },
    .{ .msg = "Integrity check fsroot", .func = &checkRootIntegrity },
    .{ .msg = "Mount fsroot and chroot", .func = &mountRootAndChroot },
    .{ .msg = "Execute the second part of the init system", .func = &execPhase2 },
};
