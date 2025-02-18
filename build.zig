const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const Util = @import("build-system/util.zig");

const SRC_DIR = "src/";
const ENTRY_FILE = SRC_DIR ++ "main.zig";
const NAME = "init";

const target = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .none };

pub fn build(b: *Build) void {
    const network = b.dependency("network", .{});

    const exe = b.addExecutable(.{
        .name = NAME,
        .root_source_file = b.path(ENTRY_FILE),
        .target = b.resolveTargetQuery(target),
    });
    exe.root_module.addImport("network", network.module("network"));
    b.installArtifact(exe);

    const xdCli = b.addExecutable(.{
        .name = "xd",
        .root_source_file = b.path("src/cli/xd.zig"),
        .target = b.resolveTargetQuery(target),
    });
    xdCli.root_module.addImport("network", network.module("network"));
    b.installArtifact(xdCli);
}
