const std = @import("std");
const log = std.log.scoped(.ast);
const BufPrintError = std.fmt.BufPrintError;

pub const Expr = union(enum) {
    text: TextExpr,
    string: StringExpr,
    symbol: SymbolExpr,

    pub fn debug(self: @This(), prev: []const u8) BufPrintError!void {
        switch (self) {
            inline else => |h| try h.debug(prev),
        }
    }
};

pub const Stmt = union(enum) {
    expression: ExpressionStmt,
    block: BlockStmt,

    pub fn debug(self: @This(), prev: []const u8) BufPrintError!void {
        switch (self) {
            inline else => |h| try h.debug(prev),
        }
    }
};

pub const BlockStmt = struct {
    body: std.ArrayList(Stmt),

    pub fn debug(block: @This(), prev: []const u8) BufPrintError!void {
        var buf: [64]u8 = undefined;
        const next = try std.fmt.bufPrint(&buf, "{s} > block", .{prev});

        for (block.body.items) |stmt| {
            try stmt.debug(next);
        }
    }
};

pub const ExpressionStmt = struct {
    expression: Expr,

    pub fn debug(stmt: @This(), prev: []const u8) BufPrintError!void {
        var buf: [64]u8 = undefined;
        const next = try std.fmt.bufPrint(&buf, "{s} > expr", .{prev});

        try stmt.expression.debug(next);
    }
};

pub const TextExpr = struct {
    value: []const u8,

    pub fn debug(expr: @This(), prev: []const u8) BufPrintError!void {
        var buf: [64]u8 = undefined;
        const next = try std.fmt.bufPrint(&buf, "{s} > text ({s})", .{ prev, expr.value });

        log.debug("{s}", .{next});
    }
};

pub const StringExpr = struct {
    value: []const u8,

    pub fn debug(expr: @This(), prev: []const u8) BufPrintError!void {
        var buf: [64]u8 = undefined;
        const next = try std.fmt.bufPrint(&buf, "{s} > string ({s})", .{ prev, expr.value });

        log.debug("{s}", .{next});
    }
};

pub const SymbolExpr = struct {
    value: []const u8,

    pub fn debug(expr: @This(), prev: []const u8) BufPrintError!void {
        var buf: [64]u8 = undefined;
        const next = try std.fmt.bufPrint(&buf, "{s} > symbol ({s})", .{ prev, expr.value });

        log.debug("{s}", .{next});
    }
};
