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

const LOCALE_FILE = "/etc/locale.conf";

pub fn setLocale(env: Env) !void {
    const data = std.Io.Dir.readFileAlloc(.cwd(), env.io, LOCALE_FILE, env.allocator, .unlimited) catch {
        log.warn("Could not read {s}, setting default locale", .{ LOCALE_FILE });
        env.environ.put("LANG", "C.UTF-8") catch {};
        return;
    };

    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        if (!std.mem.startsWith(u8, line, "LC_")) {
            std.log.warn("locale.conf can only set LC_ variables, skipping {s}", .{line});
            continue;
        }
        const eq_pos = std.mem.indexOfScalar(u8, line, '=') orelse {
            std.log.warn("skipping malformed line: {s}", .{line});
            continue;
        };

        const key = std.mem.trim(u8, line[0..eq_pos], " \t");
        const value = std.mem.trim(u8, line[eq_pos + 1 ..], " \t");

        env.environ.put(key, value) catch {};
    }
}

const ENVIRON_FILE = "/etc/xd/environ";

pub fn readInitRc(env: Env) !void {
    const data = std.Io.Dir.readFileAlloc(.cwd(), env.io, ENVIRON_FILE, env.allocator, .unlimited) catch {
        log.warn("Could not read {s}, skipping.", .{ ENVIRON_FILE });
        return;
    };

    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        const eq_pos = std.mem.indexOfScalar(u8, line, '=') orelse {
            std.log.warn("skipping malformed line: {s}", .{line});
            continue;
        };

        const key = std.mem.trim(u8, line[0..eq_pos], " \t");
        const value = std.mem.trim(u8, line[eq_pos + 1 ..], " \t");

        env.environ.put(key, value) catch {};
    }
}
