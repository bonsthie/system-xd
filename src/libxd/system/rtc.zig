const std = @import("std");
const linux = std.os.linux;
const wrapErrno = @import("errno.zig").wrapErrno;

pub const RtcTime = extern struct {
    tm_sec: i32,
    tm_min: i32,
    tm_hour: i32,
    tm_mday: i32,
    tm_mon: i32,
    tm_year: i32,
    tm_wday: i32 = 0,
    tm_yday: i32 = 0,
    tm_isdst: i32 = 0,
};

const RTC_RD_TIME: u32 = 0x80247009;

pub fn readRtcTime(fd: linux.fd_t) !RtcTime {
    var t: RtcTime = std.mem.zeroes(RtcTime);
    _ = try wrapErrno(linux.ioctl(fd, RTC_RD_TIME, @intFromPtr(&t)));
    return t;
}

pub fn rtcTimeToUnix(t: RtcTime) i64 {
    const year: i64 = @as(i64, t.tm_year) + 1900;
    const month: i64 = @as(i64, t.tm_mon) + 1; // tm_mon is 0-11
    const day: i64 = @as(i64, t.tm_mday);

    const y: i64 = if (month <= 2) year - 1 else year;
    const era: i64 = @divFloor(if (y >= 0) y else y - 399, 400);
    const yoe: i64 = y - era * 400;
    const mp: i64 = @mod(month + 9, 12);
    const doy: i64 = @divFloor(153 * mp + 2, 5) + day - 1;
    const doe: i64 = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    const days_since_epoch: i64 = era * 146097 + doe - 719468;

    return days_since_epoch * 86400 + @as(i64, t.tm_hour) * 3600 + @as(i64, t.tm_min) * 60 + @as(i64, t.tm_sec);
}
