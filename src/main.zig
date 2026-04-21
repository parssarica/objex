const std = @import("std");
const utils = @import("utils.zig");
const parser = @import("parser.zig");
const cli = @import("cli.zig");
const output = @import("output.zig");
const print = utils.print;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    var args = std.process.args();
    _ = args.next();
    const opts = cli.parse_args(&args) catch |err| {
        print("\x1b[31mERROR:\x1b[0m {s}\n", .{switch (err) {
            error.OptionUsedAsFile => "Option used as file.",
            error.InvalidOption => "Invalid option used.",
        }});
        output.help();
        std.process.exit(1);
    };

    if (opts.show_help) {
        output.help();
        std.process.exit(0);
    }

    if (!opts.show_sections and !opts.show_headers) {
        output.help();
        std.process.exit(1);
    }

    const path = if (opts.file) |path| path else {
        print("\x1b[31mERROR:\x1b[0m File isn't provided.\n", .{});
        std.process.exit(1);
    };

    const f = utils.readfile(alloc, path) catch |err| {
        if (err == error.IsDir) {
            print("\x1b[31mERROR:\x1b[0m Path is a directory rather than a file.\n", .{});
            std.process.exit(1);
        }

        return err;
    };
    defer alloc.free(f);

    var parsed = parser.parse_file(alloc, f) catch |err| {
        switch (err) {
            error.InvalidSize => parser.invalid_file("ELF size is too small."),
            error.InvalidMagic => parser.invalid_file("File isn't ELF, invalid magic bytes"),
            error.InvalidClass => parser.invalid_file("ELF class is invalid."),
            error.InvalidEndianness => parser.invalid_file("ELF endianness is invalid."),
            error.InvalidElfVersion => parser.invalid_file("ELF version is invalid."),
            error.InvalidPadding => parser.invalid_file("ELF padding at header is invalid."),
            error.NoEndSection => parser.invalid_file("Section name doesn't have an end."),
            error.NoStrtabSection => parser.invalid_file("File doesn't have a .strtab section, but it has a .symtab section."),
            error.NoEndSymbol => parser.invalid_file("Symbol name doesn't have an end."),
            error.NoDynstrSection => parser.invalid_file("File doesn't have a .dynstr section, but it has a .dynsym section."),
            error.OutOfMemory => print("Out of memory\n", .{}),
        }
        std.process.exit(1);
    };

    output.print_parsed(alloc, &opts, &parsed, output.color_table(opts.colors_on)) catch {
        print("Out of memory\n", .{});
        std.process.exit(1);
    };

    parsed.symbols.deinit(alloc);
    parsed.section_header.deinit(alloc);
}
