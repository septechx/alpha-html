const std = @import("std");
const log = std.log.scoped(.ast);
const BufPrintError = std.fmt.BufPrintError;
const tokensI = @import("../lexer/tokens.zig");
const TokenKind = tokensI.TokenKind;
const lexer = @import("../lexer/lexer.zig");

const AST_DEBUG_BUF_SIZE = 256;
const AST_DEBUG_ATTR_BUF_SIZE = 64;
const LOCKED_AST_BUF_SIZE = 64;

pub const LockStmtError = error{NoSpaceLeft};
pub const LockError = error{OutOfMemory};

pub const Expr = union(enum) {
    text: TextExpr,
    symbol: SymbolExpr,

    pub fn debug(self: @This(), prev: []const u8, id: *u32) BufPrintError!void {
        switch (self) {
            inline else => |h| try h.debug(prev, id),
        }
    }

    pub fn debugIntoBuf(self: @This(), buf: []u8) !usize {
        switch (self) {
            inline else => |h| return try h.debugIntoBuf(buf),
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

    pub fn isBlock(self: @This()) bool {
        switch (self) {
            inline else => |h| return h.isBlock(),
        }
    }

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        switch (self) {
            inline else => |h| h.deinit(allocator),
        }
    }

    pub fn lock(self: @This(), allocator: std.mem.Allocator) !LockedStmt {
        switch (self) {
            inline else => |h| return try h.lock(allocator),
        }
    }

    pub fn element(self: @This()) ?[]const u8 {
        switch (self) {
            inline else => |h| return h.getElement(),
        }
    }

    pub fn ended(self: @This()) bool {
        switch (self) {
            inline else => |h| return h.getEnded(),
        }
    }

    pub fn end(self: @This()) void {
        switch (self) {
            inline else => |h| h.end(),
        }
    }
};

pub const LockedStmt = union(enum) {
    expression: LockedExpressionStmt,
    block: LockedBlockStmt,

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        switch (self) {
            inline else => |h| h.deinit(allocator),
        }
    }

    pub fn debug(self: @This(), padding: u32) LockStmtError!void {
        switch (self) {
            inline else => |h| try h.debug(padding),
        }
    }
};

pub const LockedBlockStmt = struct {
    body: []LockedStmt,
    attributes: []Attr,
    options: ?[]Opt,
    element: []const u8,
    self_closing: bool,

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        for (self.body) |stmt| {
            stmt.deinit(allocator);
        }
        allocator.free(self.body);
    }

    pub fn debug(self: @This(), padding: u32) LockStmtError!void {
        if (padding >= LOCKED_AST_BUF_SIZE) return error.NoSpaceLeft;

        if (self.options) |opts| {
            try debugOpts(opts);
        }

        var buf: [LOCKED_AST_BUF_SIZE]u8 = undefined;
        @memset(buf[0..padding], ' ');
        const padded = buf[0..padding];

        var attr_buf: [AST_DEBUG_ATTR_BUF_SIZE]u8 = undefined;
        log.debug("{s}{s} Block ({s}) [{s}]", .{
            padded,
            if (padding == 0) "" else ">",
            self.element,
            makeAttributeString(self.attributes, &attr_buf) catch "",
        });

        for (self.body) |stmt| {
            try stmt.debug(padding + 4);
        }
    }
};

pub const LockedExpressionStmt = struct {
    expression: Expr,

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    pub fn debug(self: @This(), padding: u32) LockStmtError!void {
        if (padding >= LOCKED_AST_BUF_SIZE) return error.NoSpaceLeft;

        var buf: [LOCKED_AST_BUF_SIZE]u8 = undefined;
        @memset(buf[0..padding], ' ');
        const padded = buf[0..padding];

        var expBuf: [LOCKED_AST_BUF_SIZE]u8 = undefined;
        const len = try self.expression.debugIntoBuf(&expBuf);
        log.debug("{s}> Expression ({s})", .{ padded, expBuf[0..len] });
    }
};

pub const Opt = struct {
    key: []const u8,
    value: lexer.OptionValue,
};

pub const Attr = struct {
    key: []const u8,
    value: []const u8,
};

fn makeAttributeString(attributes: []Attr, buf: *[AST_DEBUG_ATTR_BUF_SIZE]u8) ![]u8 {
    if (attributes.len == 0) {
        return "";
    }

    var len = (try std.fmt.bufPrint(buf, "{s} -> {s}", .{ attributes[0].key, attributes[0].value })).len;

    for (attributes[1..]) |attr| {
        len = (try std.fmt.bufPrint(buf[len..], ", {s} -> {s}", .{ attr.key, attr.value })).len;
    }

    return buf[0..len];
}

fn debugOpts(opts: []Opt) !void {
    log.debug("<Options>", .{});
    for (opts) |opt| {
        log.debug("{s} -> [{s}] ({s})", .{ opt.key, @tagName(opt.value.getType()), try opt.value.getStringEq() });
    }
    log.debug("</Options>", .{});
}

pub const BlockStmt = struct {
    body: std.ArrayList(Stmt),
    attributes: std.ArrayList(Attr),
    handlers: std.ArrayList(Attr),
    options: ?std.ArrayList(Opt),
    element: ?[]const u8,
    ended: *bool,
    self_closing: bool,

    pub fn debug(block: @This(), prev: []const u8, id: *u32) BufPrintError!void {
        id.* += 1;

        if (block.options) |opts| {
            try debugOpts(opts.items);
        }

        var buf: [AST_DEBUG_BUF_SIZE]u8 = undefined;
        var attr_buf: [AST_DEBUG_ATTR_BUF_SIZE]u8 = undefined;
        const next = try std.fmt.bufPrint(&buf, "{s} > block #{d} ({s}) [{s}]", .{
            prev,
            id.*,
            block.element orelse "root",
            try makeAttributeString(block.attributes.items, &attr_buf),
        });

        var nId: u32 = 0;

        for (block.body.items) |stmt| {
            try stmt.debug(next, &nId);
        }
    }

    pub fn isBlock(self: @This()) bool {
        _ = self;
        return true;
    }

    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        for (self.body.items) |stmt| {
            stmt.deinit(allocator);
        }
        if (self.options) |opt| {
            opt.deinit();
        }
        self.body.deinit();
        self.attributes.deinit();
        self.handlers.deinit();
        allocator.destroy(self.ended);
    }

    pub fn lock(self: @This(), allocator: std.mem.Allocator) LockError!LockedStmt {
        const slice = try allocator.alloc(LockedStmt, self.body.items.len);

        for (self.body.items, 0..) |item, i| {
            slice[i] = try item.lock(allocator);
        }

        const options = if (self.options) |opts| opts.items else null;

        return .{ .block = .{
            .body = slice,
            .options = options,
            .attributes = self.attributes.items,
            .element = self.element orelse "root",
            .self_closing = self.self_closing,
        } };
    }

    pub fn getElement(self: @This()) ?[]const u8 {
        return self.element;
    }

    pub fn getEnded(self: @This()) bool {
        return self.ended.*;
    }

    pub fn end(self: @This()) void {
        self.ended.* = true;
    }
};

pub const ExpressionStmt = struct {
    expression: Expr,

    pub fn debug(stmt: @This(), prev: []const u8, id: *u32) BufPrintError!void {
        id.* += 1;

        var buf: [AST_DEBUG_BUF_SIZE]u8 = undefined;
        const next = try std.fmt.bufPrint(&buf, "{s} > expr #{d}", .{ prev, id.* });

        var nId: u32 = 0;

        try stmt.expression.debug(next, &nId);
    }

    pub fn isBlock(self: @This()) bool {
        _ = self;
        return false;
    }

    // Dummy method
    pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    pub fn lock(self: @This(), allocator: std.mem.Allocator) LockError!LockedStmt {
        _ = allocator;
        return .{ .expression = .{ .expression = self.expression } };
    }

    // Dummy method
    pub fn getElement(self: @This()) ?[]const u8 {
        _ = self;
        return null;
    }

    // Dummy method
    pub fn getEnded(self: @This()) bool {
        _ = self;
        return true;
    }

    // Dummy method
    pub fn end(self: @This()) void {
        _ = self;
    }
};

pub const TextExpr = struct {
    value: []const u8,

    pub fn debug(expr: @This(), prev: []const u8, id: *u32) BufPrintError!void {
        id.* += 1;

        var buf: [AST_DEBUG_BUF_SIZE]u8 = undefined;
        const next = try std.fmt.bufPrint(&buf, "{s} > text #{d} ({s})", .{ prev, id.*, expr.value });

        log.debug("{s}", .{next});
    }

    pub fn debugIntoBuf(self: @This(), buf: []u8) !usize {
        const result = try std.fmt.bufPrint(buf, "Text ({s})", .{self.value});
        return result.len;
    }
};

pub const SymbolExpr = struct {
    value: []const u8,
    type: SymbolType,

    pub fn debug(expr: @This(), prev: []const u8, id: *u32) BufPrintError!void {
        id.* += 1;

        var buf: [AST_DEBUG_BUF_SIZE]u8 = undefined;
        const next = try std.fmt.bufPrint(&buf, "{s} > symbol #{d} [{s}] ({s})", .{ prev, id.*, @tagName(expr.type), expr.value });

        log.debug("{s}", .{next});
    }

    pub fn debugIntoBuf(self: @This(), buf: []u8) !usize {
        const result = try std.fmt.bufPrint(buf, "Symbol [{s}] ({s})", .{ @tagName(self.type), self.value });
        return result.len;
    }
};

const SymbolType = enum {
    TEMPLATE,
};
