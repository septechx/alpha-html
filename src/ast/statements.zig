const std = @import("std");
const ast = @import("ast.zig");
const Expr = ast.Expr;
const Stmt = ast.Stmt;

pub const BlockStmt = struct {
    body: std.ArrayList(Stmt),

    fn stmt() void {}
};

pub const TemplateStmt = struct {
    body: std.ArrayList(Stmt),

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{ .body = std.ArrayList(Stmt).init(allocator) };
    }

    fn stmt() void {}
};

pub const ExpressionStmt = struct {
    expression: Expr,

    fn stmt() void {}
};
