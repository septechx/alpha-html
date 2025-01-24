const std = @import("std");
const testing = std.testing;

pub const Html = struct {};

test {
    std.testing.refAllDecls(@This());
}
