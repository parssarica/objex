const std = @import("std");
const utils = @import("utils.zig");
const cli = @import("cli.zig");
const parser = @import("parser.zig");
const print = utils.print;

pub fn help() void {
    const help_msg =
        \\Usage: objex <options> <file>
        \\
        \\Options:
        \\        --help     show this help message and exit
        \\    -f, --file     specify file
        \\    -a, --all      show all informations about file
        \\    -s, --sections show sections
        \\    -h, --headers  show headers
        \\
        \\Example usage:
        \\
        \\    objex -a -f /bin/ls
        \\
        \\    Shows all informations about /bin/ls
        \\
    ;

    print("{s}", .{help_msg});
}

pub fn print_parsed(allocator: std.mem.Allocator, opts: *const cli.options, parsed: *const parser.elf_file) !void {
    if (!opts.show_sections and !opts.show_headers) {
        print("\x1b[31mERROR:\x1b[0m No options provided.", .{});
        std.process.exit(1);
    }

    if (opts.show_headers) {
        var magic_str: std.ArrayList(u8) = .empty;
        defer magic_str.deinit(allocator);

        for (parsed.e_ident_part.magic, 0..) |byte, i| {
            try magic_str.print(allocator, "{x:0>2}", .{byte});
            if (i < parsed.e_ident_part.magic.len - 1) {
                try magic_str.append(allocator, ' ');
            }
        }
        print("Headers:\n", .{});
        print("\tMagic bytes: \t\t\t\t{s}\n", .{magic_str.items});
        print("\tClass: \t\t\t\t\t{X}, {s}\n", .{ parsed.e_ident_part.class, if (parsed.e_ident_part.class == 0x2) "64-bit" else "32-bit" });
        print("\tEndianness: \t\t\t\t{X}, {s}\n", .{ parsed.e_ident_part.endianness, if (parsed.e_ident_part.endianness == 0x1) "little endian" else "big endian" });
        print("\tELF version: \t\t\t\tv{d}\n", .{parsed.e_ident_part.elfver});
        print("\tOS ABI: \t\t\t\t{X}, {s}\n", .{ parsed.e_ident_part.osabi, switch (parsed.e_ident_part.osabi) {
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
        print("\tABI version: \t\t\t\tv{d}\n", .{parsed.e_ident_part.abiver});
        print("\tType: \t\t\t\t\t{d}\n", .{parsed.header.e_type});
        print("\tMachine: \t\t\t\t{d}\n", .{parsed.header.e_machine});
        print("\tVersion: \t\t\t\t{d}\n", .{parsed.header.e_version});
        print("\tEntry point: \t\t\t\t0x{X}\n", .{parsed.header.e_entry});
        print("\tProgram headers offset: \t\t0x{X}\n", .{parsed.header.e_phoff});
        print("\tSection headers offset: \t\t0x{X}\n", .{parsed.header.e_shoff});
        print("\tFlags: \t\t\t\t\t0x{X}\n", .{parsed.header.e_flags});
        print("\tELF header size: \t\t\t{d} bytes\n", .{parsed.header.e_ehsize});
        print("\tProgram header entry size: \t\t{d} bytes\n", .{parsed.header.e_phentsize});
        print("\tProgram header count: \t\t\t{d}\n", .{parsed.header.e_phnum});
        print("\tSection header entry size: \t\t{d} bytes\n", .{parsed.header.e_shentsize});
        print("\tSection header count: \t\t\t{d}\n", .{parsed.header.e_shnum});
        print("\tSection header string table index: \t{d}\n", .{parsed.header.e_shstrndx});
    }

    if (opts.show_sections) {
        for (parsed.section_header.items, 0..) |sect, i| {
            print("Section {d}\n", .{i});
            print("\tName: {s}\n", .{sect.name orelse "No name found."});
            print("\tName offset: 0x{X}\n", .{sect.sh_name});
            print("\tType: 0x{X}\n", .{sect.sh_type});
            print("\tFlags: 0x{X}\n", .{sect.sh_flags});
            print("\tVirtual addres: 0x{X}\n", .{sect.sh_addr});
            print("\tOffset: 0x{X}\n", .{sect.sh_offset});
            print("\tSize: 0x{X}\n", .{sect.sh_size});
            print("\tLink: 0x{X}\n", .{sect.sh_link});
            print("\tInfo: 0x{X}\n", .{sect.sh_info});
            print("\tAddress align: 0x{X}\n", .{sect.sh_addralign});
            print("\tEntry size: 0x{X}\n\n", .{sect.sh_entsize});
        }
    }
}
