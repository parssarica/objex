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
