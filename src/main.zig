const std = @import("std");
const log = std.log.scoped(.main);
const os = std.os.linux;
const fs = std.fs;
const consts = @import("consts.zig");
const customLogFn = @import("log.zig").customLogFn;

const init = @import("init.zig");

pub const std_options = .{
    .logFn = customLogFn,
    .log_level = if (consts.debug) .debug else .info,
};

fn coerceProjectAuthors() []const u8 {
    const authors = comptime &consts.Project.authors;
    comptime var result: []const u8 = undefined;
    const sep = ", ";
    const final_sep = ", and ";
    const two_final_sep = " and ";
    comptime var i: usize = 0;
    inline for (authors) |author| {
        if (i == 0) {
            result = author;
        } else if (i == authors.len - 1) {
            if (i == 1) {
                result = result ++ two_final_sep ++ author;
            } else {
                result = result ++ final_sep ++ author;
            }
        } else {
            result = result ++ sep ++ author;
        }
        i += 1;
    }
    return result;
}

pub fn main() !void {
    const pid = os.getpid();
    log.debug("PID: {d}", .{pid});
    if (pid != 1) {
        if (consts.debug) {
            log.debug("Bypassing PID check because program was compiled in debug mode", .{});
        } else {
            log.err("This program must be run as PID 1", .{});
            return;
        }
    }

    {
        const project = consts.Project;
        log.info("Launching {s} v{s}", .{ project.name, project.version });
        log.info("This dumbfuckery is brought to you by {s}", .{coerceProjectAuthors()});
    }

    init.cowabunga() catch |err| {
        log.err("Caught an unexpected error: {s}", .{@errorName(err)});
        log.err("Dropping you in an emergency shell, you're on your own...", .{});
        const argv = &[_:null]?[*:0]const u8{ "/bin/sh", "-i" };
        const envp = &[_:null]?[*:0]const u8{ "PATH=/usr/sbin:/sbin:/usr/bin:/bin", "HOME=/", "TERM=linux", "XD_RECOVERY_SHELL=1" };
        const syscall_ret = os.execve("/bin/sh", argv, envp);
        log.err("Failed to execve /bin/sh: E{s}", .{@tagName(os.E.init(syscall_ret))});
        _ = os.reboot(os.LINUX_REBOOT.MAGIC1.MAGIC1, os.LINUX_REBOOT.MAGIC2.MAGIC2, os.LINUX_REBOOT.CMD.RESTART, null);
    };
}
