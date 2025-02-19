const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addModule("alpha-html", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mvzr = b.dependency("mvzr", .{
        .target = target,
        .optimize = optimize,
    });
    lib.addImport("mvzr", mvzr.module("mvzr"));
}
