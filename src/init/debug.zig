const std = @import("std");
const os = std.os.linux;
const log = std.log.scoped(.debug);

const consts = @import("xd").consts;

pub fn isPid1() !void {
    const pid = os.getpid();
    log.debug("PID: {d}", .{pid});
    if (pid != 1) {
        if (consts.debug) {
            log.debug("Bypassing PID check because program was compiled in debug mode", .{});
        } else {
            log.err("This program must be run as PID 1", .{});
            return error.notPid1;
        }
    }
}
