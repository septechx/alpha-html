const std = @import("std");
const log = std.log.scoped(.ast);
const BufPrintError = std.fmt.BufPrintError;

pub const Expr = union(enum) {
    text: TextExpr,
    string: StringExpr,
    symbol: SymbolExpr,

    pub fn debug(self: @This(), prev: []const u8, id: *u32) BufPrintError!void {
        switch (self) {
            inline else => |h| try h.debug(prev, id),
        }
    }
};

pub const Stmt = union(enum) {
    expression: ExpressionStmt,
    block: BlockStmt,

    pub fn debug(self: @This(), prev: []const u8, id: *u32) BufPrintError!void {
        switch (self) {
            inline else => |h| try h.debug(prev, id),
        }
    }
};

pub const BlockStmt = struct {
    body: std.ArrayList(Stmt),

    pub fn debug(block: @This(), prev: []const u8, id: *u32) BufPrintError!void {
        id.* += 1;

        var buf: [128]u8 = undefined;
        const next = try std.fmt.bufPrint(&buf, "{s} > block #{d}", .{ prev, id.* });

        var nId: u32 = 0;

        for (block.body.items) |stmt| {
            try stmt.debug(next, &nId);
        }
    }
};

pub const ExpressionStmt = struct {
    expression: Expr,

    pub fn debug(stmt: @This(), prev: []const u8, id: *u32) BufPrintError!void {
        id.* += 1;

        var buf: [128]u8 = undefined;
        const next = try std.fmt.bufPrint(&buf, "{s} > expr #{d}", .{ prev, id.* });

        var nId: u32 = 0;

        try stmt.expression.debug(next, &nId);
    }
};

pub const TextExpr = struct {
    value: []const u8,

    pub fn debug(expr: @This(), prev: []const u8, id: *u32) BufPrintError!void {
        id.* += 1;

        var buf: [128]u8 = undefined;
        const next = try std.fmt.bufPrint(&buf, "{s} > text #{d} ({s})", .{ prev, id.*, expr.value });

        log.debug("{s}", .{next});
    }
};

pub const StringExpr = struct {
    value: []const u8,

    pub fn debug(expr: @This(), prev: []const u8, id: *u32) BufPrintError!void {
        id.* += 1;

        var buf: [128]u8 = undefined;
        const next = try std.fmt.bufPrint(&buf, "{s} > string #{d} ({s})", .{ prev, id.*, expr.value });

        log.debug("{s}", .{next});
    }
};

pub const SymbolExpr = struct {
    value: []const u8,
    type: SymbolType,

    pub fn debug(expr: @This(), prev: []const u8, id: *u32) BufPrintError!void {
        id.* += 1;

        var buf: [128]u8 = undefined;
        const next = try std.fmt.bufPrint(&buf, "{s} > symbol #{d} [{s}] ({s})", .{ prev, id.*, @tagName(expr.type), expr.value });

        log.debug("{s}", .{next});
    }
};

const SymbolType = enum {
    TEMPLATE,
    ATTRIBUTE,
    TAG,
};
