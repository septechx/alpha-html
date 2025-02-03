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

    pub fn handle(self: @This(), lex: *Lexer, regex: mvzr.Regex) void {
        switch (self) {
            inline else => |h| h.handle(lex, regex),
        }
    }
};

const RegexPattern = struct {
    regex: mvzr.Regex,
    handler: RegexHandler,
};

const Lexer = struct {
    patterns: []const RegexPattern,
    tokens: std.ArrayList(Token),
    source: []const u8,
    pos: u32,
    inTag: bool,
    expectElement: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, source: []const u8, patterns: []const RegexPattern) Lexer {
        return .{
            .pos = 0,
            .source = source,
            .tokens = std.ArrayList(Token).init(allocator),
            .patterns = patterns,
            .inTag = false,
            .expectElement = false,
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
        .{ .regex = mvzr.compile("<!DOCTYPE html>").?, .handler = skipHandler() }, // Skip doctype declaration as it is not needed
        .{ .regex = mvzr.compile("<!--.*?-->").?, .handler = skipHandler() },
        .{ .regex = mvzr.compile("\"[^\"]*\"").?, .handler = stringHandler() },
        .{ .regex = mvzr.compile("\\s+").?, .handler = skipHandler() },
        .{ .regex = mvzr.compile("=").?, .handler = defaultHandler(.EQUALS, "=") },
        .{ .regex = mvzr.compile("</").?, .handler = defaultHandler(.CLOSE_TAG, "</") },
        .{ .regex = mvzr.compile("<").?, .handler = defaultHandler(.OPEN_TAG, "<") },
        .{ .regex = mvzr.compile(">").?, .handler = defaultHandler(.END_TAG, ">") },
        .{ .regex = mvzr.compile("\\{").?, .handler = defaultHandler(.OPEN_CURLY, "{") },
        .{ .regex = mvzr.compile("\\}").?, .handler = defaultHandler(.CLOSE_CURLY, "}") },
        .{ .regex = mvzr.compile("[a-zA-Z0-9$_-][a-zA-Z0-9$_-]*").?, .handler = symbolHandler() },
    };

    var lex = Lexer.init(allocator, source, &patterns);

    while (!lex.at_eof()) {
        var matched = false;

        for (lex.patterns) |pattern| {
            const loc = pattern.regex.match(lex.remainder());

            if (loc == null) continue;

            if (loc.?.start == 0) {
                pattern.handler.handle(&lex, pattern.regex);
                matched = true;
                break;
            }
        }

        if (!matched) {
            log.err("Unrecognized token at {d} near {s}", .{ lex.pos, lex.remainder() });
            break;
        }
    }

    lex.push(Token{ .kind = .EOF, .value = "EOF" });
    return lex.tokens;
}

const DefaultRegexHandler = struct {
    kind: TokenKind,
    value: []const u8,

    pub fn handle(self: @This(), lex: *Lexer, regex: mvzr.Regex) void {
        _ = regex;
        lex.advance(@intCast(self.value.len));
        lex.push(Token{ .kind = self.kind, .value = self.value });

        if (std.mem.eql(u8, self.value, "<")) {
            lex.inTag = true;
            lex.expectElement = true;
        } else if (std.mem.eql(u8, self.value, ">")) {
            lex.inTag = false;
        }
    }
};
fn defaultHandler(kind: TokenKind, value: []const u8) RegexHandler {
    return .{ .default = DefaultRegexHandler{ .kind = kind, .value = value } };
}

const SkipRegexHandler = struct {
    pub fn handle(self: @This(), lex: *Lexer, regex: mvzr.Regex) void {
        _ = self;
        const match = regex.match(lex.remainder());
        lex.advance(@intCast(match.?.end));
    }
};
fn skipHandler() RegexHandler {
    return .{ .skip = SkipRegexHandler{} };
}

const SymbolHandler = struct {
    pub fn handle(self: @This(), lex: *Lexer, regex: mvzr.Regex) void {
        _ = self;
        const match = regex.match(lex.remainder());

        if (lex.inTag) {
            const expectElement = lex.expectElement;
            lex.expectElement = false;

            lex.push(Token{ .kind = if (expectElement) .ELEMENT else .ATTRIBUTE, .value = match.?.slice });
        } else {
            if (std.mem.startsWith(u8, match.?.slice, "$$")) {
                lex.push(Token{ .kind = .TEMPLATE, .value = match.?.slice[2..] });
            } else {
                lex.push(Token{ .kind = .TEXT, .value = match.?.slice });
            }
        }

        lex.advance(@intCast(match.?.end));
    }
};
fn symbolHandler() RegexHandler {
    return .{ .symbol = SymbolHandler{} };
}

const StringHandler = struct {
    pub fn handle(self: @This(), lex: *Lexer, regex: mvzr.Regex) void {
        _ = self;
        const match = regex.match(lex.remainder());
        const stringLiteral = lex.remainder()[match.?.start + 1 .. match.?.end - 1];

        lex.advance(@intCast(match.?.end));
        lex.push(Token{ .kind = .STRING, .value = stringLiteral });
    }
};
fn stringHandler() RegexHandler {
    return .{ .string = StringHandler{} };
}
