const std = @import("std");
const parser = @import("parser.zig");
const ast = @import("../ast/ast.zig");
const lookups = @import("lookups.zig");
const expr = @import("expr.zig");
const tokensI = @import("../lexer/tokens.zig");
const TokenKind = tokensI.TokenKind;
const statements = @import("../ast/statements.zig");

fn containsEnumMember(comptime T: type, value: T) bool {
    const info = @typeInfo(T).Enum;
    for (info.fields) |field| {
        if (field.value == @intFromEnum(value)) {
            return true;
        }
    }
    return false;
}

pub fn parse_stmt(p: *parser.Parser) ast.Stmt {
    if (containsEnumMember(lookups.ReservedTokenKind, p.currentTokenKind())) {
        return ast.Stmt{};
    }

    const expression = expr.parse_expr(p);

    return statements.ExpressionStmt{ .expression = expression };
}
