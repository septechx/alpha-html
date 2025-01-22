const std = @import("std");

pub const Expr = struct {
    expr: fn () void,
};

pub const Stmt = struct {
    stmt: fn () void,
};
