//! Some constants used throughout the project
const builtin = @import("builtin");

pub const debug = (builtin.mode == .Debug);

pub const Project = .{
    .name = "system-xd",
    .version = "0.0.1+indev",
    .authors = [_][]const u8{ "babonnet", "kiroussa" },
};
