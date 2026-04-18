const std = @import("std");
const utils = @import("utils.zig");
const parser = @import("parser.zig");
const cli = @import("cli.zig");
const print = utils.print;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    var args = std.process.args();
    _ = args.next();
    _ = try cli.parse_args(&args);

    const f = try utils.readfile(alloc, "ls");
    defer alloc.free(f);

    _ = parser.parse_file(alloc, f) catch |err| {
        switch (err) {
            error.InvalidSize => parser.invalid_file("ELF size is too small."),
            error.InvalidMagic => parser.invalid_file("File isn't ELF, invalid magic bytes"),
            error.InvalidClass => parser.invalid_file("ELF class is invalid."),
            error.InvalidEndianness => parser.invalid_file("ELF endianness is invalid."),
            error.InvalidElfVersion => parser.invalid_file("ELF version is invalid."),
            error.InvalidPadding => parser.invalid_file("ELF padding at header is invalid."),
            error.NoEndSection => parser.invalid_file("Section name doesn't have an end.."),
            error.OutOfMemory => {
                print("Out of memory\n", .{});
                std.process.exit(1);
            },
        }
    };
}
