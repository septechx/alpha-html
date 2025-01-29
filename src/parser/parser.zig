const std = @import("std");
const log = std.log.scoped(.parser);
const tokensI = @import("../lexer/tokens.zig");
const Token = tokensI.Token;
const TokenKind = tokensI.TokenKind;
const ast = @import("../ast/ast.zig");
const BlockStmt = ast.BlockStmt;
const stmt = @import("stmt.zig");
const parse_stmt = stmt.parse_stmt;
const stackI = @import("../stack.zig");
const Stack = stackI.Stack;
const StackError = stackI.StackError;

const STACK_SIZE: usize = 64;

pub const ParserMode = enum {
    NORMAL,
    TEMPLATE,
    TAG,
    END,
    ATTRIBUTE,
};

pub const Parser = struct {
    tokens: std.ArrayList(Token),
    pos: u32,
    mode: ParserMode,
    stack: Stack(TokenKind, STACK_SIZE),
    attr_buf: ?Token,

    pub fn init(tokens: std.ArrayList(Token)) Parser {
        return .{
            .tokens = tokens,
            .pos = 0,
            .mode = .NORMAL,
            .attr_buf = null,
            .stack = Stack(TokenKind, STACK_SIZE).init(),
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
        log.debug("Mode: {any}", .{p.mode});
        p.stack.debug();
    }
};

pub fn Parse(allocator: std.mem.Allocator, tokens: std.ArrayList(Token)) !BlockStmt {
    var body = std.ArrayList(ast.Stmt).init(allocator);
    var p = Parser.init(tokens);

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
        .body = body,
        .ended = ended,
        .element = null,
    };
}
