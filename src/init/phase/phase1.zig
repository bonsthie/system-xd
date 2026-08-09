const os = @import("std").os.linux;
const system = @import("xd").system;

const Env = system.Env;
const Cmdline = system.Cmdline;
const syscall = system.syscall;

const operations = @import("../operations/root.zig");
const step = @import("step.zig");

const root_mount = "/mnt";
const module_list = "/modules.xd";

pub const Ctx = struct {
    env: Env,
    cmdline: ?Cmdline = null,
    root: ?operations.rootfs.RootSpec = null,

    pub fn init(env: Env) Ctx {
        return .{ .env = env };
    }

    pub fn deinit(self: *Ctx) void {
        if (self.cmdline) |*cmdline| cmdline.deinit();
        if (self.root) |*root| root.deinit(self.env.allocator);
    }

    fn requireCmdline(self: *Ctx) !*Cmdline {
        return if (self.cmdline) |*cmdline| cmdline else error.CmdlineNotLoaded;
    }

    fn requireRoot(self: *Ctx) !*operations.rootfs.RootSpec {
        return if (self.root) |*root| root else error.RootNotResolved;
    }
};

const PhaseStep = step.Step(Ctx);

pub const Steps = [_]PhaseStep{
    .{ .msg = "Mount kernel virtual filesystems", .func = mountKernelVirtualFilesystems },
    .{ .msg = "Attach /dev/kmsg", .func = attachKmsg },
    .{ .msg = "Parse kernel arguments", .func = parseKernelArguments },
    .{ .msg = "Load required kernel modules", .func = loadRequiredModules },
    .{ .msg = "Integrity check fsroot", .func = checkRootIntegrity },
    .{ .msg = "Mount fsroot and chroot", .func = mountRootAndChroot },
    .{ .msg = "Execute the second part of the init system", .func = execPhase2 },
};

pub fn run(env: Env) !void {
    _ = os.setsid();

    var ctx = Ctx.init(env);
    defer ctx.deinit();

    try step.runAll(Ctx, &ctx, &Steps);
}

fn mountKernelVirtualFilesystems(ctx: *Ctx) !void {
    try operations.mounts.kernelVirtualFilesystems(ctx.env);
}

fn attachKmsg(ctx: *Ctx) !void {
    try operations.kmsg.attach(ctx.env);
}

fn parseKernelArguments(ctx: *Ctx) !void {
    ctx.cmdline = try Cmdline.load(ctx.env);
}

fn loadRequiredModules(ctx: *Ctx) !void {
    try operations.modules.loadRequired(ctx.env, module_list);
}

fn resolveRoot(ctx: *Ctx) !void {
    if (ctx.root != null) return;
    ctx.root = try operations.rootfs.resolve(ctx.env, try ctx.requireCmdline());
}

fn checkRootIntegrity(ctx: *Ctx) !void {
    try resolveRoot(ctx);
    try operations.rootfs.checkAndMount(ctx.env, try ctx.requireRoot(), root_mount);
}

fn mountRootAndChroot(_: *Ctx) !void {
    try operations.rootfs.switchTo(root_mount);
}

fn execPhase2(_: *Ctx) !void {
    const argv = &[_:null]?[*:0]const u8{ "/sbin/init", "phase2", null };
    const envp = &[_:null]?[*:0]const u8{ "PATH=/usr/sbin:/sbin:/usr/bin:/bin", null };

    try syscall.execve("/sbin/init", argv, envp);
    return error.ExecReturned;
}
