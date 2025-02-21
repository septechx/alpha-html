const std = @import("std");
const @"alpha-html" = @import("alpha-html");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    try std.fs.cwd().deleteTree("test-out");
    try std.fs.cwd().makeDir("test-out");

    var example_dir = try std.fs.cwd().openDir("examples", .{ .iterate = true });
    defer example_dir.close();

    var walker = try example_dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |file| {
        const path = try std.fs.path.join(allocator, &[_][]const u8{ "examples", file.path });
        defer allocator.free(path);

        var buf: [256]u8 = undefined;
        const test_file = try std.fs.cwd().readFile(path, &buf);

        var html = @"alpha-html".Html.init(allocator);
        defer html.deinit();

        try html.parse(test_file);
        try html.lock();
        const base = try html.write(.{ .minify = false, .ignore_templates = true });
        const mini = try html.write(.{ .minify = true, .ignore_templates = true });

        try write(base, "base", file);
        try write(mini, "mini", file);
    }
}

fn write(content: []const u8, mod: []const u8, entry: std.fs.Dir.Walker.Entry) !void {
    var buf: [256]u8 = undefined;
    const newPath = try std.fmt.bufPrint(&buf, "test-out/{s}-{s}{s}", .{
        entry.basename,
        mod,
        std.fs.path.extension(entry.path),
    });

    const file = try std.fs.cwd().createFile(newPath, .{});
    defer file.close();

    try file.writeAll(content);
}
