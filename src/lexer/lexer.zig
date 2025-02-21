const std = @import("std");
const log = std.log.scoped(.lexer);
const mvzr = @import("mvzr");
const tokens = @import("tokens.zig");
const Token = tokens.Token;
const TokenKind = tokens.TokenKind;

const RegexHandler = union(enum) {
    skip: SkipRegexHandler,
    default: DefaultRegexHandler,
    symbol: SymbolHandler,
    string: StringHandler,
    expect: ExpectHandler,

    pub fn handle(self: @This(), lex: *Lexer, regex: mvzr.Regex) !void {
        switch (self) {
            inline else => |h| try h.handle(lex, regex),
        }
    }
};

const OptionValueDataType = enum {
    boolean,
    number,
    string,
};

pub const OptionValue = union(OptionValueDataType) {
    boolean: bool,
    number: f32,
    string: []const u8,

    pub fn getType(self: @This()) OptionValueDataType {
        return switch (self) {
            .boolean => .boolean,
            .number => .number,
            .string => .string,
        };
    }

    pub fn getStringEq(self: @This()) ![]const u8 {
        return switch (self) {
            .string => |s| s,
            .boolean => |b| if (b) "true" else "false",
            .number => |n| {
                var buf: [32]u8 = undefined;
                return try std.fmt.bufPrint(&buf, "{d}", .{n});
            },
        };
    }
};

const RegexPattern = struct {
    regex: mvzr.Regex,
    handler: RegexHandler,
};

const Expect = enum {
    NONE,
    ELEMENT,
    OPTION,
    VALUE,
    TEMPLATE,
};

const ExpectSymbol = enum {
    AT,
    DOUBLE_DOLLAR,
};

const Lexer = struct {
    patterns: []const RegexPattern,
    tokens: std.ArrayList(Token),
    source: []const u8,
    pos: u32,
    inTag: bool,
    expect: Expect,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, source: []const u8, patterns: []const RegexPattern) Lexer {
        return .{
            .pos = 0,
            .source = source,
            .tokens = std.ArrayList(Token).init(allocator),
            .patterns = patterns,
            .inTag = false,
            .expect = .NONE,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Lexer) void {
        self.tokens.deinit();
    }

    pub fn advance(lex: *Lexer, n: u32) void {
        if (lex.pos + n > lex.source.len) {
            log.err("Advance would exceed bounds: pos = {d}, n = {d}, source.len = {d}", .{ lex.pos, n, lex.source.len });
            return;
        }
        lex.pos += n;
    }

    pub fn push(lex: *Lexer, token: Token) void {
        lex.tokens.append(token) catch |err| {
            log.err("Token push error: {any}", .{err});
        };
    }

    pub fn at(lex: *Lexer) u8 {
        return lex.source[lex.pos];
    }

    pub fn remainder(lex: *Lexer) []const u8 {
        if (lex.pos > lex.source.len) {
            log.err("Tried to access larger index than possible", .{});
            return "";
        }
        return lex.source[lex.pos..lex.source.len];
    }

    pub fn at_eof(lex: *Lexer) bool {
        return lex.pos >= lex.source.len;
    }
};

pub fn Tokenize(allocator: std.mem.Allocator, source: []const u8) !std.ArrayList(Token) {
    const patterns = [_]RegexPattern{
        // Skip doctype declaration as it is not needed
        .{ .regex = mvzr.compile("<!DOCTYPE html>").?, .handler = skipHandler() },
        .{ .regex = mvzr.compile("<!doctype html>").?, .handler = skipHandler() },

        .{ .regex = mvzr.compile("<!--.*?-->").?, .handler = skipHandler() },
        .{ .regex = mvzr.compile("\"[^\"]*\"").?, .handler = stringHandler() },
        .{ .regex = mvzr.compile("\\s+").?, .handler = skipHandler() },
        .{ .regex = mvzr.compile("@").?, .handler = expectHandler(.AT) },
        .{ .regex = mvzr.compile("\\$\\$").?, .handler = expectHandler(.DOUBLE_DOLLAR) },
        .{ .regex = mvzr.compile("=").?, .handler = defaultHandler(.EQUALS, "=") },
        .{ .regex = mvzr.compile("</").?, .handler = defaultHandler(.CLOSE_TAG, "</") },
        .{ .regex = mvzr.compile("/>").?, .handler = defaultHandler(.SELF_CLOSING_TAG, "/>") },
        .{ .regex = mvzr.compile("<").?, .handler = defaultHandler(.OPEN_TAG, "<") },
        .{ .regex = mvzr.compile(">").?, .handler = defaultHandler(.END_TAG, ">") },
        .{ .regex = mvzr.compile("\\{").?, .handler = defaultHandler(.OPEN_CURLY, "{") },
        .{ .regex = mvzr.compile("\\}").?, .handler = defaultHandler(.CLOSE_CURLY, "}") },
        .{ .regex = mvzr.compile("[a-zA-Z0-9$_-][a-zA-Z0-9$_\\-\\s]*").?, .handler = symbolHandler() },
    };

    var lex = Lexer.init(allocator, source, &patterns);

    while (!lex.at_eof()) {
        var matched = false;

        for (lex.patterns) |pattern| {
            const loc = pattern.regex.match(lex.remainder());

            if (loc == null) continue;

            if (loc.?.start == 0) {
                try pattern.handler.handle(&lex, pattern.regex);
                matched = true;
                break;
            }
        }

        if (!matched) {
            log.err("Unrecognized token at {d} near {s}", .{ lex.pos, lex.remainder() });
            break;
        }
    }

    lex.push(.{ .kind = .EOF, .value = "EOF", .metadata = null });
    return lex.tokens;
}

const DefaultRegexHandler = struct {
    kind: TokenKind,
    value: []const u8,

    pub fn handle(self: @This(), lex: *Lexer, regex: mvzr.Regex) !void {
        _ = regex;
        lex.advance(@intCast(self.value.len));
        lex.push(.{ .kind = self.kind, .value = self.value, .metadata = null });

        if (std.mem.eql(u8, self.value, "<")) {
            lex.inTag = true;
            lex.expect = .ELEMENT;
        } else if (std.mem.eql(u8, self.value, ">") or std.mem.eql(u8, self.value, "/>")) {
            lex.inTag = false;
        }
    }
};
fn defaultHandler(kind: TokenKind, value: []const u8) RegexHandler {
    return .{ .default = DefaultRegexHandler{ .kind = kind, .value = value } };
}

const SkipRegexHandler = struct {
    pub fn handle(self: @This(), lex: *Lexer, regex: mvzr.Regex) !void {
        _ = self;
        const match = regex.match(lex.remainder());
        lex.advance(@intCast(match.?.end));
    }
};
fn skipHandler() RegexHandler {
    return .{ .skip = SkipRegexHandler{} };
}

const ExpectHandler = struct {
    mode: ExpectSymbol,

    pub fn handle(self: @This(), lex: *Lexer, regex: mvzr.Regex) !void {
        const match = regex.match(lex.remainder());

        switch (self.mode) {
            .AT => lex.expect = .OPTION,
            .DOUBLE_DOLLAR => lex.expect = .TEMPLATE,
        }

        lex.advance(@as(u32, @intCast(match.?.end)));
    }
};
fn expectHandler(mode: ExpectSymbol) RegexHandler {
    return .{ .expect = ExpectHandler{ .mode = mode } };
}

fn createOptionValue(value: []const u8) !OptionValue {
    if (std.mem.eql(u8, value, "true")) {
        return .{ .boolean = true };
    }
    if (std.mem.eql(u8, value, "false")) {
        return .{ .boolean = false };
    }

    const number = try std.fmt.parseFloat(f32, value);
    return .{ .number = number };
}

const SymbolHandler = struct {
    pub fn handle(self: @This(), lex: *Lexer, regex: mvzr.Regex) !void {
        _ = self;
        const match = regex.match(lex.remainder());
        const expect = lex.expect;
        lex.expect = .NONE;

        var slice = match.?.slice;
        if (lex.inTag) {
            if (std.ascii.isWhitespace(slice[slice.len - 1])) {
                slice = slice[0 .. slice.len - 2];
            }
        }

        switch (expect) {
            .ELEMENT => lex.push(.{ .kind = .ELEMENT, .value = slice, .metadata = null }),
            .VALUE => lex.push(.{ .kind = .VALUE, .value = slice, .metadata = .{ .optionValue = try createOptionValue(slice) } }),
            .TEMPLATE => lex.push(.{ .kind = .TEMPLATE, .value = slice, .metadata = null }),
            .OPTION => {
                lex.push(.{ .kind = .OPTION, .value = slice, .metadata = null });
                lex.expect = .VALUE;
            },
            else => {
                if (lex.inTag) {
                    lex.push(.{ .kind = .ATTRIBUTE, .value = slice, .metadata = null });
                } else {
                    lex.push(.{ .kind = .TEXT, .value = slice, .metadata = null });
                }
            },
        }

        lex.advance(@as(u32, @intCast(match.?.end)));
    }
};
fn symbolHandler() RegexHandler {
    return .{ .symbol = SymbolHandler{} };
}

const StringHandler = struct {
    pub fn handle(self: @This(), lex: *Lexer, regex: mvzr.Regex) !void {
        _ = self;
        const match = regex.match(lex.remainder());
        const stringLiteral = lex.remainder()[match.?.start + 1 .. match.?.end - 1];

        if (lex.expect == .VALUE) {
            lex.push(.{ .kind = .VALUE, .value = stringLiteral, .metadata = .{ .optionValue = .{ .string = stringLiteral } } });
        } else {
            lex.push(.{ .kind = .STRING, .value = stringLiteral, .metadata = null });
        }

        lex.advance(@intCast(match.?.end));
    }
};
fn stringHandler() RegexHandler {
    return .{ .string = StringHandler{} };
}
