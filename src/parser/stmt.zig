const std = @import("std");
const parser = @import("parser.zig");
const ast = @import("../ast/ast.zig");
const expr = @import("expr.zig");
const tokensI = @import("../lexer/tokens.zig");
const TokenKind = tokensI.TokenKind;

pub fn parse_stmt(p: *parser.Parser) ast.Stmt {
    const expression = expr.parse_expr(p);
    return .{ .expression = ast.ExpressionStmt{ .expression = expression } };
}
