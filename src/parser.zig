const std = @import("std");
const utils = @import("utils.zig");
const print = utils.print;

pub const e_ident = struct {
    magic: []const u8,
    class: u8,
    endianness: u8,
    elfver: u8,
    osabi: u8,
    abiver: u8,
    padding: []const u8,
};

pub const elf_file = struct {
    e_ident_part: e_ident,
};

pub fn invalid_file(msg: []const u8) void {
    print("\x1b[31mERROR:\x1b[0m Invalid binary. {s}.\n", .{msg});
    std.process.exit(1);
}

pub fn parse_e_ident(file: []const u8) !e_ident {
    const magic = file[0..4];
    const class = file[4];
    const endianness = file[5];
    const elfver = file[6];
    const osabi = file[7];
    const abiver = file[8];
    const padding = file[9..16];

    if (!std.mem.eql(u8, magic, &[_]u8{ 0x7f, 0x45, 0x4c, 0x46 })) {
        return error.InvalidMagic;
    }

    if (class != 1 and class != 2) {
        return error.InvalidClass;
    }

    if (endianness != 1 and endianness != 2) {
        return error.InvalidEndianness;
    }

    if (elfver != 1) {
        return error.InvalidElfVersion;
    }

    if (!std.mem.allEqual(u8, padding, 0)) {
        return error.InvalidPadding;
    }

    return e_ident{
        .magic = magic,
        .class = class,
        .endianness = endianness,
        .elfver = elfver,
        .osabi = osabi,
        .abiver = abiver,
        .padding = padding,
    };
}

pub fn parse_file(file: []const u8) !elf_file {
    if (file.len < 16) {
        return error.InvalidSize;
    }

    const e_ident_part = try parse_e_ident(file);

    return elf_file{ .e_ident_part = e_ident_part };
}

test "parse_file_test1" {
    const bytes = [_]u8{ 0x7f, 0x45, 0x4c, 0x46, 0x2, 0x1, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 };
    const output = parse_file(&bytes) catch unreachable;

    try std.testing.expectEqualDeep(output, elf_file{
        .e_ident_part = e_ident{ .magic = &[_]u8{ 0x7f, 0x45, 0x4c, 0x46 }, .class = 0x2, .endianness = 0x1, .elfver = 0x1, .osabi = 0x0, .abiver = 0x0, .padding = &[_]u8{0} ** 7 },
    });
}

test "parse_file_test2" {
    const bytes = [_]u8{};
    const output = parse_file(&bytes);

    try std.testing.expectError(error.InvalidSize, output);
}

test "parse_file_test3" {
    const bytes = [_]u8{ 0x8f, 0x45, 0x4c, 0x46, 0x2, 0x1, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 };
    const output = parse_file(&bytes);

    try std.testing.expectError(error.InvalidMagic, output);
}

test "parse_file_test4" {
    const bytes = [_]u8{ 0x7f, 0x45, 0x4c, 0x46, 0x3, 0x1, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 };
    const output = parse_file(&bytes);

    try std.testing.expectError(error.InvalidClass, output);
}

test "parse_file_test5" {
    const bytes = [_]u8{ 0x7f, 0x45, 0x4c, 0x46, 0x2, 0x3, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 };
    const output = parse_file(&bytes);

    try std.testing.expectError(error.InvalidEndianness, output);
}

test "parse_file_test6" {
    const bytes = [_]u8{ 0x7f, 0x45, 0x4c, 0x46, 0x2, 0x1, 0x2, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 };
    const output = parse_file(&bytes);

    try std.testing.expectError(error.InvalidElfVersion, output);
}

test "parse_file_test7" {
    const bytes = [_]u8{ 0x7f, 0x45, 0x4c, 0x46, 0x2, 0x1, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1 };
    const output = parse_file(&bytes);

    try std.testing.expectError(error.InvalidPadding, output);
}
