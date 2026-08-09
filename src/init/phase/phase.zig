const Env = @import("xd").system.Env;

const Type = enum {
    initramfs, // phase 1
    system, // phase 2
    service, // phase 3
};

const phase1 = @import("phase1.zig");
const phase2 = @import("phase2.zig");

pub fn run(phase: Type, env: Env) !void {
    switch (phase) {
        .initramfs => try phase1.run(env),
        .system => try phase2.run(env),
        .service => return error.ServicePhaseNotImplemented,
    }
}
