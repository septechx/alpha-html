const std = @import("std");
const parser = @import("parser.zig");
const ast = @import("../ast/ast.zig");
const expr = @import("expr.zig");
const tokensI = @import("../lexer/tokens.zig");
const TokenKind = tokensI.TokenKind;
const stack = @import("../stack.zig");

pub fn parse_stmt(allocator: std.mem.Allocator, p: *parser.Parser, root: *std.ArrayList(ast.Stmt)) !?ast.Stmt {
    if (p.currentToken().isOneOfMany(&[_]TokenKind{ .END_TAG, .OPEN_TAG, .CLOSE_TAG, .OPEN_CURLY, .CLOSE_CURLY })) {
        processMode(p);
        _ = p.advance();

        return null;
    }

    if (p.mode == .TAG) {
        try p.stack.push(p.currentTokenKind());
        _ = p.advance();

        return .{ .block = ast.BlockStmt{ .body = std.ArrayList(ast.Stmt).init(allocator) } };
    } else if (p.mode == .END) {
        _ = try p.stack.pop();
        _ = p.advance();

        return null;
    }

    if (p.stack.top != 0) {
        var block = findBlock(root, 1);
        const expression = expr.parse_expr(p);
        try block.body.append(.{ .expression = ast.ExpressionStmt{ .expression = expression } });
        return null;
    }

    const expression = expr.parse_expr(p);
    return .{ .expression = ast.ExpressionStmt{ .expression = expression } };
}

fn findBlock(root: *std.ArrayList(ast.Stmt), i: u32) *ast.BlockStmt {
    const stmt = &root.items[root.items.len - i];
    if (stmt.isBlock()) {
        return &stmt.block;
    }
    return findBlock(root, i + 1);
}

fn processMode(p: *parser.Parser) void {
    switch (p.currentTokenKind()) {
        .OPEN_TAG => p.mode = .TAG,
        .CLOSE_TAG => p.mode = .END,
        .OPEN_CURLY => p.mode = .TEMPLATE,
        else => p.mode = .NORMAL,
    }
}
