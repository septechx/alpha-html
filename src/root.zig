const std = @import("std");

pub const Html = struct {};

test {
    std.testing.refAllDecls(@This());
}
