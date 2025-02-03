const std = @import("std");
const parser = @import("parser.zig");
const ast = @import("../ast/ast.zig");
const expr = @import("expr.zig");
const tokensI = @import("../lexer/tokens.zig");
const TokenKind = tokensI.TokenKind;

pub fn parse_stmt(allocator: std.mem.Allocator, p: *parser.Parser, root: *std.ArrayList(ast.Stmt)) !?ast.Stmt {
    const shouldReturn = p.level == 0;
    const block: ?*ast.BlockStmt = findMostRecentBlock(p, root);

    if (p.currentToken().isOneOfMany(&[_]TokenKind{ .END_TAG, .OPEN_TAG, .CLOSE_TAG, .OPEN_CURLY, .CLOSE_CURLY, .EQUALS })) {
        processMode(p);
        _ = p.advance();

        return null;
    }

    if (p.currentToken().kind == .ATTRIBUTE) {
        p.attr_buf = p.advance();
        return null;
    }

    switch (p.mode) {
        .TAG => {
            const value = p.advance().value;
            p.level += 1;

            const ended = try allocator.create(bool);
            ended.* = false;
            return try make(shouldReturn, block, .{ .block = ast.BlockStmt{
                .body = std.ArrayList(ast.Stmt).init(allocator),
                .attributes = std.ArrayList(ast.Attr).init(allocator),
                .element = value,
                .ended = ended,
            } });
        },
        .END => {
            if (block) |b| {
                b.end();
            }
            p.level -= 1;
            _ = p.advance();

            return null;
        },
        .ATTRIBUTE => {
            if (block != null and p.attr_buf != null) {
                const buf = p.attr_buf;
                p.attr_buf = null;
                const str = p.advance();
                try block.?.attributes.append(.{ .key = buf.?.value, .value = str.value });
            } else {
                _ = p.advance();
            }
            return null;
        },
        else => {},
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

fn findMostRecentBlock(p: *parser.Parser, root: *std.ArrayList(ast.Stmt)) ?*ast.BlockStmt {
    if (p.level == 0) return null;

    var i: usize = root.items.len;
    while (i > 0) : (i -= 1) {
        const stmt = &root.items[i - 1];
        if (stmt.isBlock() and !stmt.ended()) {
            if (stmt.block.body.items.len > 0) {
                if (findMostRecentBlock(p, &stmt.block.body)) |nestedBlock| {
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
        .EQUALS => p.mode = .ATTRIBUTE,
        else => p.mode = .NORMAL,
    }
}
