const std = @import("std");
const lexer = @import("lexer/lexer.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var buf: [1024]u8 = undefined;
    const file = try std.fs.cwd().readFile("examples/01.html", &buf);
    const tokens = try lexer.Tokenize(allocator, file);
    defer tokens.deinit();
    for (tokens.items) |token| {
        var vtoken = token;
        vtoken.debug();
    }
}

test {
    std.testing.refAllDecls(@This());
}
