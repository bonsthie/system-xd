//! The entrypoint for the `xd` daemon control command.

const std = @import("std");
const os = std.os.linux;
const log = std.log.scoped(.cli);

const xd = @import("xd");
const Env = xd.system.Env;

const command = @import("command.zig");

pub fn main(proc_init: std.process.Init) !u8 {
    if (!xd.consts.debug and os.geteuid() != 0) {
        log.err("This command must be run as root (or with root privileges)", .{});
        return 1;
    }

    const env = Env{ .allocator = proc_init.gpa, .io = proc_init.io };
    const args = try proc_init.minimal.args.toSlice(proc_init.arena.allocator());

    var help = false;
    for (args) |arg| blk: {
        if (std.mem.eql(u8, arg, "--help")) {
            help = true;
            break :blk;
        }
    }
    if (args.len == 1 or help) {
        try command.run(env, "help", args);
        return 0;
    }

    command.run(env, args[1], args[2..]) catch |err| {
        log.err("Failed to run command '{s}': {s}", .{ args[1], @errorName(err) });
        return 1;
    };

    return 0;
}
