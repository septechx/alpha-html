const std = @import("std");
const lexer = @import("lexer/lexer.zig");
const parser = @import("parser/parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var buf: [1024]u8 = undefined;
    const file = try std.fs.cwd().readFile("examples/01.html", &buf);
    const tokens = try lexer.Tokenize(allocator, file);
    defer tokens.deinit();
    const ast = parser.Parse(allocator, tokens);
    defer ast.body.deinit();

    std.debug.print("==== TOKENS ====\n", .{});
    for (tokens.items) |token| {
        token.debug();
    }
    std.debug.print("==== AST ====\n", .{});
    try ast.debug("root");
}

test {
    std.testing.refAllDecls(@This());
}
