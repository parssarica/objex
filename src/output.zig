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
        \\    -a, --all      show all informations about file
        \\    -s, --sections show sections
        \\    -h, --headers  show headers
        \\
        \\Example usage:
        \\
        \\    objex -a /bin/ls
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
        print("\tType: \t\t\t\t\t{d}, {s}\n", .{ parsed.header.e_type, switch (parsed.header.e_type) {
            0 => "None",
            1 => "Relocatable file",
            2 => "Executable file",
            3 => "Shared object",
            4 => "Core file",
            0xfe00...0xfeff => "Operating system specific",
            0xff00...0xffff => "Processor specific",
            else => "Unkown",
        } });
        print("\tMachine: \t\t\t\t{d}, {s}\n", .{ parsed.header.e_machine, switch (parsed.header.e_machine) {
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
