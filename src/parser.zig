const std = @import("std");
const utils = @import("utils.zig");
const print = utils.print;
const ArrayList = std.ArrayList;

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

pub const elf_section = struct {
    name: ?[]const u8,
    data: ?[]const u8,
    sh_name: u32,
    sh_type: u32,
    sh_flags: u64,
    sh_addr: u64,
    sh_offset: u64,
    sh_size: u64,
    sh_link: u32,
    sh_info: u32,
    sh_addralign: u64,
    sh_entsize: u64,
};

pub const elf_sym = struct {
    name: ?[]const u8,
    st_name: u32,
    st_info: u8,
    st_other: u8,
    st_shndx: u16,
    st_value: u64,
    st_size: u64,
};

pub const elf_file = struct {
    e_ident_part: e_ident,
    header: elf_header,
    section_header: ArrayList(elf_section),
    symbols: ArrayList(elf_sym),
};

fn little8(bytes: []const u8) u8 {
    return std.mem.readInt(u8, bytes[0..1], .little);
}

fn little16(bytes: []const u8) u16 {
    return std.mem.readInt(u16, bytes[0..2], .little);
}

fn little32(bytes: []const u8) u32 {
    return std.mem.readInt(u32, bytes[0..4], .little);
}

fn little64(bytes: []const u8) u64 {
    return std.mem.readInt(u64, bytes[0..8], .little);
}

fn big8(bytes: []const u8) u8 {
    return std.mem.readInt(u8, bytes[0..1], .big);
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

    const e_type = if (endianness == 0x1) little16(file[16..18]) else big16(file[16..18]);
    const e_machine = if (endianness == 0x1) little16(file[18..20]) else big16(file[18..20]);
    const e_version = if (endianness == 0x1) little32(file[20..24]) else big32(file[20..24]);
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
        e_entry = if (endianness == 0x1) little64(file[24..32]) else big64(file[24..32]);
        e_phoff = if (endianness == 0x1) little64(file[32..40]) else big64(file[32..40]);
        e_shoff = if (endianness == 0x1) little64(file[40..48]) else big64(file[40..48]);
        e_flags = if (endianness == 0x1) little32(file[48..52]) else big32(file[48..52]);
        e_ehsize = if (endianness == 0x1) little16(file[52..54]) else big16(file[52..54]);
        e_phentsize = if (endianness == 0x1) little16(file[54..56]) else big16(file[54..56]);
        e_phnum = if (endianness == 0x1) little16(file[56..58]) else big16(file[56..58]);
        e_shentsize = if (endianness == 0x1) little16(file[58..60]) else big16(file[58..60]);
        e_shnum = if (endianness == 0x1) little16(file[60..62]) else big16(file[60..62]);
        e_shstrndx = if (endianness == 0x1) little16(file[62..64]) else big16(file[62..64]);
    } else {
        e_entry = if (endianness == 0x1) little32(file[24..28]) else big32(file[24..28]);
        e_phoff = if (endianness == 0x1) little32(file[28..32]) else big32(file[28..32]);
        e_shoff = if (endianness == 0x1) little32(file[32..36]) else big32(file[32..36]);
        e_flags = if (endianness == 0x1) little32(file[36..40]) else big32(file[36..40]);
        e_ehsize = if (endianness == 0x1) little16(file[40..42]) else big16(file[40..42]);
        e_phentsize = if (endianness == 0x1) little16(file[42..44]) else big16(file[42..44]);
        e_phnum = if (endianness == 0x1) little16(file[44..46]) else big16(file[44..46]);
        e_shentsize = if (endianness == 0x1) little16(file[46..48]) else big16(file[46..48]);
        e_shnum = if (endianness == 0x1) little16(file[48..50]) else big16(file[48..50]);
        e_shstrndx = if (endianness == 0x1) little16(file[50..52]) else big16(file[50..52]);
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

pub fn parse_section(file: []const u8, endianness: u8, class: u8, sect_name_addr: u64, sect_addr: u64) !elf_section {
    const sh_name = if (endianness == 0x1) little32(file[sect_addr .. sect_addr + 4]) else big32(file[sect_addr .. sect_addr + 4]);
    const sh_type = if (endianness == 0x1) little32(file[sect_addr + 4 .. sect_addr + 8]) else big32(file[sect_addr + 4 .. sect_addr + 8]);
    var sh_flags: u64 = undefined;
    var sh_addr: u64 = undefined;
    var sh_offset: u64 = undefined;
    var sh_size: u64 = undefined;
    var sh_link: u32 = undefined;
    var sh_info: u32 = undefined;
    var sh_addralign: u32 = undefined;
    var sh_entsize: u32 = undefined;
    var name: ?[]const u8 = null;
    var data: ?[]const u8 = null;
    if (class == 0x2) {
        sh_flags = if (endianness == 0x1) little64(file[sect_addr + 8 .. sect_addr + 16]) else big64(file[sect_addr + 8 .. sect_addr + 16]);
        sh_addr = if (endianness == 0x1) little64(file[sect_addr + 16 .. sect_addr + 24]) else big64(file[sect_addr + 16 .. sect_addr + 24]);
        sh_offset = if (endianness == 0x1) little64(file[sect_addr + 24 .. sect_addr + 32]) else big64(file[sect_addr + 24 .. sect_addr + 32]);
        sh_size = if (endianness == 0x1) little32(file[sect_addr + 32 .. sect_addr + 40]) else big32(file[sect_addr + 32 .. sect_addr + 40]);
        sh_link = if (endianness == 0x1) little32(file[sect_addr + 40 .. sect_addr + 44]) else big32(file[sect_addr + 40 .. sect_addr + 44]);
        sh_info = if (endianness == 0x1) little32(file[sect_addr + 44 .. sect_addr + 48]) else big32(file[sect_addr + 44 .. sect_addr + 48]);
        sh_addralign = if (endianness == 0x1) little32(file[sect_addr + 48 .. sect_addr + 56]) else big32(file[sect_addr + 48 .. sect_addr + 56]);
        sh_entsize = if (endianness == 0x1) little32(file[sect_addr + 56 .. sect_addr + 64]) else big32(file[sect_addr + 56 .. sect_addr + 64]);
    } else {
        sh_flags = if (endianness == 0x1) little32(file[sect_addr + 8 .. sect_addr + 12]) else big32(file[sect_addr + 8 .. sect_addr + 12]);
        sh_addr = if (endianness == 0x1) little32(file[sect_addr + 12 .. sect_addr + 16]) else big32(file[sect_addr + 12 .. sect_addr + 16]);
        sh_offset = if (endianness == 0x1) little32(file[sect_addr + 16 .. sect_addr + 20]) else big32(file[sect_addr + 16 .. sect_addr + 20]);
        sh_size = if (endianness == 0x1) little32(file[sect_addr + 20 .. sect_addr + 24]) else big32(file[sect_addr + 20 .. sect_addr + 24]);
        sh_link = if (endianness == 0x1) little32(file[sect_addr + 24 .. sect_addr + 28]) else big32(file[sect_addr + 24 .. sect_addr + 28]);
        sh_info = if (endianness == 0x1) little32(file[sect_addr + 28 .. sect_addr + 32]) else big32(file[sect_addr + 28 .. sect_addr + 32]);
        sh_addralign = if (endianness == 0x1) little32(file[sect_addr + 32 .. sect_addr + 36]) else big32(file[sect_addr + 32 .. sect_addr + 36]);
        sh_entsize = if (endianness == 0x1) little32(file[sect_addr + 36 .. sect_addr + 40]) else big32(file[sect_addr + 36 .. sect_addr + 40]);
    }

    if (sh_name != 0) {
        const offset = sect_name_addr + sh_name;
        name = file[offset .. offset + (std.mem.indexOfScalar(u8, file[offset..], 0) orelse return error.NoEndSection)];
    }

    if (sh_type != 8) {
        if (sh_offset + sh_size > file.len) {
            return error.InvalidSize;
        }
        data = file[sh_offset .. sh_offset + sh_size];
    }

    return elf_section{
        .name = name,
        .data = data,
        .sh_name = sh_name,
        .sh_type = sh_type,
        .sh_flags = sh_flags,
        .sh_addr = sh_addr,
        .sh_offset = sh_offset,
        .sh_size = sh_size,
        .sh_link = sh_link,
        .sh_info = sh_info,
        .sh_addralign = sh_addralign,
        .sh_entsize = sh_entsize,
    };
}

pub fn parse_section_header(allocator: std.mem.Allocator, file: []const u8, ident: e_ident, header: elf_header) !std.ArrayList(elf_section) {
    if (header.e_shoff + @as(u64, header.e_shnum) * @as(u64, header.e_shentsize) > file.len + 1) {
        return error.InvalidSize;
    }

    var list: ArrayList(elf_section) = .empty;
    var sect_name_addr: u64 = header.e_shoff + header.e_shentsize * header.e_shstrndx;
    if (ident.class == 0x2) {
        if (ident.endianness == 0x1) {
            sect_name_addr = little64(file[sect_name_addr + 0x18 ..]);
        } else {
            sect_name_addr = big64(file[sect_name_addr + 0x18 ..]);
        }
    } else {
        if (ident.endianness == 0x1) {
            sect_name_addr = little64(file[sect_name_addr + 0x10 ..]);
        } else {
            sect_name_addr = big64(file[sect_name_addr + 0x10 ..]);
        }
    }

    for (0..header.e_shnum) |i| {
        try list.append(allocator, try parse_section(file, ident.endianness, ident.class, sect_name_addr, header.e_shoff + i * header.e_shentsize));
    }

    return list;
}

pub fn parse_symbols(allocator: std.mem.Allocator, file: []const u8, sections: []const elf_section, ident: e_ident) !ArrayList(elf_sym) {
    var list: ArrayList(elf_sym) = .empty;
    var strtab_off: ?u64 = null;
    var dynstr_off: ?u64 = null;

    for (sections) |sect| {
        if (std.mem.eql(u8, sect.name orelse continue, ".strtab")) {
            strtab_off = sect.sh_offset;
        } else if (std.mem.eql(u8, sect.name orelse continue, ".dynstr")) {
            dynstr_off = sect.sh_offset;
        }
    }

    for (sections) |sect| {
        if (std.mem.eql(u8, sect.name orelse continue, ".symtab") or std.mem.eql(u8, sect.name orelse continue, ".dynsym")) {
            var addr = sect.sh_offset;
            var symsize: u8 = undefined;
            while (addr < sect.sh_offset + sect.sh_size) : (addr += symsize) {
                var st_name: u32 = undefined;
                var st_info: u8 = undefined;
                var st_other: u8 = undefined;
                var st_shndx: u16 = undefined;
                var st_value: u64 = undefined;
                var st_size: u64 = undefined;
                var name: ?[]const u8 = null;
                if (ident.class == 0x2) {
                    symsize = 24;
                    if (addr + symsize > file.len) {
                        return error.InvalidSize;
                    }
                    st_name = if (ident.endianness == 0x1) little32(file[addr .. addr + 4]) else big32(file[addr .. addr + 4]);
                    st_info = if (ident.endianness == 0x1) little8(file[addr + 4 .. addr + 5]) else big8(file[addr + 4 .. addr + 5]);
                    st_other = if (ident.endianness == 0x1) little8(file[addr + 5 .. addr + 6]) else big8(file[addr + 5 .. addr + 6]);
                    st_shndx = if (ident.endianness == 0x1) little16(file[addr + 6 .. addr + 8]) else big16(file[addr + 6 .. addr + 10]);
                    st_value = if (ident.endianness == 0x1) little64(file[addr + 8 .. addr + 16]) else big64(file[addr + 8 .. addr + 16]);
                    st_size = if (ident.endianness == 0x1) little64(file[addr + 16 .. addr + 24]) else big64(file[addr + 16 .. addr + 24]);
                } else {
                    symsize = 16;
                    if (addr + symsize > file.len) {
                        return error.InvalidSize;
                    }
                    st_name = if (ident.endianness == 0x1) little32(file[addr .. addr + 4]) else big32(file[addr .. addr + 4]);
                    st_value = if (ident.endianness == 0x1) little32(file[addr + 4 .. addr + 8]) else big32(file[addr + 4 .. addr + 8]);
                    st_size = if (ident.endianness == 0x1) little32(file[addr + 8 .. addr + 12]) else big32(file[addr + 8 .. addr + 12]);
                    st_info = if (ident.endianness == 0x1) little8(file[addr + 12 .. addr + 13]) else big8(file[addr + 12 .. addr + 13]);
                    st_other = if (ident.endianness == 0x1) little8(file[addr + 13 .. addr + 14]) else big8(file[addr + 13 .. addr + 14]);
                    st_shndx = if (ident.endianness == 0x1) little16(file[addr + 14 .. addr + 16]) else big16(file[addr + 14 .. addr + 16]);
                }

                if (st_name != 0) {
                    if (std.mem.eql(u8, sect.name orelse continue, ".symtab")) {
                        const offset = (strtab_off orelse return error.NoStrtabSection);
                        name = file[offset + st_name .. offset + st_name + (std.mem.indexOfScalar(u8, file[offset + st_name ..], 0) orelse return error.NoEndSymbol)];
                    } else {
                        const offset = (dynstr_off orelse return error.NoDynstrSection);
                        name = file[offset + st_name .. offset + st_name + (std.mem.indexOfScalar(u8, file[offset + st_name ..], 0) orelse return error.NoEndSymbol)];
                    }
                }

                try list.append(allocator, elf_sym{
                    .name = name,
                    .st_name = st_name,
                    .st_info = st_info,
                    .st_other = st_other,
                    .st_shndx = st_shndx,
                    .st_value = st_value,
                    .st_size = st_size,
                });
            }
        }
    }

    return list;
}

pub fn parse_file(allocator: std.mem.Allocator, file: []const u8) !elf_file {
    const e_ident_part = try parse_e_ident(file);
    const header = try parse_header(file, e_ident_part.class, e_ident_part.endianness);
    const section_header = try parse_section_header(allocator, file, e_ident_part, header);
    const symbols = try parse_symbols(allocator, file, section_header.items, e_ident_part);

    return elf_file{ .e_ident_part = e_ident_part, .header = header, .section_header = section_header, .symbols = symbols };
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
    const output = try parse_header(&bytes, 0x2, 0x1);

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
    const output = parse_header(&bytes, 0x2, 0x1);

    try std.testing.expectError(error.InvalidSize, output);
}

test "parse_section_test1" {
    const bytes = [_]u8{ 0x0B, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2E, 0x61, 0x62, 0x63, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    var output = try parse_section_header(std.testing.allocator, &bytes, e_ident{
        .magic = &[_]u8{},
        .class = 0x2,
        .endianness = 0x1,
        .elfver = 0,
        .osabi = 0,
        .abiver = 0,
        .padding = &[_]u8{},
    }, elf_header{
        .e_type = 0,
        .e_machine = 0,
        .e_version = 0,
        .e_entry = 0,
        .e_phoff = 0,
        .e_shoff = 0,
        .e_flags = 0,
        .e_ehsize = 0,
        .e_phentsize = 0,
        .e_phnum = 0,
        .e_shentsize = 64,
        .e_shnum = 1,
        .e_shstrndx = 0,
    });

    defer output.deinit(std.testing.allocator);

    try std.testing.expectEqualDeep(
        output.items[0],
        elf_section{ .name = ".abc", .data = bytes[0x318..0x33c], .sh_name = 0xb, .sh_type = 0x7, .sh_flags = 0x2, .sh_addr = 0x318, .sh_offset = 0x318, .sh_size = 0x24, .sh_link = 0x0, .sh_info = 0x0, .sh_addralign = 0x4, .sh_entsize = 0x0 },
    );
}

test "parse_symbols_test1" {
    const bytes = [_]u8{ 0x04, 0x00, 0x00, 0x00, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    var output = try parse_symbols(std.testing.allocator, &bytes, &[_]elf_section{ elf_section{
        .name = ".dynsym",
        .data = bytes[0..],
        .sh_name = 0,
        .sh_type = 0,
        .sh_flags = 0,
        .sh_addr = 0,
        .sh_offset = 0,
        .sh_size = bytes.len,
        .sh_link = 0,
        .sh_info = 0,
        .sh_addralign = 0,
        .sh_entsize = 0,
    }, elf_section{
        .name = ".dynstr",
        .data = bytes[0..],
        .sh_name = 0,
        .sh_type = 0,
        .sh_flags = 0,
        .sh_addr = 0,
        .sh_offset = 0,
        .sh_size = bytes.len,
        .sh_link = 0,
        .sh_info = 0,
        .sh_addralign = 0,
        .sh_entsize = 0,
    } }, e_ident{
        .magic = &[_]u8{},
        .class = 2,
        .endianness = 1,
        .elfver = 0,
        .osabi = 0,
        .abiver = 0,
        .padding = &[_]u8{},
    });

    defer output.deinit(std.testing.allocator);

    try std.testing.expectEqualDeep(
        output.items[0],
        elf_sym{ .name = bytes[4..5], .st_name = 0x04, .st_info = 0x12, .st_other = 0x00, .st_shndx = 0x00, .st_value = 0x00, .st_size = 0x00 },
    );
}

test "parse_symbols_test2" {
    const bytes = [_]u8{ 0x04, 0x00, 0x00, 0x00, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    var output = try parse_symbols(std.testing.allocator, &bytes, &[_]elf_section{ elf_section{
        .name = ".dynsym",
        .data = bytes[0..],
        .sh_name = 0,
        .sh_type = 0,
        .sh_flags = 0,
        .sh_addr = 0,
        .sh_offset = 0,
        .sh_size = bytes.len,
        .sh_link = 0,
        .sh_info = 0,
        .sh_addralign = 0,
        .sh_entsize = 0,
    }, elf_section{
        .name = ".dynstr",
        .data = bytes[0..],
        .sh_name = 0,
        .sh_type = 0,
        .sh_flags = 0,
        .sh_addr = 0,
        .sh_offset = 0,
        .sh_size = bytes.len,
        .sh_link = 0,
        .sh_info = 0,
        .sh_addralign = 0,
        .sh_entsize = 0,
    } }, e_ident{
        .magic = &[_]u8{},
        .class = 1,
        .endianness = 1,
        .elfver = 0,
        .osabi = 0,
        .abiver = 0,
        .padding = &[_]u8{},
    });

    defer output.deinit(std.testing.allocator);

    try std.testing.expectEqualDeep(
        output.items[0],
        elf_sym{ .name = bytes[4..5], .st_name = 0x04, .st_info = 0x0, .st_other = 0x00, .st_shndx = 0x00, .st_value = 0x12, .st_size = 0x00 },
    );
}
