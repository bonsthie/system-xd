const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const Util = @import("build-system/util.zig");

const SRC_DIR = "src/";
const ENTRY_FILE = SRC_DIR ++ "main.zig";
const NAME = "init";

pub fn build(b: *Build) void {
    const network = b.dependency("network", .{}).module("network");
    const target = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .none });

    const exe = b.addExecutable(.{
        .name = NAME,
        .root_source_file = b.path(ENTRY_FILE),
        .target = target,
    });
    exe.root_module.addImport("network", network);
    b.installArtifact(exe);

    const xdCli = b.addExecutable(.{
        .name = "xd",
        .root_source_file = b.path("src/cli/xd.zig"),
        .target = target,
    });
    xdCli.root_module.addImport("network", network);
    b.installArtifact(xdCli);
}
