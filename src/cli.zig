const std = @import("std");
const utils = @import("utils.zig");
const print = utils.print;

pub const options = struct {
    file: ?[]const u8,
    show_help: bool,
    show_sections: bool,
    show_headers: bool,
};

pub fn parse_args(args: *std.process.ArgIterator) !options {
    const opt_list = [_][]const u8{ "--help", "-f", "--file", "-s", "--sections", "-h", "--headers", "-a", "--all" };
    var opts = options{ .file = null, .show_help = false, .show_sections = false, .show_headers = false };
    var next_val = false;
    while (args.next()) |arg| {
        if (next_val) {
            for (opt_list) |item| {
                if (std.meta.eql(item, arg)) {
                    return error.OptionUsedAsValue;
                }
            }
            opts.file = arg;
            next_val = false;
            continue;
        }

        if (std.mem.eql(u8, arg, "--help")) {
            opts.show_help = true;
        } else if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--file")) {
            next_val = true;
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--sections")) {
            opts.show_sections = true;
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--headers")) {
            opts.show_headers = true;
        } else if (std.mem.eql(u8, arg, "-a") or std.mem.eql(u8, arg, "--all")) {
            opts.show_sections = true;
            opts.show_headers = true;
        } else {
            return error.InvalidOption;
        }
    }

    if (next_val) {
        return error.UnspecifiedValue;
    }

    return opts;
}
