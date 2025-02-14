//! This file contains some boilerplate and helper functions for the build

const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

// Create a chain of system command that depend on each other
// b : the base build system
// cmds list of cmd ex .{
//      [_][]const u8{ "echo", "foo" },
//      [_][]const u8{ "echo", "bar" }
// }
pub fn createCmdScript(b: *Build, cwd: ?*const Build.LazyPath, comptime cmds: anytype) ?*Step {
    var lastStep: ?*Step = null;

    inline for (cmds) |cmd| {
        const cmd_slice = cmd[0..];
        const cmdStep = b.addSystemCommand(cmd_slice);
        if (cwd) |cwdPath| {
            cmdStep.setCwd(cwdPath.*);
        }
        if (lastStep) |prev| {
            cmdStep.step.dependOn(prev);
        }
        lastStep = &cmdStep.step;
    }

    return lastStep;
}
