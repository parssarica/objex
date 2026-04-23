// Pars SARICA <pars@parssarica.com>
//

const std = @import("std");

pub fn print(comptime fmt: []const u8, args: anytype) void {
    var stdout_impl = std.fs.File.stdout().writer(&.{});
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

pub fn readfile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            print("\x1b[31mERROR:\x1b[0m File doesn't exist.\n", .{});
        } else {
            print("\x1b[31mERROR:\x1b[0m {any}\n", .{@errorName(err)});
        }
        std.process.exit(1);
    };

    defer file.close();
    const size = (try file.stat()).size;

    const memory = try allocator.alloc(u8, size);

    _ = try file.read(memory);

    return memory;
}
