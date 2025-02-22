const std = @import("std");
const log = std.log.scoped(.lexer);
const lexer = @import("lexer.zig");

pub const TokenKind = enum {
    EOF,
    TEXT,
    STRING,
    TEMPLATE,
    OPEN_CURLY,
    CLOSE_CURLY,
    OPEN_TAG,
    CLOSE_TAG,
    SELF_CLOSING_TAG,
    END_TAG,
    EQUALS,
    ATTRIBUTE,
    ELEMENT,
    OPTION,
    VALUE,
    AT_HANDLER,

    fakeSTART,
};

const TokenMetadata = struct {
    optionValue: ?lexer.OptionValue = null,
};

pub const Token = struct {
    metadata: ?TokenMetadata = null,
    kind: TokenKind,
    value: []const u8,

    pub fn debug(token: @This()) void {
        if (token.isOneOfMany(&[_]TokenKind{
            .STRING,
            .TEXT,
            .TEMPLATE,
            .ATTRIBUTE,
            .ELEMENT,
            .OPTION,
            .AT_HANDLER,
        })) {
            log.debug("{s} ({s})", .{ @tagName(token.kind), token.value });
        } else if (token.kind == .VALUE) {
            log.debug("{s} [{s}] ({s})", .{ @tagName(token.kind), @tagName(token.metadata.?.optionValue.?), token.value });
        } else {
            log.debug("{s} ()", .{@tagName(token.kind)});
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
