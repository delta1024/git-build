const std = @import("std");
const git = @import("git");
const args = @import("args.zig");
const lib = @import("lib");
const Temp = struct {
    v: u32,
    pub fn format(self: Temp, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = self;
        _ = options;
        try writer.print("{s}", .{fmt});
    }
};
pub fn main() !u8 {
    _ = try git.init();
    defer _ = git.shutdown() catch {};
    // var repo = r: {
    //     var path = try git.repository.discover(".", false, null);
    //     defer path.destroy();
    //     const rep = try git.repository.open(path.slice());
    //     break :r rep;
    // };
    // defer repo.destroy();
    // var conf = try repo.config();
    // defer conf.deinit();
    // var config = try conf.snapshot();
    // defer config.deinit();
    // std.debug.print("{s}\n", .{try config.getString("build.target")});
    const argsAllocator = std.heap.page_allocator;
    const program_args = args.parseArgs(argsAllocator) catch |err| switch (err) {
        error.WrongArg => return 1,
        else => |e| return e,
    };
    defer program_args.deinit();
    return args.runArgs(&program_args, argsAllocator) catch |err| switch (err) {
        error.WrongArg => return 1,
        else => |e| return e,
    };
    // return 0;
}
