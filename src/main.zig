const std = @import("std");
const utils = @import("utils.zig");
const print = utils.print;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const f = try utils.readfile(alloc, "ls");
    defer alloc.free(f);

    print("{s}", .{f});
}
