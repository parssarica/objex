const std = @import("std");
const print = @import("utils.zig").print;

pub fn main() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();
    _ = alloc;

    print("Objex\n", .{});
}
