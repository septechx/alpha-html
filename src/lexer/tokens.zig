const std = @import("std");
const log = std.log.scoped(.lexer);

pub const TokenKind = enum {
    EOF,
    TEXT,
    OPEN_CURLY,
    CLOSE_CURLY,
    OPEN_DIV,
    CLOSE_DIV,
    OPEN_H1,
    CLOSE_H1,
    OPEN_H2,
    CLOSE_H2,
};

pub const Token = struct {
    kind: TokenKind,
    value: []const u8,

    pub fn debug(token: *Token) void {
        if (token.kind == .TEXT) {
            log.debug("{s} ({s})\n", .{ @tagName(token.kind), token.value });
        } else {
            log.debug("{s} ()\n", .{@tagName(token.kind)});
        }
    }
};
