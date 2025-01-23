const std = @import("std");
const log = std.log.scoped(.parser);
const tokensI = @import("../lexer/tokens.zig");
const Token = tokensI.Token;
const TokenKind = tokensI.TokenKind;
const ast = @import("../ast/ast.zig");
const BlockStmt = ast.BlockStmt;
const stmt = @import("stmt.zig");
const parse_stmt = stmt.parse_stmt;

pub const Parser = struct {
    tokens: std.ArrayList(Token),
    pos: *u32,

    pub fn init(tokens: std.ArrayList(Token), pos: *u32) Parser {
        return .{ .tokens = tokens, .pos = pos };
    }

    pub fn currentToken(p: @This()) Token {
        return p.tokens.items[@as(usize, @intCast(p.pos.*))];
    }

    pub fn currentTokenKind(p: @This()) TokenKind {
        return p.currentToken().kind;
    }

    pub fn advance(p: @This()) Token {
        const tk = p.currentToken();
        p.pos.* = p.pos.* + @as(u32, 1);
        return tk;
    }

    pub fn hasTokens(p: @This()) bool {
        return @as(usize, @intCast(p.pos.*)) < p.tokens.items.len and p.currentTokenKind() != .EOF;
    }
};

pub fn Parse(allocator: std.mem.Allocator, tokens: std.ArrayList(Token)) BlockStmt {
    var body = std.ArrayList(ast.Stmt).init(allocator);
    var pos: u32 = 0;
    var p = Parser.init(tokens, &pos);

    while (p.hasTokens()) {
        body.append(parse_stmt(&p)) catch |err| {
            log.err("Failed to append statement to body: {any}", .{err});
        };
    }

    return BlockStmt{ .body = body };
}
