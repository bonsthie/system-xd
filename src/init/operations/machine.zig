const std = @import("std");
const system = @import("xd").system;

const Cmdline = system.Cmdline;
const Env = system.Env;
const syscall = system.syscall;
const log = std.log.scoped(.machine);

const rtc_device = "/dev/rtc0";
const default_epoch: i64 = 1_735_689_600;

pub fn disablePrintk(env: Env) !void {
    const file = std.Io.Dir.openFileAbsolute(env.io, "/proc/sys/kernel/printk", .{ .mode = .write_only }) catch |err| {
        log.warn("Could not open /proc/sys/kernel/printk: {s}", .{@errorName(err)});
        return;
    };
    defer file.close(env.io);

    var writer_buffer: [16]u8 = undefined;
    var writer = file.writerStreaming(env.io, &writer_buffer);
    try writer.interface.print("1\n", .{});
    try writer.interface.flush();
}

pub fn setTime(env: Env) !void {
    const now = std.Io.Clock.now(.real, env.io);
    if (now.toSeconds() > 0) {
        log.info("time already set: {}", .{now});
        return;
    }

    log.info("time is not set, attempting RTC read from {s}", .{rtc_device});

    const unix_time: i64 = blk: {
        const file = std.Io.Dir.openFileAbsolute(env.io, rtc_device, .{}) catch |err| {
            log.warn("Could not open {s}: {s}, falling back to default time", .{ rtc_device, @errorName(err) });
            break :blk default_epoch;
        };
        defer file.close(env.io);

        const rtc_time = system.rtc.readTime(file.handle) catch |err| {
            log.warn("RTC_RD_TIME failed: {s}, falling back to default time", .{@errorName(err)});
            break :blk default_epoch;
        };

        log.info("Read RTC time: {d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2} UTC", .{
            rtc_time.tm_year + 1900, rtc_time.tm_mon + 1, rtc_time.tm_mday,
            rtc_time.tm_hour,        rtc_time.tm_min,     rtc_time.tm_sec,
        });
        break :blk system.rtc.toUnix(rtc_time);
    };

    const timestamp = std.os.linux.timespec{ .sec = unix_time, .nsec = 0 };
    _ = try syscall.clock_settime(std.os.linux.CLOCK.REALTIME, &timestamp);
    log.info("System time set to {d}", .{unix_time});
}

pub fn setHostname(env: Env, cmdline: ?*const Cmdline) !void {
    const hostname = blk: {
        if (cmdline) |args| {
            if (args.get("hostname")) |hostname| {
                break :blk try env.allocator.dupe(u8, hostname);
            }
        }

        const file = std.Io.Dir.openFileAbsolute(env.io, "/etc/hostname", .{}) catch {
            log.warn("Could not open /etc/hostname, setting default hostname", .{});
            break :blk try env.allocator.dupe(u8, "xd-machine");
        };
        defer file.close(env.io);

        var reader_buffer: [512]u8 = undefined;
        var reader = file.reader(env.io, &reader_buffer);
        break :blk try reader.interface.allocRemaining(env.allocator, .limited(4096));
    };
    defer env.allocator.free(hostname);

    const hostname_z = try env.allocator.dupeZ(u8, hostname);
    defer env.allocator.free(hostname_z);

    var len = hostname.len;
    if (std.mem.indexOfScalar(u8, hostname_z, '\n')) |newline| {
        hostname_z[newline] = 0;
        len = newline;
    }
    len = @min(len, 255);

    try syscall.sethostname(hostname_z, len);
    log.info("Hostname set to {s}", .{hostname_z});
}
