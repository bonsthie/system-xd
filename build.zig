const std = @import("std");
const Build = std.Build;
const Import = Build.Module.Import;

const Executable = struct {
    name: []const u8,
    directory: []const u8,
    root_file: []const u8 = "main.zig",
    imports: []const Import = &.{},
    facade: ?Facade = null,

    const Facade = struct {
        name: []const u8,
        root_file: []const u8 = "root.zig",
        imports: []const Import = &.{},
    };
};

fn installExecutables(
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    executables: []const Executable,
) void {
    for (executables) |options| {
        const root_module = b.createModule(.{
            .root_source_file = b.path(b.pathJoin(&.{
                options.directory,
                options.root_file,
            })),
            .target = target,
            .optimize = optimize,
            .imports = options.imports,
        });

        if (options.facade) |facade_options| {
            const facade = b.createModule(.{
                .root_source_file = b.path(b.pathJoin(&.{
                    options.directory,
                    facade_options.root_file,
                })),
                .target = target,
                .optimize = optimize,
                .imports = facade_options.imports,
            });
            root_module.addImport(facade_options.name, facade);
        }

        const executable = b.addExecutable(.{
            .name = options.name,
            .root_module = root_module,
        });
        b.installArtifact(executable);
    }
}

pub fn build(b: *Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
        .abi = .none,
    });
    const optimize = b.standardOptimizeOption(.{});

    const toml = b.dependency("toml", .{}).module("toml");
    const libxd = b.addModule("xd", .{
        .root_source_file = b.path("src/libxd/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "toml", .module = toml },
        },
    });

    const common_imports: []const Import = &.{
        .{ .name = "xd", .module = libxd },
    };
    const networkd_imports: []const Import = &.{
        .{ .name = "xd", .module = libxd },
        .{ .name = "toml", .module = toml },
    };

    installExecutables(b, target, optimize, &.{
        .{
            .name = "init",
            .directory = "src/init",
            .imports = common_imports,
        },
        .{
            .name = "xd",
            .directory = "src/cli",
            .imports = common_imports,
        },
        .{
            .name = "xd-networkd",
            .directory = "src/networkd",
            .imports = common_imports,
            .facade = .{
                .name = "networkd",
                .imports = networkd_imports,
            },
        },
    });
}
