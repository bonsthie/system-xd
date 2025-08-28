const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const Util = @import("build-system/util.zig");

const SRC_DIR = "src/";

const INIT_DIR = SRC_DIR ++ "";
const INIT_ROOT_FILE = INIT_DIR ++ "main.zig";
const INIT_NAME = "init";

const CLI_DIR = SRC_DIR ++ "cli/";
const CLI_ROOT_FILE = CLI_DIR ++ "main.zig";
const CLI_NAME = "xd";


pub fn build(b: *Build) void {
    const network = b.dependency("network", .{}).module("network");
    const target = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .none });
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path(INIT_ROOT_FILE),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = INIT_NAME,
        .root_module = mod,
    });
    exe.root_module.addImport("network", network);
    b.installArtifact(exe);

    const xdCli = b.addExecutable(.{
        .name = CLI_NAME,
        .root_module = b.createModule(.{
            .root_source_file = b.path(CLI_ROOT_FILE),
            .target = target,
            .optimize = optimize,
        }),
    });
    xdCli.root_module.addImport("network", network);
    b.installArtifact(xdCli);
}
