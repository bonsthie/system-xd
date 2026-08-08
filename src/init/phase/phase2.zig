const system = @import("xd").system;
const Env = system.Env;
const Cmdline = system.Cmdline;
const RootSpec = @import("root.zig").RootSpec;

pub const Phase1Ctx = struct {
    env: Env,
    cmdline: ?Cmdline = null,
    root: ?RootSpec = null,

    pub fn init(env: *Env) !void {}
};
