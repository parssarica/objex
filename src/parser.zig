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

pub const elf_header = struct {
    e_type: u16,
    e_machine: u16,
    e_version: u32,
    e_entry: u64,
    e_phoff: u64,
    e_shoff: u64,
    e_flags: u32,
    e_ehsize: u16,
    e_phentsize: u16,
    e_phnum: u16,
    e_shentsize: u16,
    e_shnum: u16,
    e_shstrndx: u16,
};

pub const elf_file = struct {
    e_ident_part: e_ident,
    header: elf_header,
};

fn little16(bytes: []const u8) u16 {
    return std.mem.readInt(u16, bytes[0..2], .little);
}

fn little32(bytes: []const u8) u32 {
    return std.mem.readInt(u32, bytes[0..4], .little);
}

fn little64(bytes: []const u8) u64 {
    return std.mem.readInt(u64, bytes[0..8], .little);
}

fn big16(bytes: []const u8) u16 {
    return std.mem.readInt(u16, bytes[0..2], .big);
}

fn big32(bytes: []const u8) u32 {
    return std.mem.readInt(u32, bytes[0..4], .big);
}

fn big64(bytes: []const u8) u64 {
    return std.mem.readInt(u64, bytes[0..8], .big);
}

pub fn invalid_file(msg: []const u8) void {
    print("\x1b[31mERROR:\x1b[0m Invalid binary. {s}.\n", .{msg});
    std.process.exit(1);
}

pub fn parse_e_ident(file: []const u8) !e_ident {
    if (file.len < 16) {
        return error.InvalidSize;
    }

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

pub fn parse_header(file: []const u8, class: u8, endianness: u8) !elf_header {
    if ((class == 0x2 and file.len < 64) or (class == 0x1 and file.len < 52)) {
        return error.InvalidSize;
    }

    const e_type = if (endianness == 0x2) little16(file[16..18]) else big16(file[16..18]);
    const e_machine = if (endianness == 0x2) little16(file[18..20]) else big16(file[18..20]);
    const e_version = if (endianness == 0x2) little32(file[20..24]) else big32(file[20..24]);
    var e_entry: u64 = undefined;
    var e_phoff: u64 = undefined;
    var e_shoff: u64 = undefined;
    var e_flags: u32 = undefined;
    var e_ehsize: u16 = undefined;
    var e_phentsize: u16 = undefined;
    var e_phnum: u16 = undefined;
    var e_shentsize: u16 = undefined;
    var e_shnum: u16 = undefined;
    var e_shstrndx: u16 = undefined;
    if (class == 0x2) {
        e_entry = if (endianness == 0x2) little64(file[24..32]) else big64(file[24..32]);
        e_phoff = if (endianness == 0x2) little64(file[32..40]) else big64(file[32..40]);
        e_shoff = if (endianness == 0x2) little64(file[40..48]) else big64(file[40..48]);
        e_flags = if (endianness == 0x2) little32(file[48..52]) else big32(file[48..52]);
        e_ehsize = if (endianness == 0x2) little16(file[52..54]) else big16(file[52..54]);
        e_phentsize = if (endianness == 0x2) little16(file[54..56]) else big16(file[54..56]);
        e_phnum = if (endianness == 0x2) little16(file[56..58]) else big16(file[56..58]);
        e_shentsize = if (endianness == 0x2) little16(file[58..60]) else big16(file[58..60]);
        e_shnum = if (endianness == 0x2) little16(file[60..62]) else big16(file[60..62]);
        e_shstrndx = if (endianness == 0x2) little16(file[62..64]) else big16(file[62..64]);
    } else {
        e_entry = if (endianness == 0x2) little32(file[24..28]) else big32(file[24..28]);
        e_phoff = if (endianness == 0x2) little32(file[28..32]) else big32(file[28..32]);
        e_shoff = if (endianness == 0x2) little32(file[32..36]) else big32(file[32..36]);
        e_flags = if (endianness == 0x2) little32(file[36..40]) else big32(file[36..40]);
        e_ehsize = if (endianness == 0x2) little16(file[40..42]) else big16(file[40..42]);
        e_phentsize = if (endianness == 0x2) little16(file[42..44]) else big16(file[42..44]);
        e_phnum = if (endianness == 0x2) little16(file[44..46]) else big16(file[44..46]);
        e_shentsize = if (endianness == 0x2) little16(file[46..48]) else big16(file[46..48]);
        e_shnum = if (endianness == 0x2) little16(file[48..50]) else big16(file[48..50]);
        e_shstrndx = if (endianness == 0x2) little16(file[50..52]) else big16(file[50..52]);
    }

    return elf_header{
        .e_type = e_type,
        .e_machine = e_machine,
        .e_version = e_version,
        .e_entry = e_entry,
        .e_phoff = e_phoff,
        .e_shoff = e_shoff,
        .e_flags = e_flags,
        .e_ehsize = e_ehsize,
        .e_phentsize = e_phentsize,
        .e_phnum = e_phnum,
        .e_shentsize = e_shentsize,
        .e_shnum = e_shnum,
        .e_shstrndx = e_shstrndx,
    };
}

pub fn parse_file(file: []const u8) !elf_file {
    const e_ident_part = try parse_e_ident(file);
    const header = try parse_header(file);

    return elf_file{ .e_ident_part = e_ident_part, .header = header };
}

test "parse_e_ident_test1" {
    const bytes = [_]u8{ 0x7f, 0x45, 0x4c, 0x46, 0x2, 0x1, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 };
    const output = parse_e_ident(&bytes) catch unreachable;

    try std.testing.expectEqualDeep(
        output,
        e_ident{ .magic = &[_]u8{ 0x7f, 0x45, 0x4c, 0x46 }, .class = 0x2, .endianness = 0x1, .elfver = 0x1, .osabi = 0x0, .abiver = 0x0, .padding = &[_]u8{0} ** 7 },
    );
}

test "parse_e_ident_test2" {
    const bytes = [_]u8{};
    const output = parse_e_ident(&bytes);

    try std.testing.expectError(error.InvalidSize, output);
}

test "parse_e_ident_test3" {
    const bytes = [_]u8{ 0x8f, 0x45, 0x4c, 0x46, 0x2, 0x1, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 };
    const output = parse_e_ident(&bytes);

    try std.testing.expectError(error.InvalidMagic, output);
}

test "parse_e_ident_test4" {
    const bytes = [_]u8{ 0x7f, 0x45, 0x4c, 0x46, 0x3, 0x1, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 };
    const output = parse_e_ident(&bytes);

    try std.testing.expectError(error.InvalidClass, output);
}

test "parse_e_ident_test5" {
    const bytes = [_]u8{ 0x7f, 0x45, 0x4c, 0x46, 0x2, 0x3, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 };
    const output = parse_e_ident(&bytes);

    try std.testing.expectError(error.InvalidEndianness, output);
}

test "parse_e_ident_test6" {
    const bytes = [_]u8{ 0x7f, 0x45, 0x4c, 0x46, 0x2, 0x1, 0x2, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 };
    const output = parse_e_ident(&bytes);

    try std.testing.expectError(error.InvalidElfVersion, output);
}

test "parse_e_ident_test7" {
    const bytes = [_]u8{ 0x7f, 0x45, 0x4c, 0x46, 0x2, 0x1, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x1 };
    const output = parse_e_ident(&bytes);

    try std.testing.expectError(error.InvalidPadding, output);
}

test "parse_header_test1" {
    const bytes = [_]u8{ 0x7f, 0x45, 0x4c, 0x46, 0x2, 0x1, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 3, 0, 0x3e, 0, 1, 0, 0, 0, 0xf0, 0x37, 0, 0, 0, 0, 0, 0, 0x40, 0, 0, 0, 0, 0, 0, 0, 0x60, 0x2f, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x40, 0, 0x38, 0, 0xd, 0, 0x40, 0, 0x21, 0, 0x20, 0 };
    const output = try parse_header(&bytes, 0x2, 0x2);

    try std.testing.expectEqualDeep(elf_header{
        .e_type = 3,
        .e_machine = 0x3e,
        .e_version = 1,
        .e_entry = 0x37f0,
        .e_phoff = 0x40,
        .e_shoff = 0x22f60,
        .e_flags = 0,
        .e_ehsize = 0x40,
        .e_phentsize = 0x38,
        .e_phnum = 0xd,
        .e_shentsize = 0x40,
        .e_shnum = 0x21,
        .e_shstrndx = 0x20,
    }, output);
}

test "parse_header_test2" {
    const bytes = [_]u8{};
    const output = try parse_header(&bytes, 0x2, 0x2);

    try std.testing.expectError(error.InvalidSize, output);
}
