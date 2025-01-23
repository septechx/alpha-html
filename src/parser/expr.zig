const std = @import("std");
const log = std.log.scoped(.parser);
const parser = @import("parser.zig");
const ast = @import("../ast/ast.zig");
const StringExpr = ast.StringExpr;
const TextExpr = ast.TextExpr;
const SymbolExpr = ast.SymbolExpr;
const tokens = @import("../lexer/tokens.zig");

pub fn parse_expr(p: *parser.Parser) ast.Expr {
    switch (p.currentTokenKind()) {
        .STRING => return .{ .string = StringExpr{ .value = p.advance().value } },
        .TEXT => return .{ .text = TextExpr{ .value = p.advance().value } },
        else => return .{ .symbol = SymbolExpr{ .value = p.advance().value } },
    }
}
