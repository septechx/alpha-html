const std = @import("std");
const testing = std.testing;

const lexer = @import("lexer/lexer.zig");

pub const Html = struct {};

test {
    std.testing.refAllDecls(@This());
}
