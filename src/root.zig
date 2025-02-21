const std = @import("std");
pub const lexer = @import("lexer/lexer.zig");
pub const ast = @import("ast/ast.zig");
pub const parser = @import("parser/parser.zig");
pub const writer = @import("writer/writer.zig");

pub const Html = struct {
    allocator: std.mem.Allocator,
    ast: ?ast.BlockStmt,
    locked: ?ast.LockedBlockStmt,
    written: ?std.ArrayList(u8),

    pub const WriteOptions = struct {
        minify: bool = false,
        ignore_templates: bool = false,
    };

    const Self = *Html;

    pub fn init(allocator: std.mem.Allocator) Html {
        return .{
            .allocator = allocator,
            .ast = null,
            .locked = null,
            .written = null,
        };
    }

    pub fn deinit(self: Self) void {
        if (self.ast) |tree| {
            tree.deinit(self.allocator);
        }
        if (self.written) |written| {
            written.deinit();
        }
        if (self.locked) |locked| {
            locked.deinit(self.allocator);
        }
    }

    pub fn parse(self: Self, html: []const u8) !void {
        var tokens = try lexer.Tokenize(self.allocator, html);
        defer tokens.deinit();

        self.ast = try parser.Parse(self.allocator, tokens);
    }

    pub fn lock(self: Self) !void {
        if (self.ast) |tree| {
            const locked = try tree.lock(self.allocator);
            self.locked = locked.block;
        } else {
            @panic("called lock() withought an ast, call parse() first");
        }
    }

    pub fn write(self: Self, options: WriteOptions) ![]const u8 {
        if (self.locked) |locked| {
            var prevWasText = false;
            self.written = try writer.write(
                self.allocator,
                &ast.LockedStmt{ .block = locked },
                !options.minify,
                true,
                options.ignore_templates,
                &prevWasText,
            );
            return self.written.?.items;
        }
        try self.lock();
        return self.write(options);
    }

    pub fn getAst(self: Self) ast.BlockStmt {
        if (self.ast) |tree| {
            return tree;
        } else {
            @panic("called getAst() withought an ast, call parse() first");
        }
    }

    pub fn writeAst(self: Self, tree: ast.BlockStmt) void {
        self.ast = tree;
    }
};
