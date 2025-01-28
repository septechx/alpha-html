const std = @import("std");
const log = std.log.scoped(.lexer);

pub const TokenKind = enum {
    EOF,
    TEXT,
    STRING,
    TEMPLATE,
    OPEN_CURLY,
    CLOSE_CURLY,
    OPEN_TAG,
    CLOSE_TAG,
    END_TAG,
    EQUALS,

    // Used to create a fake token if the first element of the html is of type symbol
    fakeSTART,

    HTML,
    HEAD,
    TITLE,
    BASE,
    LINK,
    META,
    STYLE,
    SCRIPT,
    NOSCRIPT,
    BODY,
    SECTION,
    NAV,
    ARTICLE,
    ASIDE,
    H1,
    H2,
    H3,
    H4,
    H5,
    H6,
    HEADER,
    FOOTER,
    ADDRESS,
    MAIN,
    P,
    HR,
    PRE,
    BLOCKQUOTE,
    OL,
    UL,
    LI,
    DL,
    DT,
    DD,
    FIGURE,
    FIGCAPTION,
    DIV,
    A,
    EM,
    STRONG,
    SMALL,
    S,
    CITE,
    Q,
    DFN,
    ABBR,
    DATA,
    TIME,
    CODE,
    VAR,
    SAMP,
    KBD,
    SUB,
    SUP,
    I,
    B,
    U,
    MARK,
    RUBY,
    RT,
    RP,
    BDI,
    BDO,
    SPAN,
    BR,
    WBR,
    INS,
    DEL,
    PICTURE,
    SOURCE,
    IMG,
    IFRAME,
    EMBED,
    OBJECT,
    PARAM,
    VIDEO,
    AUDIO,
    TRACK,
    MAP,
    AREA,
    TABLE,
    CAPTION,
    COLGROUP,
    COL,
    TBODY,
    THEAD,
    TFOOT,
    TR,
    TD,
    TH,
    FORM,
    LABEL,
    INPUT,
    BUTTON,
    SELECT,
    DATALIST,
    OPTGROUP,
    OPTION,
    TEXTAREA,
    OUTPUT,
    PROGRESS,
    METER,
    FIELDSET,
    LEGEND,
    DETAILS,
    SUMMARY,
    DIALOG,
    SLOT,
    CANVAS,
    SVG,
    MATH,

    // Template is already defined so <template> is htmlTEMPLATE
    htmlTEMPLATE,
};

pub const Reserved = enum {
    html,
    head,
    title,
    base,
    link,
    meta,
    style,
    body,
    article,
    section,
    nav,
    aside,
    h1,
    h2,
    h3,
    h4,
    h5,
    h6,
    header,
    footer,
    address,
    p,
    hr,
    pre,
    blockquote,
    ol,
    ul,
    li,
    dl,
    dt,
    dd,
    figure,
    figcaption,
    div,
    main,
    a,
    em,
    strong,
    small,
    s,
    cite,
    q,
    dfn,
    abbr,
    data,
    time,
    code,
    samp,
    kbd,
    sub,
    sup,
    i,
    b,
    u,
    mark,
    ruby,
    rt,
    rp,
    bdi,
    bdo,
    span,
    br,
    wbr,
    ins,
    del,
    picture,
    source,
    img,
    iframe,
    embed,
    object,
    param,
    video,
    audio,
    track,
    map,
    area,
    table,
    caption,
    colgroup,
    col,
    tbody,
    thead,
    tfoot,
    tr,
    td,
    th,
    form,
    label,
    input,
    button,
    select,
    datalist,
    optgroup,
    option,
    textarea,
    output,
    progress,
    meter,
    fieldset,
    legend,
    details,
    summary,
    dialog,
    script,
    noscript,
    slot,
    canvas,
    svg,
    math,

    // To mantain consistency with TokenKind <template> is htmltemplate
    htmltemplate,

    pub fn toTokenKind(self: @This()) TokenKind {
        const tag_name = @tagName(self);
        var buf: [16]u8 = undefined;
        const upper = std.ascii.upperString(&buf, tag_name);
        return std.meta.stringToEnum(TokenKind, upper) orelse unreachable;
    }
};

pub const Token = struct {
    kind: TokenKind,
    value: []const u8,

    pub fn debug(token: @This()) void {
        if (token.isOneOfMany(&[_]TokenKind{
            .STRING,
            .TEXT,
            .TEMPLATE,
            // fakeSTART is here te log a warning if it is found in the token list while debuging
            .fakeSTART,
        })) {
            log.debug("{s} ({s})", .{ @tagName(token.kind), token.value });
        } else {
            log.debug("{s} ()", .{@tagName(token.kind)});
        }
    }

    pub fn isOneOfMany(token: @This(), tokens: []const TokenKind) bool {
        for (tokens) |kind| {
            if (token.kind == kind) {
                return true;
            }
        }
        return false;
    }
};
