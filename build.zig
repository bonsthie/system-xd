const std = @import("std");
const Build = std.Build;
const Step = Build.Step;
const Import = Build.Module.Import;
const Util = @import("build-system/util.zig");

const SRC_DIR = "src/";

const INIT_DIR = SRC_DIR ++ "init/";
const INIT_ROOT_FILE = INIT_DIR ++ "main.zig";
const INIT_NAME = "init";

const CLI_DIR = SRC_DIR ++ "cli/";
const CLI_ROOT_FILE = CLI_DIR ++ "main.zig";
const CLI_NAME = "xd";

const LIBXD_DIR = SRC_DIR ++ "libxd/";
const LIBXD_ROOT_FILE = LIBXD_DIR ++ "root.zig";
const LIBXD_NAME = "xd";

pub fn build(b: *Build) void {
    const target = b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .none });
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .Debug });

    const toml = b.dependency("toml", .{}).module("toml");

    const libxdImports: []const Import = &.{
        .{ .name = "toml", .module = toml },
    };

    const libxd = b.addModule(LIBXD_NAME, .{
        .root_source_file = b.path(LIBXD_ROOT_FILE),
        .target = target,
        .optimize = optimize,
        .imports = libxdImports,
    });

    const imports: []const Import = &.{
        .{ .name = LIBXD_NAME, .module = libxd },
    };

    const init = b.addExecutable(.{
        .name = INIT_NAME,
        .root_module = b.createModule(.{
            .root_source_file = b.path(INIT_ROOT_FILE),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        }),
    });
    b.installArtifact(init);

    const cli = b.addExecutable(.{
        .name = CLI_NAME,
        .root_module = b.createModule(.{
            .root_source_file = b.path(CLI_ROOT_FILE),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        }),
    });
    b.installArtifact(cli);
}
