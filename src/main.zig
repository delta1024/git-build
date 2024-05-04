const std = @import("std");
const git = @import("git");
const args = @import("arguments.zig");
pub fn main() !u8 {
    const argsAllocator = std.heap.page_allocator;
    const program_args = args.parseArgs(argsAllocator) catch |err| switch (err) {
        error.WrongArg => return 1,
        else => |e| return e,
    };
    return try args.runArgs(&program_args, argsAllocator);
}
