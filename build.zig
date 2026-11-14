const builtin = @import("builtin");
const std = @import("std");

const zig_version: std.SemanticVersion = .{
    .major = 0,
    .minor = 17,
    .patch = 0,
};

comptime {
    const zig_version_equal =
        zig_version.major == builtin.zig_version.major and
        zig_version.minor == builtin.zig_version.minor and
        zig_version.patch == builtin.zig_version.patch;

    if (!zig_version_equal) @compileError(std.fmt.comptimePrint(
        "unsupported zig version: expected {f}, found {f}",
        .{ zig_version, builtin.zig_version },
    ));
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{ .os_tag = .windows } });
    const optimize = b.standardOptimizeOption(.{});

    const launcher = b.addExecutable(.{
        .name = "remielle-bootstrap",
        .win32_manifest = b.addWriteFiles().add(
            "launcher.manifest",
            @embedFile("win32_manifest.xml"),
        ),
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bootstrap.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(launcher);

    const dynlib = b.addLibrary(.{
        .name = "thaumiel",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/dynlib.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(dynlib);

    const assets_dir = b.root.openDir(b.graph.io, "assets", .{ .iterate = true }) catch |err| {
        std.debug.panic("unable to open assets directory: {t}", .{err});
    };
    defer assets_dir.close(b.graph.io);

    var it = assets_dir.iterateAssumeFirstIteration();
    while (it.next(b.graph.io) catch @panic("failed to read dir")) |entry| {
        if (std.mem.startsWith(u8, entry.name, ".") or entry.kind != .file)
            continue;

        dynlib.root_module.addAnonymousImport(
            entry.name,
            .{ .root_source_file = b.path(b.fmt("assets/{s}", .{entry.name})) },
        );
    }
}
