const std = @import("std");
const ast = @import("ast.zig");
const Expr = ast.Expr;

// Literal expressions
pub const TextExpr = struct {
    value: []const u8,

    fn expr() void {}
};

pub const StringExpr = struct {
    value: []const u8,

    fn expr() void {}
};

pub const SymbolExpr = struct {
    value: []const u8,

    fn expr() void {}
};
