const std = @import("std");
const lexer = @import("lexer/lexer.zig");
const parser = @import("parser/parser.zig");
const astI = @import("ast/ast.zig");
const BlockStmt = astI.BlockStmt;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer std.debug.assert(gpa.deinit() == .ok);

    var buf: [1024]u8 = undefined;
    const file = try std.fs.cwd().readFile("examples/08.html", &buf);
    const tokens = try lexer.Tokenize(allocator, file);
    defer tokens.deinit();

    //const ast = try parser.Parse(allocator, tokens);
    //defer ast.deinit(allocator);
    //const locked = try ast.lock(allocator);
    //defer locked.deinit(allocator);

    //var id: u32 = 0;

    //std.debug.print("==== TOKENS ====\n", .{});
    for (tokens.items) |token| {
        token.debug();
    }
    //std.debug.print("==== AST ====\n", .{});
    //try ast.debug("root", &id);
    //std.debug.print("==== Locked AST ====\n", .{});
    //try locked.debug(0);
}

test {
    std.testing.refAllDecls(@This());
}
