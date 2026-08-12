const os = @import("std").os.linux;
const system = @import("xd").system;
const process = system.process;

const Cmdline = system.Cmdline;
const Env = system.Env;
const Fstab = system.fstab.Fstab;
const ServiceTable = system.service.ServiceTable;

const operations = @import("../operations/root.zig");
const step = @import("step.zig");

const fstab_path = "/etc/fstab";

pub const Ctx = struct {
    env: Env,
    cmdline: ?Cmdline = null,
    fstab: ?Fstab = null,

    pub fn init(env: Env) Ctx {
        return .{ .env = env };
    }

    pub fn deinit(self: *Ctx) void {
        if (self.cmdline) |*cmdline| cmdline.deinit();
        if (self.fstab) |*fstab| fstab.deinit();
    }

    fn requireCmdline(self: *Ctx) !*Cmdline {
        return if (self.cmdline) |*cmdline| cmdline else error.CmdlineNotLoaded;
    }

    fn requireFstab(self: *Ctx) !*Fstab {
        return if (self.fstab) |*fstab| fstab else error.FstabNotLoaded;
    }
};

const PhaseStep = step.Step(Ctx);

pub const Steps = [_]PhaseStep{
    .{ .msg = "Mount kernel virtual filesystems", .func = mountKernelVirtualFilesystems },
    .{ .msg = "Attach /dev/kmsg", .func = attachKmsg },
    .{ .msg = "Parse kernel arguments", .func = parseKernelArguments },
    .{ .msg = "Setup signal handlers", .func = setupSignalHandlers },
    .{ .msg = "Disable CAD syskey", .func = disableCadSyskey },
    .{ .msg = "Set system time", .func = setTime },
    .{ .msg = "Set system hostname", .func = setHostname },
    .{ .msg = "Set system locale", .func = setLocale },
    .{ .msg = "Read /etc/environ.xd", .func = readInitRc },
    .{ .msg = "Parse fstab", .func = parseFstab },
    .{ .msg = "Mount user filesystems", .func = mountUserFilesystems },
    .{ .msg = "Shut printk", .func = disablePrintk },
    .{ .msg = "Start login services", .func = startServices },
    //TODO: replace startServices with a step that starts the daemon and keeps its pid
};

pub fn run(env: Env) !noreturn {
    _ = os.setsid();

    var ctx = Ctx.init(env);
    defer ctx.deinit();

    try step.runAll(Ctx, &ctx, &Steps);
    operations.pid1.wait();
}

fn mountKernelVirtualFilesystems(ctx: *Ctx) !void {
    try operations.mounts.kernelVirtualFilesystems(ctx.env);
}

fn attachKmsg(ctx: *Ctx) !void {
    try operations.kmsg.attach(ctx.env);
}

fn disablePrintk(ctx: *Ctx) !void {
    try operations.machine.disablePrintk(ctx.env);
}

fn parseKernelArguments(ctx: *Ctx) !void {
    ctx.cmdline = try Cmdline.load(ctx.env);
}

fn setupSignalHandlers(_: *Ctx) !void {
    try operations.pid1.setupSignalHandlers();
}

fn disableCadSyskey(_: *Ctx) !void {
    try operations.pid1.disableCad();
}

fn setTime(ctx: *Ctx) !void {
    try operations.machine.setTime(ctx.env);
}

fn setHostname(ctx: *Ctx) !void {
    try operations.machine.setHostname(ctx.env, try ctx.requireCmdline());
}

fn setLocale(ctx: *Ctx) !void {
    try operations.machine.setLocale(ctx.env);
}

fn readInitRc(ctx: *Ctx) !void {
    try operations.machine.readInitRc(ctx.env);
}

fn parseFstab(ctx: *Ctx) !void {
    ctx.fstab = try system.fstab.load(ctx.env, fstab_path);
}

fn mountUserFilesystems(ctx: *Ctx) !void {
    try operations.mounts.configuredFilesystems(ctx.env, try ctx.requireFstab());
}

fn startServices(ctx: *Ctx) !void {
    try operations.pid1.startAndWatchDaemon(ctx.env);
}
