const std = @import("std");
const tokensI = @import("../lexer/tokens.zig");
const Reserved = tokensI.Reserved;
const TokenKind = tokensI.TokenKind;

fn reservedTokenKind(comptime T: type) type {
    return @Type(.{
        .Enum = .{
            .tag_type = @typeInfo(T).Enum.tag_type,
            .fields = &[_]std.builtin.Type.EnumField{
                inline for (@typeInfo(Reserved).Enum.fields) |f| .{
                    .name = f.name,
                    .value = f.value,
                },
            },
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
}

pub const ReservedTokenKind = reservedTokenKind(TokenKind);
