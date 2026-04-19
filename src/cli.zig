const std = @import("std");
const utils = @import("utils.zig");
const print = utils.print;

pub const options = struct {
    file: ?[]const u8,
    colors_on: bool,
    show_help: bool,
    show_sections: bool,
    show_headers: bool,
};

pub fn parse_args(args: *std.process.ArgIterator) !options {
    const opt_list = [_][]const u8{ "--help", "-s", "--sections", "-h", "--headers", "-a", "--all", "--no-color" };
    var opts = options{ .file = null, .colors_on = true, .show_help = false, .show_sections = false, .show_headers = false };
    var last_val: []const u8 = undefined;
    var invalid_option_used = false;
    while (args.next()) |arg| {
        last_val = arg;
        if (invalid_option_used) {
            return error.InvalidOption;
        }

        if (std.mem.eql(u8, arg, "--help")) {
            opts.show_help = true;
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--sections")) {
            opts.show_sections = true;
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--headers")) {
            opts.show_headers = true;
        } else if (std.mem.eql(u8, arg, "-a") or std.mem.eql(u8, arg, "--all")) {
            opts.show_sections = true;
            opts.show_headers = true;
        } else if (std.mem.eql(u8, arg, "--no-color")) {
            opts.colors_on = false;
        } else {
            invalid_option_used = true;
        }
    }

    for (opt_list) |opt| {
        if (std.meta.eql(opt, last_val)) {
            return error.OptionUsedAsFile;
        }
    }

    opts.file = last_val;

    return opts;
}
