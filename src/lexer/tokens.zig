const std = @import("std");
const log = std.log.scoped(.lexer);

pub const TokenKind = enum {
    EOF,
    TEXT,
    STRING,
    OPEN_CURLY,
    CLOSE_CURLY,
    OPEN_TAG,
    CLOSE_TAG,
    END_TAG,
    EQUALS,

    CLASS,
    DIV,
    H1,
    H2,
};

pub const Reserved = enum {
    class,
    div,
    h1,
    h2,

    pub fn toTokenKind(self: @This()) TokenKind {
        const tag_name = @tagName(self);
        var buf: [16]u8 = undefined;
        const upper = std.ascii.upperString(&buf, tag_name);
        return std.meta.stringToEnum(TokenKind, upper) orelse unreachable;
    }
};

pub const Token = struct {
    kind: TokenKind,
    value: []const u8,

    pub fn debug(token: @This()) void {
        if (token.isOneOfMany(&[_]TokenKind{ .STRING, .TEXT })) {
            log.debug("{s} ({s})\n", .{ @tagName(token.kind), token.value });
        } else {
            log.debug("{s} ()\n", .{@tagName(token.kind)});
        }
    }

    pub fn isOneOfMany(token: @This(), tokens: []const TokenKind) bool {
        for (tokens) |kind| {
            if (token.kind == kind) {
                return true;
            }
        }
        return false;
    }
};
