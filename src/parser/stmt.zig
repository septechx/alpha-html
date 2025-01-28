const std = @import("std");
const parser = @import("parser.zig");
const ast = @import("../ast/ast.zig");
const expr = @import("expr.zig");
const tokensI = @import("../lexer/tokens.zig");
const TokenKind = tokensI.TokenKind;
const stack = @import("../stack.zig");

pub fn parse_stmt(allocator: std.mem.Allocator, p: *parser.Parser, root: *std.ArrayList(ast.Stmt)) !?ast.Stmt {
    const shouldReturn = p.stack.top == 0;
    const block: ?*ast.BlockStmt = if (!shouldReturn) findMostRecentBlock(root) else null;

    if (p.currentToken().isOneOfMany(&[_]TokenKind{ .END_TAG, .OPEN_TAG, .CLOSE_TAG, .OPEN_CURLY, .CLOSE_CURLY })) {
        processMode(p);
        _ = p.advance();

        return null;
    }

    if (p.mode == .TAG) {
        const kind = p.advance().kind;
        try p.stack.push(kind);

        const ended = try allocator.create(bool);
        ended.* = false;
        return try make(shouldReturn, block, .{ .block = ast.BlockStmt{ .body = std.ArrayList(ast.Stmt).init(allocator), .element = kind, .ended = ended } });
    } else if (p.mode == .END) {
        block.?.end();
        _ = try p.stack.pop();
        _ = p.advance();

        return null;
    }

    const expression = expr.parse_expr(p);
    return try make(shouldReturn, block, .{ .expression = ast.ExpressionStmt{ .expression = expression } });
}

fn make(shouldReturn: bool, block: ?*ast.BlockStmt, toMake: ast.Stmt) !?ast.Stmt {
    if (shouldReturn) {
        return toMake;
    } else {
        try block.?.body.append(toMake);
        return null;
    }
}

fn findMostRecentBlock(root: *std.ArrayList(ast.Stmt)) ?*ast.BlockStmt {
    if (root.items.len == 0) return null;

    var i: usize = root.items.len;
    while (i > 0) : (i -= 1) {
        const stmt = &root.items[i - 1];
        if (stmt.isBlock() and !stmt.ended()) {
            if (stmt.block.body.items.len > 0) {
                if (findMostRecentBlock(&stmt.block.body)) |nestedBlock| {
                    if (!nestedBlock.ended.*) {
                        return nestedBlock;
                    }
                }
            }
            return &stmt.block;
        }
    }

    return null;
}

fn processMode(p: *parser.Parser) void {
    switch (p.currentTokenKind()) {
        .OPEN_TAG => p.mode = .TAG,
        .CLOSE_TAG => p.mode = .END,
        .OPEN_CURLY => p.mode = .TEMPLATE,
        else => p.mode = .NORMAL,
    }
}
