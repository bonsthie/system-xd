//! The entrypoint for the `xd` daemon control command.

const std = @import("std");
const os = std.os.linux;

pub fn main() u8 {
    if (os.geteuid() != 0) {
        std.log.err("This command must be run as root (or with root privileges)", .{});
        return 1;
    }
    std.debug.print("Hello, world!\n", .{});
    return 0;
}
