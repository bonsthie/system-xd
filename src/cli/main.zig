//! The entrypoint for the `xd` daemon control command.

const std = @import("std");
const os = std.os.linux;
const log = std.log.scoped(.cli);

const command = @import("command.zig");

pub fn main(proc_init: std.process.Init) !u8 {
    if (os.geteuid() != 0) {
        log.err("This command must be run as root (or with root privileges)", .{});
        return 1;
    }

    const gpa = proc_init.gpa;
    const io = proc_init.io;
    const args = try proc_init.minimal.args.toSlice(proc_init.arena.allocator());

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--help")) {
            try command.run(gpa, io, "help", args);
            return 0;
        }
    }
    if (args.len == 1) {
        try command.run(gpa, io, "help", args);
        return 0;
    }

    command.run(gpa, io, args[1], args[2..]) catch |err| {
        log.err("Failed to run command '{s}': {s}", .{ args[1], @errorName(err) });
        return 1;
    };

    return 0;
}
