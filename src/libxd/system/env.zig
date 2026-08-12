const std = @import("std");

pub const Env = struct {
    allocator : std.mem.Allocator,
    io        : std.Io,
    environ   : *std.process.Environ.Map,
    init      : bool = true,
};
