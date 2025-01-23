const std = @import("std");
const parser = @import("parser.zig");
const ast = @import("../ast/ast.zig");
const StringExpr = ast.StringExpr;
const TextExpr = ast.TextExpr;
const SymbolExpr = ast.SymbolExpr;
const tokens = @import("../lexer/tokens.zig");

pub fn parse_expr(p: *parser.Parser) ast.Expr {
    const tk = p.currentTokenKind();
    const next = p.advance().value;
    switch (tk) {
        .STRING => return .{ .string = StringExpr{ .value = next } },
        .TEXT => return .{ .text = TextExpr{ .value = next } },
        else => return .{ .symbol = SymbolExpr{ .value = next } },
    }
}
