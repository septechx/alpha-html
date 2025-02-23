const std = @import("std");
const parser = @import("parser.zig");
const ast = @import("../ast/ast.zig");
const expr = @import("expr.zig");
const tokensI = @import("../lexer/tokens.zig");
const TokenKind = tokensI.TokenKind;
const Token = tokensI.Token;

const self_closing_tags = [_][]const u8{
    "area",
    "base",
    "br",
    "col",
    "embed",
    "hr",
    "img",
    "input",
    "link",
    "meta",
    "source",
    "track",
    "wbr",
};

pub fn parse_stmt(allocator: std.mem.Allocator, p: *parser.Parser, root: *std.ArrayList(ast.Stmt)) !?ast.Stmt {
    const shouldReturn = p.level == 0;
    const block = findMostRecentBlock(p, root, false);
    const blockMaybeEnded = findMostRecentBlock(p, root, true);

    if (p.currentToken().isOneOfMany(&[_]TokenKind{
        .END_TAG,
        .OPEN_TAG,
        .SELF_CLOSING_TAG,
        .CLOSE_TAG,
        .OPEN_CURLY,
        .CLOSE_CURLY,
        .EQUALS,
    })) {
        processMode(p);
        _ = p.advance();

        return null;
    }

    if (p.currentToken().isOneOfMany(&[_]TokenKind{
        .ATTRIBUTE,
        .OPTION,
        .AT_HANDLER,
    })) {
        processAttrType(p);
        processMode(p);
        p.tkn_buf = p.advance();

        return null;
    }

    switch (p.mode) {
        .TAG => {
            const value = p.advance().value;
            p.level += 1;

            const ended = try allocator.create(bool);
            ended.* = containsAtLeastScalarSlice(u8, &self_closing_tags, 1, value);

            return try make(shouldReturn, block, .{ .block = ast.BlockStmt{
                .body = std.ArrayList(ast.Stmt).init(allocator),
                .attributes = std.ArrayList(ast.Attr).init(allocator),
                .handlers = std.ArrayList(ast.Attr).init(allocator),
                .element = value,
                .ended = ended,
                .options = null,
                .self_closing = ended.*,
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
            const tkn = processTokenBuf(p);
            const str = p.advance();

            switch (p.attr_type.?) {
                .ATTRIBUTE => try blockMaybeEnded.?.attributes.append(.{ .key = tkn.?.value, .value = str.value }),
                .HANDLER => try blockMaybeEnded.?.handlers.append(.{ .key = tkn.?.value, .value = str.value }),
            }

            return null;
        },
        .VALUE => {
            const tkn = processTokenBuf(p);
            const val = p.advance();
            try p.opt_buf.append(.{ .key = tkn.?.value, .value = val.metadata.?.optionValue.? });

            return null;
        },
        else => {},
    }

    const expression = expr.parse_expr(p);
    return try make(shouldReturn, block, .{ .expression = ast.ExpressionStmt{ .expression = expression } });
}

fn containsAtLeastScalarSlice(comptime T: type, haystack: []const []const T, expected_count: usize, needle: []const T) bool {
    if (expected_count == 0) return true;

    var found: usize = 0;

    for (haystack) |item| {
        if (std.mem.eql(T, item, needle)) {
            found += 1;
            if (found == expected_count) return true;
        }
    }

    return false;
}

fn processTokenBuf(p: *parser.Parser) ?Token {
    defer p.tkn_buf = null;
    return p.tkn_buf;
}

fn make(shouldReturn: bool, block: ?*ast.BlockStmt, toMake: ast.Stmt) !?ast.Stmt {
    if (shouldReturn) {
        return toMake;
    }
    try block.?.body.append(toMake);
    return null;
}

fn findMostRecentBlock(p: *parser.Parser, root: *std.ArrayList(ast.Stmt), can_be_ended: bool) ?*ast.BlockStmt {
    if (p.level == 0) return null;

    var i: usize = root.items.len;
    while (i > 0) : (i -= 1) {
        const stmt = &root.items[i - 1];
        if (stmt.isBlock() and (can_be_ended or !stmt.ended())) {
            if (stmt.block.body.items.len > 0) {
                if (findMostRecentBlock(p, &stmt.block.body, can_be_ended)) |nestedBlock| {
                    if (can_be_ended or !nestedBlock.ended.*) {
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
        .OPTION => p.mode = .VALUE,
        else => p.mode = .NORMAL,
    }
}

fn processAttrType(p: *parser.Parser) void {
    switch (p.currentTokenKind()) {
        .ATTRIBUTE => p.attr_type = .ATTRIBUTE,
        .AT_HANDLER => p.attr_type = .HANDLER,
        else => p.attr_type = null,
    }
}
