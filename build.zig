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

    const exe = b.addExecutable(.{
        .name = "test",
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("alpha-html", lib);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("test", "Run tests");
    run_step.dependOn(&run_cmd.step);
}
