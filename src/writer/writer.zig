const std = @import("std");
const ast = @import("../ast/ast.zig");

const InvalidTree = error{InvalidTree};

pub fn write(allocator: std.mem.Allocator, tree: *const ast.LockedStmt, split: bool, first: bool) !std.ArrayList(u8) {
    var out = std.ArrayList(u8).init(allocator);

    if (first) {
        try out.appendSlice("<!DOCTYPE html>");

        if (split) {
            try out.append('\n');
        }

        const innerHtml = try write(allocator, &tree.block.body[0], split, false);
        defer innerHtml.deinit();
        try out.appendSlice(innerHtml.items);

        return out;
    }

    if (tree.* == .block) {
        const startTag = try writeEl(allocator, &tree.block, false, split);
        defer startTag.deinit();
        const endTag = try writeEl(allocator, &tree.block, true, split);
        defer endTag.deinit();

        try out.appendSlice(startTag.items);
        for (tree.block.body) |b| {
            const innerHtml = try write(allocator, &b, split, false);
            defer innerHtml.deinit();
            try out.appendSlice(innerHtml.items);
        }
        try out.appendSlice(endTag.items);
    } else {
        if (tree.expression.expression == .text) {
            try out.appendSlice(tree.expression.expression.text.value);

            if (split) {
                try out.append('\n');
            }
        } else {
            @panic("Found template while writing, templates should be replaced before calling write()");
        }
    }

    return out;
}

fn writeEl(allocator: std.mem.Allocator, block: *const ast.LockedBlockStmt, close: bool, split: bool) !std.ArrayList(u8) {
    var out = std.ArrayList(u8).init(allocator);

    const attrs = try writeAttr(allocator, &block.attributes);
    defer attrs.deinit();

    try out.writer().print("<{s}{s}{s}>{s}", .{
        if (close) "/" else "",
        block.element,
        if (close) "" else attrs.items,
        if (split) "\n" else "",
    });

    return out;
}

fn writeAttr(allocator: std.mem.Allocator, attrs: *const []ast.Attr) !std.ArrayList(u8) {
    var out = std.ArrayList(u8).init(allocator);

    for (attrs.*) |attr| {
        try out.writer().print(" {s}=\"{s}\"", .{
            attr.key,
            attr.value,
        });
    }

    return out;
}
