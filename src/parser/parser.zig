const std = @import("std");
const log = std.log.scoped(.parser);
const tokensI = @import("../lexer/tokens.zig");
const Token = tokensI.Token;
const TokenKind = tokensI.TokenKind;
const ast = @import("../ast/ast.zig");
const BlockStmt = ast.BlockStmt;
const stmt = @import("stmt.zig");
const parse_stmt = stmt.parse_stmt;

pub const ParserMode = enum {
    NORMAL,
    TEMPLATE,
    TAG,
};

pub const Parser = struct {
    tokens: std.ArrayList(Token),
    pos: u32,
    mode: ParserMode,

    pub fn init(tokens: std.ArrayList(Token)) Parser {
        return .{ .tokens = tokens, .pos = 0, .mode = .NORMAL };
    }

    pub fn currentToken(p: *Parser) Token {
        return p.tokens.items[@as(usize, @intCast(p.pos))];
    }

    pub fn currentTokenKind(p: *Parser) TokenKind {
        return p.currentToken().kind;
    }

    pub fn advance(p: *Parser) Token {
        const tk = p.currentToken();
        p.pos += 1;
        return tk;
    }

    pub fn hasTokens(p: *Parser) bool {
        return @as(usize, @intCast(p.pos)) < p.tokens.items.len and p.currentTokenKind() != .EOF;
    }
};

pub fn Parse(allocator: std.mem.Allocator, tokens: std.ArrayList(Token)) BlockStmt {
    var body = std.ArrayList(ast.Stmt).init(allocator);
    var p = Parser.init(tokens);

    while (p.hasTokens()) {
        const statement = parse_stmt(&p);
        if (statement == null) {
            continue;
        }

        body.append(statement.?) catch |err| {
            log.err("Failed to append statement to body: {any}", .{err});
        };
    }

    return BlockStmt{ .body = body };
}
