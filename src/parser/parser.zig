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
    END,
    ATTRIBUTE,
    VALUE,
};

pub const Parser = struct {
    tokens: std.ArrayList(Token),
    opt_buf: std.ArrayList(ast.Opt),
    pos: u32,
    mode: ParserMode,
    level: u32,
    tkn_buf: ?Token,

    pub fn init(allocator: std.mem.Allocator, tokens: std.ArrayList(Token)) Parser {
        return .{
            .opt_buf = std.ArrayList(ast.Opt).init(allocator),
            .tokens = tokens,
            .pos = 0,
            .level = 0,
            .mode = .NORMAL,
            .tkn_buf = null,
        };
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

    pub fn skipTo(p: *Parser, n: u32) void {
        p.pos += n;
    }

    pub fn hasTokens(p: *Parser) bool {
        return @as(usize, @intCast(p.pos)) < p.tokens.items.len and p.currentTokenKind() != .EOF;
    }

    pub fn debug(p: *Parser) void {
        log.debug("Pos: {d}", .{p.pos});
        log.debug("Level: {d}", .{p.level});
        log.debug("Mode: {s}", .{@tagName(p.mode)});
    }
};

pub fn Parse(allocator: std.mem.Allocator, tokens: std.ArrayList(Token)) !BlockStmt {
    var body = std.ArrayList(ast.Stmt).init(allocator);
    var p = Parser.init(allocator, tokens);

    while (p.hasTokens()) {
        const statement = try parse_stmt(allocator, &p, &body);
        if (statement == null) {
            continue;
        }

        body.append(statement.?) catch |err| {
            log.err("Failed to append statement to body: {any}", .{err});
        };
    }

    p.debug();

    const ended = try allocator.create(bool);
    ended.* = true;
    return BlockStmt{
        .attributes = std.ArrayList(ast.Attr).init(allocator),
        .options = p.opt_buf,
        .body = body,
        .ended = ended,
        .element = null,
    };
}
