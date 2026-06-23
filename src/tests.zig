const std = @import("std");

comptime {
    _ = @import("cli.zig");
    _ = @import("main.zig");
    _ = @import("output.zig");
    _ = @import("parser.zig");
    _ = @import("utils.zig");
}
