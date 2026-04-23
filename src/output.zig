const std = @import("std");
const utils = @import("utils.zig");
const cli = @import("cli.zig");
const parser = @import("parser.zig");
const print = utils.print;
const ArrayList = std.ArrayList;

const segment_tag = enum {
    executable,
    data,
    databss,
    dynamic,
    interpreted,
    readonly,
};

const colors = struct {
    red: u8 = 31,
    green: u8 = 32,
    yellow: u8 = 33,
    brightyellow: u8 = 93,
    blue: u8 = 34,
    brightblue: u8 = 94,
    purple: u8 = 35,
    brightpurple: u8 = 95,
    cyan: u8 = 36,
    brightcyan: u8 = 96,
    white: u8 = 37,
    brightblack: u8 = 90,
    highlightedred: u8 = 41,
    highlightedgreen: u8 = 42,
    highlightedyellow: u8 = 43,
    highlightedblue: u8 = 44,
    highlightedpurple: u8 = 45,
    highlightedcyan: u8 = 46,
    highlightedwhite: u8 = 47,
    bold: u8 = 1,
    dimwhite: u8 = 2,
    italic: u8 = 3,
};

pub fn help() void {
    const help_msg =
        \\Usage: objex <options> <file>
        \\
        \\Options:
        \\        --help            show this help message and exit
        \\        --no-color        disables colors
        \\    -a, --all             show all information about file
        \\    -S, --sections        show sections
        \\    -s, --symbols         show symbols
        \\    -h, --headers         show headers
        \\    -l, --program-headers show program headers (segments)
        \\        --strings         show strings
        \\
        \\Example usage:
        \\
        \\    objex -a /bin/ls
        \\
        \\    Shows all information about /bin/ls
        \\
    ;

    print("{s}", .{help_msg});
}

pub fn print_parsed(allocator: std.mem.Allocator, opts: *const cli.options, parsed: *const parser.elf_file, color_opts: colors) !void {
    if (!opts.show_sections and !opts.show_headers and !opts.show_symbols and !opts.show_strings and !opts.show_segments) {
        print("\x1b[31mERROR:\x1b[0m No options provided.\n", .{});
        std.process.exit(1);
    }

    if (opts.show_headers) {
        var magic_str: ArrayList(u8) = .empty;
        var flags_resolved: ArrayList(u8) = try resolve_flags(allocator, parsed.header.e_flags, parsed.header.e_machine, color_opts);
        defer magic_str.deinit(allocator);
        defer flags_resolved.deinit(allocator);

        for (parsed.e_ident_part.magic, 0..) |byte, i| {
            try magic_str.print(allocator, "{x:0>2}", .{byte});
            if (i < parsed.e_ident_part.magic.len - 1) {
                try magic_str.append(allocator, ' ');
            }
        }
        print("\x1b[{d}\x1b[{d}mHeaders:\x1b[0m\n", .{ color_opts.bold, color_opts.cyan });
        print("\t\x1b[{d}mMagic bytes:\x1b[0m \t\t\t\t\x1b[{d}m{s}\x1b[0m\n", .{ color_opts.dimwhite, color_opts.yellow, magic_str.items });
        print("\t\x1b[{d}m\x1b[{d}mClass:\x1b[0m \t\t\t\t\t\x1b[{d}m{X}\x1b[0m, \x1b[{d}m{s}\x1b[0m\n", .{ color_opts.bold, color_opts.dimwhite, color_opts.green, parsed.e_ident_part.class, color_opts.white, if (parsed.e_ident_part.class == 0x2) "64-bit" else "32-bit" });
        print("\t\x1b[{d}m\x1b[{d}mEndianness:\x1b[0m \t\t\t\t\x1b[{d}m{X}\x1b[0m, \x1b[{d}m{s}\x1b[0m\n", .{ color_opts.bold, color_opts.dimwhite, color_opts.green, parsed.e_ident_part.endianness, color_opts.white, if (parsed.e_ident_part.endianness == 0x1) "little endian" else "big endian" });
        print("\t\x1b[{d}mELF version:\x1b[0m \t\t\t\t\x1b[{d}mv{d}\x1b[0m\n", .{ color_opts.dimwhite, color_opts.green, parsed.e_ident_part.elfver });
        print("\t\x1b[{d}mOS ABI:\x1b[0m \t\t\t\t\x1b[{d}m{X}\x1b[0m, \x1b[{d}m{s}\x1b[0m\n", .{ color_opts.dimwhite, color_opts.green, color_opts.white, parsed.e_ident_part.osabi, switch (parsed.e_ident_part.osabi) {
            0 => "System V",
            1 => "HP-UX",
            2 => "NetBSD",
            3 => "Linux",
            4 => "GNU Hurd",
            6 => "Solaris",
            7 => "AIX",
            8 => "IRIX",
            9 => "FreeBSD",
            10 => "Tru64",
            11 => "Novell Modesto",
            12 => "OpenBSD",
            13 => "OpenVMS",
            14 => "NonStop Kernel",
            15 => "AROS",
            16 => "FenixOS",
            17 => "CloudABI",
            18 => "Stratus Technologies OpenVOS",
            else => "Other",
        } });
        print("\t\x1b[{d}mABI version:\x1b[0m \t\t\t\t\x1b[{d}mv{d}\x1b[0m\n\n", .{ color_opts.dimwhite, color_opts.green, parsed.e_ident_part.abiver });
        print("\t\x1b[{d}m\x1b[{d}mType:\x1b[0m \t\t\t\t\t\x1b[{d}m{d}, \x1b[{d}m{s}\x1b[0m\n", .{ color_opts.bold, color_opts.dimwhite, color_opts.green, parsed.header.e_type, color_opts.white, switch (parsed.header.e_type) {
            0 => "None",
            1 => "Relocatable file",
            2 => "Executable file",
            3 => "Shared object",
            4 => "Core file",
            0xfe00...0xfeff => "Operating system specific",
            0xff00...0xffff => "Processor specific",
            else => "Unkown",
        } });
        print("\t\x1b[{d}m\x1b[{d}mMachine:\x1b[0m \t\t\t\t\x1b[{d}m{d}\x1b[0m, \x1b[{d}m{s}\x1b[0m\n", .{ color_opts.bold, color_opts.dimwhite, color_opts.green, parsed.header.e_machine, color_opts.white, switch (parsed.header.e_machine) {
            0 => "None",
            1 => "AT&T WE 32100",
            2 => "SPARC",
            3 => "x86",
            4 => "Motorola 68000 (M68k)",
            5 => "Motorola 88000 (M88k)",
            6 => "Intel MCU",
            7 => "Intel 80860",
            8 => "MIPS",
            9 => "IBM System/370",
            0xa => "MIPS RS3000 Little-endian",
            0xb...0xe => "Reserved",
            0xf => "Hewlett-Packard PA-RISC",
            0x13 => "Intel 80960",
            0x14 => "PowerPC",
            0x15 => "PowerPC (64-bit)",
            0x16 => "S390",
            0x17 => "IBM SPU/SPC",
            0x18...0x23 => "Reserved",
            0x24 => "NEC V800",
            0x25 => "Fujitsu FR20",
            0x26 => "TRW RH-32",
            0x27 => "Motorola RCE",
            0x28 => "Arm",
            0x29 => "Digital Alpha",
            0x2a => "SuperH",
            0x2b => "SPARC Version 9",
            0x2c => "Siemens TriCore embedded processor",
            0x2d => "Argonaut RISC Core",
            0x2e => "Hitachi H8/300",
            0x2f => "Hitachi H8/300H",
            0x30 => "Hitachi H8S",
            0x31 => "Hitachi H8/500",
            0x32 => "IA-64",
            0x33 => "Stanford MIPS-X",
            0x34 => "Motorola ColdFire",
            0x35 => "Motorola M68HC12",
            0x36 => "Fujitsu MMA Multimedia Accelerator",
            0x37 => "Siemens PCP",
            0x38 => "Sony nCPU embedded RISC processor",
            0x39 => "Denso NDR1 microprocessor",
            0x3a => "Motorola Star*Core processor",
            0x3b => "Toyota ME16 processor",
            0x3c => "STMicroelectronics ST100 processor",
            0x3d => "Advanced Logic Corp. TinyJ embedded processor family",
            0x3e => "AMD x86-64",
            0x3f => "Sony DSP Processor",
            0x40 => "Digital Equipment Corp. PDP-10",
            0x41 => "Digital Equipment Corp. PDP-11",
            0x42 => "Siemens FX66 microcontroller",
            0x43 => "STMicroelectronics ST9+ 8/16-bit microcontroller",
            0x44 => "STMicroelectronics ST7 8-bit microcontroller",
            0x45 => "Motorola MC68HC16 Microcontroller",
            0x46 => "Motorola MC68HC11 Microcontroller",
            0x47 => "Motorola MC68HC08 Microcontroller",
            0x48 => "Motorola MC68HC05 Microcontroller",
            0x49 => "Silicon Graphics SVx",
            0x4a => "STMicroelectronics ST19 8-bit microcontroller",
            0x4b => "Digital VAX",
            0x4c => "Axis Communications 32-bit embedded processor",
            0x4d => "Infineon Technologies 32-bit embedded processor",
            0x4e => "Element 14 64-bit DSP Processor",
            0x4f => "LSI Logic 16-bit DSP Processor",
            0x8c => "TMS320C6000 Family",
            0xaf => "MCST Elbrus e2k",
            0xb7 => "Arm 64-bits",
            0xdc => "Zilog Z80",
            0xf3 => "RISC-V",
            0xf7 => "Berkeley Packet Filter",
            0x101 => "WDC 65C816",
            0x102 => "LoongArch",
            else => "Unknown",
        } });
        print("\t\x1b[{d}mVersion:\x1b[0m \t\t\t\t\x1b[{d}m{d}\x1b[0m\n", .{ color_opts.dimwhite, color_opts.green, parsed.header.e_version });
        print("\t\x1b[{d}m\x1b[{d}mEntry point:\x1b[0m \t\t\t\t\x1b[{d}m0x{X}\x1b[0m\n\n", .{ color_opts.bold, color_opts.dimwhite, color_opts.blue, parsed.header.e_entry });
        print("\t\x1b[{d}m\x1b[{d}mProgram headers offset:\x1b[0m \t\t\x1b[{d}m0x{X}\x1b[0m\n", .{ color_opts.bold, color_opts.dimwhite, color_opts.blue, parsed.header.e_phoff });
        print("\t\x1b[{d}m\x1b[{d}mSection headers offset:\x1b[0m \t\t\x1b[{d}m0x{X}\x1b[0m\n", .{ color_opts.bold, color_opts.dimwhite, color_opts.blue, parsed.header.e_shoff });
        print("\t\x1b[{d}mFlags:\x1b[0m \t\t\t\t\t0x{X}, {s}\n\n", .{ color_opts.dimwhite, parsed.header.e_flags, flags_resolved.items });
        print("\t\x1b[{d}mELF header size:\x1b[0m \t\t\t\x1b[{d}m{d}\x1b[0m \x1b[{d}mbytes\x1b[0m\n", .{ color_opts.dimwhite, color_opts.yellow, parsed.header.e_ehsize, color_opts.dimwhite });
        print("\t\x1b[{d}mProgram header entry size:\x1b[0m \t\t\x1b[{d}m{d}\x1b[0m \x1b[{d}mbytes\x1b[0m\n", .{ color_opts.dimwhite, color_opts.yellow, parsed.header.e_phentsize, color_opts.dimwhite });
        print("\t\x1b[{d}mProgram header count:\x1b[0m \t\t\t\x1b[{d}m{d}\x1b[0m\n", .{ color_opts.dimwhite, color_opts.green, parsed.header.e_phnum });
        print("\t\x1b[{d}mSection header entry size:\x1b[0m \t\t\x1b[{d}m{d}\x1b[0m \x1b[{d}mbytes\x1b[0m\n", .{ color_opts.dimwhite, color_opts.yellow, parsed.header.e_shentsize, color_opts.dimwhite });
        print("\t\x1b[{d}mSection header count:\x1b[0m \t\t\t\x1b[{d}m{d}\x1b[0m\n", .{ color_opts.dimwhite, color_opts.green, parsed.header.e_shnum });
        print("\t\x1b[{d}mSection header string table index:\x1b[0m \t\x1b[{d}m{d}\x1b[0m\n", .{ color_opts.dimwhite, color_opts.yellow, parsed.header.e_shstrndx });
    }

    if (opts.show_sections) blkout: {
        if (opts.show_headers) {
            print("\n", .{});
        }
        if (parsed.section_header.items.len == 0) {
            print("No sections are present.\n", .{});
            break :blkout;
        }
        print("Idx Sym Name                    Type           Addr       Offset   Size     Flags   \n", .{});
        print("----------------------------------------------------------------------------------------\n", .{});
        for (parsed.section_header.items, 0..) |sect, i| {
            var flags = try decode_flags(allocator, sect.sh_flags);
            defer flags.deinit(allocator);
            print("\x1b[{d}m{d:>3}\x1b[0m {s}   \x1b[{d}m{s:<24}\x1b[{d}m{s:<15}\x1b[{d}m0x{X:<9}0x{X:<7}\x1b[{d}m{d:<9}\x1b[0m\x1b[{d}m{s:<6}\x1b[0m\n", .{ color_opts.dimwhite, i, blk: {
                if (std.mem.eql(u8, sect.name orelse "<null>", ".text")) {
                    break :blk "▶";
                } else if (std.mem.eql(u8, sect.name orelse "<null>", ".data")) {
                    break :blk "●";
                } else if (std.mem.eql(u8, sect.name orelse "<null>", ".bss")) {
                    break :blk "○";
                }

                break :blk " ";
            }, color_opts.blue, sect.name orelse "<null>", color_opts.purple, switch (sect.sh_type) {
                0 => "NULL",
                1 => "PROGBITS",
                2 => "SYMTAB",
                3 => "STRTAB",
                4 => "RELA",
                5 => "HASH",
                6 => "DYNAMIC",
                7 => "NOTE",
                8 => "NOBITS",
                9 => "REL",
                10 => "SHLIB",
                11 => "DYNSYM",
                14 => "INIT_ARRAY",
                15 => "FINI_ARRAY",
                16 => "PREINIT_ARRAY",
                17 => "GROUP",
                18 => "SYMTAB_SHNDX",
                19 => "RELR",
                20 => "NUM",
                0x6ffffff5 => "GNU_ATTRIBUTES",
                0x6ffffff6 => "GNU_HASH",
                0x6ffffff7 => "GNU_LIBLIST",
                0x6ffffff8 => "CHECKSUM",
                0x6ffffffa => "SUNW_MOVE",
                0x6ffffffb => "SUNW_COMDAT",
                0x6ffffffc => "SUNW_SYMINFO",
                0x6ffffffd => "VERDEF",
                0x6ffffffe => "VERNEED",
                0x6fffffff => "VERSYM",
                0x70000000...0x7fffffff => "Proc specific",
                0x80000000...0x8fffffff => "User specific",
                else => "Unknown",
            }, color_opts.blue, sect.sh_addr, sect.sh_offset, color_opts.green, sect.sh_size, if (std.mem.eql(u8, flags.items, "-")) color_opts.dimwhite else color_opts.purple, flags.items });
        }

        print("\n\x1b[{d}mFlags:\x1b[0m\n", .{color_opts.cyan});
        print("  \x1b[{d}mCore\x1b[0m          : \x1b[{d}mW\x1b[0m \x1b[{d}m(write)\x1b[0m       \x1b[{d}mA\x1b[0m \x1b[{d}m(alloc)\x1b[0m      \x1b[{d}m\x1b[{d}mX\x1b[0m \x1b[{d}m(execute)\x1b[0m\n", .{ color_opts.dimwhite, color_opts.green, color_opts.dimwhite, color_opts.blue, color_opts.dimwhite, color_opts.bold, color_opts.yellow, color_opts.dimwhite });
        print("  \x1b[{d}mData / Layout\x1b[0m : \x1b[{d}mM\x1b[0m \x1b[{d}m(merge)\x1b[0m       \x1b[{d}mS\x1b[0m \x1b[{d}m(strings)\x1b[0m    \x1b[{d}mC\x1b[0m \x1b[{d}m(compressed)\x1b[0m\n", .{ color_opts.dimwhite, color_opts.purple, color_opts.dimwhite, color_opts.cyan, color_opts.dimwhite, color_opts.brightpurple, color_opts.dimwhite });
        print("  \x1b[{d}mLinking\x1b[0m       : \x1b[{d}mI\x1b[0m \x1b[{d}m(info)\x1b[0m        \x1b[{d}mL\x1b[0m \x1b[{d}m(link-order)\x1b[0m \x1b[{d}mG\x1b[0m \x1b[{d}m(group)\x1b[0m\n", .{ color_opts.dimwhite, color_opts.brightblue, color_opts.dimwhite, color_opts.brightyellow, color_opts.dimwhite, color_opts.brightcyan, color_opts.dimwhite });
        print("  \x1b[{d}mSpecial\x1b[0m       : \x1b[{d}mT\x1b[0m \x1b[{d}m(TLS)\x1b[0m         \x1b[{d}mE\x1b[0m \x1b[{d}m(exclude)\x1b[0m\n", .{ color_opts.dimwhite, color_opts.red, color_opts.dimwhite, color_opts.brightblack, color_opts.dimwhite });
        print("  \x1b[{d}mOS / CPU\x1b[0m      : \x1b[{d}m\x1b[{d}mO\x1b[0m \x1b[{d}m(OS-specific)\x1b[0m \x1b[{d}mx\x1b[0m \x1b[{d}m(OS mask)\x1b[0m    \x1b[{d}mP\x1b[0m \x1b[{d}m(proc mask)\x1b[0m\n", .{ color_opts.dimwhite, color_opts.dimwhite, color_opts.yellow, color_opts.dimwhite, color_opts.dimwhite, color_opts.dimwhite, color_opts.dimwhite, color_opts.dimwhite });
    }

    if (opts.show_symbols) blkout: {
        if (opts.show_headers or opts.show_sections) {
            print("\n", .{});
        }

        if (parsed.symbols.items.len == 0) {
            print("No symbols are present.\n", .{});
            break :blkout;
        }

        print("Idx Sym Value               Size  Type    Bind    Vis     Section         Name\n", .{});
        print("--------------------------------------------------------------------------------\n", .{});
        for (parsed.symbols.items, 0..) |sym, i| {
            const cond = std.mem.eql(u8, sym.name orelse "", "main") or std.mem.eql(u8, sym.name orelse "", "_start");
            print("\x1b[{d}m{d:<4} {s}  \x1b[0m\x1b[{d}m0x{X:0>16}  {d:<6}\x1b[{d}m{s:<8}\x1b[0m\x1b[{d}m{s:<8}\x1b[0m\x1b[{d}m{s:<8}\x1b[0m\x1b[{d}m{s:<15}\x1b[{d}m\x1b[{d}m{s:<6}\x1b[0m\n", .{ color_opts.dimwhite, i, switch (sym.st_info & 0xf) {
                1 => "●",
                2 => "ƒ",
                3 => "§",
                4 => "F",
                5 => "T",
                6 => "🧵",
                else => switch (sym.st_shndx) {
                    0xfff1 => "=",
                    0xfff2 => "C",
                    else => "?",
                },
            }, color_opts.blue, sym.st_value, sym.st_size, color_opts.cyan, switch (sym.st_info & 0xf) {
                0 => "NOTYPE",
                1 => "OBJECT",
                2 => "FUNC",
                3 => "SECTION",
                4 => "FILE",
                5 => "COMMON",
                6 => "TLS",
                else => "Unknown",
            }, color_opts.yellow, switch (sym.st_info >> 4) {
                0 => "LOCAL",
                1 => "GLOBAL",
                2 => "WEAK",
                else => "Unknown",
            }, switch (sym.st_other & 3) {
                0 => color_opts.dimwhite,
                1 => color_opts.red,
                2 => color_opts.purple,
                3 => color_opts.brightblack,
                else => unreachable,
            }, switch (sym.st_other & 3) {
                0 => "DEFAULT",
                1 => "INTERNAL",
                2 => "HIDDEN",
                3 => "PROTECTED",
                else => unreachable,
            }, if (sym.st_shndx == 0) color_opts.red else color_opts.purple, blk: {
                if (sym.st_shndx == 0xfff1) {
                    break :blk "ABS";
                } else if (sym.st_shndx == 0xfff2) {
                    break :blk "COMMON";
                } else if (sym.st_shndx == 0) {
                    break :blk "UND";
                } else if (sym.st_shndx >= parsed.section_header.items.len) {
                    break :blk "Invalid section";
                } else {
                    break :blk (parsed.section_header.items[sym.st_shndx].name orelse "");
                }
            }, if (cond) color_opts.bold else 0, if (cond) color_opts.green else color_opts.white, sym.name orelse "" });
        }
    }

    if (opts.show_strings) blkout: {
        if (opts.show_headers or opts.show_sections or opts.show_symbols) {
            print("\n", .{});
        }

        if (parsed.strings.items.len == 0) {
            print("No strings are present.", .{});
            break :blkout;
        }

        for (parsed.strings.items) |str| {
            print("\x1b[{d}m0x{X:0>8}\x1b[0m  \x1b[{d}m{s}\x1b[0m\n", .{ color_opts.blue, str.addr, color_opts.green, str.s });
        }
    }

    if (opts.show_segments) blkout: {
        if (opts.show_headers or opts.show_sections or opts.show_strings or opts.show_symbols or opts.show_strings) {
            print("\n", .{});
        }

        if (parsed.program_header.items.len == 0) {
            print("No segments are present.", .{});
            break :blkout;
        }

        print("Idx Tag Type               Offset      Virtual address   Physical address   File size   Memory size  Flags  Align\n", .{});
        print("-------------------------------------------------------------------------------------------------------------------\n", .{});
        for (parsed.program_header.items, 0..) |sgmnt, i| {
            const tag: ?segment_tag = if (sgmnt.p_flags & 0x1 != 0) .executable else if (sgmnt.p_type == 1 and sgmnt.p_flags & 0x4 != 0 and sgmnt.p_flags & 0x2 != 0 and sgmnt.p_flags & 0x1 == 0 and sgmnt.p_memsz > sgmnt.p_filesz) .databss else if (sgmnt.p_type == 1 and sgmnt.p_flags & 0x4 != 0 and sgmnt.p_flags & 0x2 != 0 and sgmnt.p_flags & 0x1 == 0) .data else if (sgmnt.p_type == 2) .dynamic else if (sgmnt.p_type == 3) .interpreted else if (sgmnt.p_flags & 0x4 != 0 and sgmnt.p_flags & 0x2 == 0 and sgmnt.p_flags & 0x1 == 0) .readonly else null;
            var flags = try decode_flags_segments(allocator, sgmnt.p_flags, color_opts);
            defer flags.deinit(allocator);
            print("\x1b[{d}m{d:<3}\x1b[0m\x1b[{d}m{s:^5}\x1b[0m \x1b[{d}m{s:<18}\x1b[0m\x1b[{d}m0x{X:0>7}   0x{X:0>12}    0x{X:0>15}  {d:<12}{d:<13}\x1b[0m{s}\t   \x1b[{d}m0x{X:<5}\x1b[0m\n", .{ color_opts.dimwhite, i, if (tag) |t| switch (t) {
                .executable => color_opts.red,
                .data => color_opts.yellow,
                .databss => color_opts.brightblack,
                .dynamic => color_opts.purple,
                .interpreted => color_opts.cyan,
                .readonly => color_opts.green,
            } else 0, if (tag) |t| switch (t) {
                .executable => "[X]",
                .data => "[D]",
                .databss => "[D B]",
                .dynamic => "[Y]",
                .interpreted => "[L]",
                .readonly => "[R]",
            } else "", if (sgmnt.p_type == 1) color_opts.bold else color_opts.dimwhite, resolve_segment_type(sgmnt.p_type), color_opts.blue, sgmnt.p_offset, sgmnt.p_vaddr, sgmnt.p_paddr, sgmnt.p_filesz, sgmnt.p_memsz, flags.items, color_opts.blue, sgmnt.p_align });
        }

        print("\n\x1b[{d}mSections mapping to segments:\x1b[0m\n", .{color_opts.cyan});
        var printed_sects: u16 = 0;
        for (parsed.program_header.items, 0..) |sgmnt, i| {
            print("\x1b[{d}m[\x1b[0m\x1b[{d}m{d}\x1b[0m\x1b[{d}m]\x1b[0m \x1b[{d}m{s}\x1b[0m: ", .{ color_opts.dimwhite, color_opts.blue, i, color_opts.dimwhite, if (sgmnt.p_type == 1) color_opts.bold else color_opts.dimwhite, resolve_segment_type(sgmnt.p_type) });
            printed_sects = 0;
            for (parsed.section_header.items) |sect| {
                if (sect.sh_offset >= sgmnt.p_offset and sect.sh_offset + sect.sh_size <= sgmnt.p_offset + sgmnt.p_filesz) {
                    if (printed_sects != 0) {
                        print(", ", .{});
                    }
                    printed_sects += 1;
                    print("{s}", .{sect.name orelse "<null>"});
                }
            }

            if (printed_sects == 0) {
                print("No sections are mapped to this segment", .{});
            }

            print("\n", .{});
        }

        print("\n\x1b[{d}mFlags:\x1b[0m\n", .{color_opts.cyan});
        print("  \x1b[{d}mR\x1b[0m: Readable\n", .{color_opts.green});
        print("  \x1b[{d}mE\x1b[0m: Executable\n", .{color_opts.red});
        print("  \x1b[{d}mW\x1b[0m: Writable\n", .{color_opts.yellow});
        print("\n\x1b[{d}mTags:\x1b[0m\n", .{color_opts.cyan});
        print("  \x1b[{d}m[E]\x1b[0m: Executable\n", .{color_opts.red});
        print("  \x1b[{d}m[D]\x1b[0m: Data\n", .{color_opts.yellow});
        print("  \x1b[{d}m[D B]\x1b[0m: Data (.bss)\n", .{color_opts.brightblack});
        print("  \x1b[{d}m[Y]\x1b[0m: Dynamic\n", .{color_opts.purple});
        print("  \x1b[{d}m[L]\x1b[0m: Interpreted\n", .{color_opts.cyan});
        print("  \x1b[{d}m[R]\x1b[0m: Read-only\n", .{color_opts.green});
    }
}

pub fn color_table(colors_on: bool) colors {
    const c = if (colors_on) colors{} else colors{ .red = 0, .green = 0, .yellow = 0, .brightyellow = 0, .blue = 0, .brightblue = 0, .purple = 0, .brightpurple = 0, .cyan = 0, .brightcyan = 0, .white = 0, .brightblack = 0, .highlightedred = 0, .highlightedgreen = 0, .highlightedyellow = 0, .highlightedblue = 0, .highlightedpurple = 0, .highlightedcyan = 0, .highlightedwhite = 0, .bold = 0, .dimwhite = 0, .italic = 0 };

    return c;
}

fn decode_flags_segments(allocator: std.mem.Allocator, flags: u64, color_opts: colors) !ArrayList(u8) {
    var flag: ArrayList(u8) = .empty;
    var i: u8 = 0;

    if (flags & 0x4 != 0) {
        try flag.writer(allocator).print("\x1b[{}mR", .{color_opts.green});
        i += 1;
    }

    if (flags & 0x2 != 0) {
        try flag.writer(allocator).print("\x1b[{}mW", .{color_opts.yellow});
        i += 1;
    }

    if (flags & 0x1 != 0) {
        try flag.writer(allocator).print("\x1b[{}mE", .{color_opts.red});
        i += 1;
    }

    try flag.appendSlice(allocator, "\x1b[0m");

    return flag;
}

fn resolve_flags(allocator: std.mem.Allocator, flags: u64, machine: u16, color_opts: colors) !ArrayList(u8) {
    return switch (machine) {
        0x08 => parse_flags_mips(allocator, flags, color_opts),
        0xb7 => parse_flags_arm(allocator, flags, color_opts),
        0xf3 => parse_flags_riscv(allocator, flags, color_opts),
        else => flags_unknown(allocator, machine, color_opts),
    };
}

fn flags_unknown(allocator: std.mem.Allocator, machine: u16, color_opts: colors) !ArrayList(u8) {
    var string: ArrayList(u8) = .empty;

    if (machine == 3) {
        try string.print(allocator, "\x1b[{d}mx86\x1b[0m", .{color_opts.purple});
    } else if (machine == 0x3e) {
        try string.print(allocator, "\x1b[{d}mx86_64\x1b[0m", .{color_opts.purple});
    } else {
        try string.print(allocator, "\x1b[{d}mUnknown\x1b[0m", .{color_opts.purple});
    }

    return string;
}

fn parse_flags_arm(allocator: std.mem.Allocator, flags: u64, color_opts: colors) !ArrayList(u8) {
    var string: ArrayList(u8) = .empty;

    const eabi_ver = (flags >> 24) & 0xff;
    const flag_val = flags & 0xffffff;
    const interworking = (flag_val & 4) != 0;
    const pie = (flag_val & 0x20) != 0;
    const newabi = (flag_val & 0x200) != 0;
    const oldabi = (flag_val & 0x400) != 0;

    try string.print(allocator, "\x1b[{d}mEABI version: {d}\x1b[0m", .{ color_opts.purple, eabi_ver });
    if (interworking) {
        try string.print(allocator, ", \x1b[{d}minterworking enabled\x1b[0m", .{color_opts.purple});
    }

    if (pie) {
        try string.print(allocator, ", \x1b[{d}mPIE enabled\x1b[0m", .{color_opts.purple});
    }

    if (newabi) {
        try string.print(allocator, ", \x1b[{d}mnew ABI enabled\x1b[0m", .{color_opts.purple});
    }

    if (oldabi) {
        try string.print(allocator, ", \x1b[{d}mold ABI enabled\x1b[0m", .{color_opts.purple});
    }

    return string;
}

fn parse_flags_riscv(allocator: std.mem.Allocator, flags: u64, color_opts: colors) !ArrayList(u8) {
    var string: ArrayList(u8) = .empty;

    try string.print(allocator, "\x1b[{d}mFloat ABI: {s}\x1b[0m", .{ color_opts.purple, switch ((flags >> 1) & 0x3) {
        0 => "soft",
        1 => "single",
        2 => "double",
        3 => "quad",
        else => "unknown",
    } });
    if ((flags & 0x1) != 0) {
        try string.print(allocator, ", \x1b[{d}mRVC enabled\x1b[0m", .{color_opts.purple});
    }

    return string;
}

fn parse_flags_mips(allocator: std.mem.Allocator, flags: u64, color_opts: colors) !ArrayList(u8) {
    const ase = flags & 0xf000000;
    var string: ArrayList(u8) = .empty;

    if ((flags & 0x1) != 0) {
        try string.print(allocator, "\x1b[{d}mnoreorder\x1b[0m", .{color_opts.purple});
    }

    if ((flags & 0x2) != 0) {
        try string.print(allocator, ", \x1b[{d}mPIC\x1b[0m", .{color_opts.purple});
    }

    if ((flags & 0x4) != 0) {
        try string.print(allocator, ", \x1b[{d}mCPIC\x1b[0m", .{color_opts.purple});
    }

    if ((flags & 0x8) != 0) {
        try string.print(allocator, ", \x1b[{d}mXGOT\x1b[0m", .{color_opts.purple});
    }

    if ((flags & 0x10) != 0) {
        try string.print(allocator, ", \x1b[{d}mUCODE (obsolete)\x1b[0m", .{color_opts.purple});
    }

    if ((flags & 0x20) != 0) {
        try string.print(allocator, ", \x1b[{d}mABI2 (N32)\x1b[0m", .{color_opts.purple});
    }

    if ((flags & 0x80) != 0) {
        try string.print(allocator, ", \x1b[{d}mOPTIONS_FIRST\x1b[0m", .{color_opts.purple});
    }

    if ((flags & 0x100) != 0) {
        try string.print(allocator, ", \x1b[{d}m32-bit mode\x1b[0m", .{color_opts.purple});
    }

    if ((flags & 0x200) != 0) {
        try string.print(allocator, ", \x1b[{d}mFP64\x1b[0m", .{color_opts.purple});
    }

    if ((flags & 0x400) != 0) {
        try string.print(allocator, ", \x1b[{d}mNan2008\x1b[0m", .{color_opts.purple});
    }

    if ((flags & 0x40) != 0) {
        try string.print(allocator, ", \x1b[{d}mdynamic\x1b[0m", .{color_opts.purple});
    }

    if ((ase & 0x8000000) != 0) {
        try string.print(allocator, ", \x1b[{d}mASE: MDMX\x1b[0m", .{color_opts.purple});
    }

    if ((ase & 0x4000000) != 0) {
        try string.print(allocator, ", \x1b[{d}mASE: MIPS16\x1b[0m", .{color_opts.purple});
    }

    if ((ase & 0x2000000) != 0) {
        try string.print(allocator, ", \x1b[{d}mASE: MicroMIPS\x1b[0m", .{color_opts.purple});
    }

    return string;
}

fn decode_flags(allocator: std.mem.Allocator, flags: u64) !ArrayList(u8) {
    var flag: ArrayList(u8) = .empty;

    if (flags & 0x1 != 0) {
        try flag.append(allocator, 'W');
    }

    if (flags & 0x2 != 0) {
        try flag.append(allocator, 'A');
    }

    if (flags & 0x4 != 0) {
        try flag.append(allocator, 'X');
    }

    if (flags & 0x10 != 0) {
        try flag.append(allocator, 'M');
    }

    if (flags & 0x20 != 0) {
        try flag.append(allocator, 'S');
    }

    if (flags & 0x40 != 0) {
        try flag.append(allocator, 'I');
    }

    if (flags & 0x80 != 0) {
        try flag.append(allocator, 'L');
    }

    if (flags & 0x100 != 0) {
        try flag.append(allocator, 'O');
    }

    if (flags & 0x200 != 0) {
        try flag.append(allocator, 'G');
    }

    if (flags & 0x400 != 0) {
        try flag.append(allocator, 'T');
    }

    if (flags & 0x800 != 0) {
        try flag.append(allocator, 'C');
    }

    if (flags & 0xff00000 != 0) {
        try flag.append(allocator, 'x');
    }

    if (flags & 0x80000000 != 0) {
        try flag.append(allocator, 'E');
    }

    if (flags & 0xf0000000 != 0) {
        try flag.append(allocator, 'p');
    }

    if (std.mem.eql(u8, flag.items, "")) {
        try flag.append(allocator, '-');
    }

    return flag;
}

fn resolve_segment_type(p_type: u32) []const u8 {
    return switch (p_type) {
        0 => "NULL",
        1 => "LOAD",
        2 => "DYNAMIC",
        3 => "INTERP",
        4 => "NOTE",
        5 => "SHLIB",
        6 => "PHDR",
        7 => "TLS",
        0x70000000...0x7fffffff => "Proc specific",
        else => if (p_type == 0x6474e550) "GNU_EH_FRAME" else if (p_type == 0x6474e551) "GNU_STACK" else if (p_type == 0x6474e552) "GNU_RELRO" else if (p_type == 0x6474e553) "GNU_PROPERTY" else if (p_type >= 0x60000000 or p_type <= 0x6fffffff) "OS specific" else "Unknown",
    };
}
