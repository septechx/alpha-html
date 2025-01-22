const std = @import("std");
const tokensI = @import("../lexer/tokens.zig");
const Token = tokensI.Token;
const TokenKind = tokensI.TokenKind;
const statements = @import("../ast/statements.zig");
const BlockStmt = statements.BlockStmt;
const ast = @import("../ast/ast.zig");
const stmt = @import("stmt.zig");
const parse_stmt = stmt.parse_stmt;

pub const Parser = struct {
    tokens: std.ArrayList(Token),
    pos: u32,

    pub fn init(tokens: std.ArrayList(Token)) Parser {
        return .{ .tokens = tokens, .pos = 0 };
    }

    pub fn currentToken(p: @This()) Token {
        return p.tokens[p.pos];
    }

    pub fn currentTokenKind(p: @This()) TokenKind {
        return p.currentToken().kind;
    }

    pub fn advance(p: @This()) Token {
        const tk = p.currentToken();
        p.pos += 1;
        return tk;
    }

    pub fn hasTokens(p: @This()) bool {
        return p.pos < p.tokens.items.len and p.currentTokenKind() != .EOF;
    }
};

fn Parse(allocator: std.mem.Allocator, tokens: std.ArrayList(Token)) BlockStmt {
    const body = std.ArrayList(ast.Stmt).init(allocator);
    const p = Parser.init(tokens);

    while (p.hasTokens()) {
        body.append(parse_stmt(&p));
    }

    return BlockStmt{ .body = body };
}
