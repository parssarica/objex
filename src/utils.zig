// Pars SARICA <pars@parssarica.com>
//

const std = @import("std");
const main = @import("main.zig");

pub fn print(comptime fmt: []const u8, args: anytype) void {
    var buffer: [4096]u8 = undefined;
    var stdout_impl = std.Io.File.stdout().writer(main.io.?, &buffer);
    const stdout = &stdout_impl.interface;

    stdout.print(fmt, args) catch {
        std.debug.print("Can't write to stdout. Exiting...\n", .{});
        std.process.exit(1);
    };
    stdout.flush() catch {
        std.debug.print("Can't write to stdout. Exiting...\n", .{});
        std.process.exit(1);
    };
}

pub fn readfile(allocator: std.mem.Allocator, path: []const u8) []u8 {
    const file = std.Io.Dir.readFileAlloc(std.Io.Dir.cwd(), main.io.?, path, allocator, .unlimited) catch |err| {
        if (err == error.FileNotFound) {
            print("\x1b[31mERROR:\x1b[0m File doesn't exist.\n", .{});
        } else if (err == error.IsDir) {
            print("\x1b[31mERROR:\x1b[0m Path is a directory rather than a file.\n", .{});
        } else {
            print("\x1b[31mERROR:\x1b[0m {any}\n", .{@errorName(err)});
        }
        std.process.exit(1);
    };

    return file;
}
