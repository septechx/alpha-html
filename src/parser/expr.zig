const std = @import("std");
const log = std.log.scoped(.parser);
const parser = @import("parser.zig");
const ast = @import("../ast/ast.zig");
const expressions = @import("../ast/expressions.zig");
const StringExpr = expressions.StringExpr;
const TextExpr = expressions.TextExpr;
const SymbolExpr = expressions.SymbolExpr;
const tokens = @import("../lexer/tokens.zig");

pub fn parse_expr(p: *parser.Parser) ast.Expr {
    switch (p.currentTokenKind()) {
        .STRING => return StringExpr{ .value = p.advance().value },
        .TEXT => return TextExpr{ .value = p.advance().value },
        else => log.err("Cannot create primary_expression from {s}\n", .{@tagName(p.currentTokenKind())}),
    }
}
