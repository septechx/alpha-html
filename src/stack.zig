const std = @import("std");
const log = std.log.scoped(.stack);

pub const StackError = error{ UnderflowError, OverflowError };

pub fn Stack(comptime T: type, comptime size: usize) type {
    return struct {
        maxsize: usize,
        top: u32,
        items: [size]?T,

        pub fn init() @This() {
            return .{
                .items = [_]?T{null} ** size,
                .maxsize = size,
                .top = 0,
            };
        }

        pub fn push(stk: *@This(), item: T) StackError!void {
            if (stk.top == stk.maxsize) {
                return StackError.OverflowError;
            } else {
                stk.items[stk.top] = item;
                stk.top += 1;
            }
        }

        pub fn pop(stk: *@This()) StackError!T {
            if (stk.top == 0) {
                return StackError.UnderflowError;
            } else {
                stk.top -= 1;
                return stk.items[stk.top].?;
            }
        }

        pub fn peek(stk: *@This()) T {
            return stk.items[stk.top - 1].?;
        }

        pub fn debug(stk: *@This()) void {
            log.debug("Maxsize: {d}", .{stk.maxsize});
            log.debug("Top: {d}", .{stk.top});
            log.debug("Items: {any}", .{stk.items});
        }
    };
}
