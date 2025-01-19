const std = @import("std");
const log = std.log.scoped(.lexer);
const mvzr = @import("mvzr");
const tokens = @import("tokens.zig");
const Token = tokens.Token;
const TokenKind = tokens.TokenKind;

const RegexHandler = union(enum) {
    skip: SkipRegexHandler,
    default: DefaultRegexHandler,

    pub fn handle(self: @This(), lex: *Lexer, regex: mvzr.Regex) void {
        switch (self) {
            .skip => |h| h.handle(lex, regex),
            .default => |h| h.handle(lex, regex),
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
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, source: []const u8, patterns: []const RegexPattern) Lexer {
        return .{
            .pos = 0,
            .source = source,
            .tokens = std.ArrayList(Token).init(allocator),
            .patterns = patterns,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Lexer) void {
        self.tokens.deinit();
    }

    pub fn advance(lex: *Lexer, n: u32) void {
        if (lex.pos + n > lex.source.len) {
            log.err("Advance would exceed bounds: pos = {d}, n = {d}, source.len = {d}\n", .{ lex.pos, n, lex.source.len });
            return;
        }
        lex.pos += n;
    }

    pub fn push(lex: *Lexer, token: Token) void {
        lex.tokens.append(token) catch |err| {
            log.err("Token push error: {any}\n", .{err});
        };
    }

    pub fn at(lex: *Lexer) u8 {
        return lex.source[lex.pos];
    }

    pub fn remainder(lex: *Lexer) []const u8 {
        if (lex.pos > lex.source.len) {
            log.err("Tried to access larger index than possible\n", .{});
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
        .{ .regex = mvzr.compile("\\s+").?, .handler = skipHandler() },
        .{ .regex = mvzr.compile("<div>").?, .handler = defaultHandler(.OPEN_DIV, "<div>") },
        .{ .regex = mvzr.compile("<h1>").?, .handler = defaultHandler(.OPEN_H1, "<h1>") },
        .{ .regex = mvzr.compile("<h2>").?, .handler = defaultHandler(.OPEN_H2, "<h2>") },
        .{ .regex = mvzr.compile("</div>").?, .handler = defaultHandler(.CLOSE_DIV, "</div>") },
        .{ .regex = mvzr.compile("</h1>").?, .handler = defaultHandler(.CLOSE_H1, "</h1>") },
        .{ .regex = mvzr.compile("</h2>").?, .handler = defaultHandler(.CLOSE_H2, "</h2>") },
        .{ .regex = mvzr.compile("\\{").?, .handler = defaultHandler(.OPEN_CURLY, "{") },
        .{ .regex = mvzr.compile("\\}").?, .handler = defaultHandler(.CLOSE_CURLY, "}") },
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
            log.err("Unrecognized token at {d} near {s}\n", .{ lex.pos, lex.remainder() });
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
