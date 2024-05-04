const std = @import("std");
const Allocator = std.mem.Allocator;
const argParser = @import("args");

const Error = error{
    WrongArg,
};
pub inline fn printHelp(comptime T: type, name: []const u8) !u8 {
    const writer = std.io.getStdErr().writer();
    try argParser.printHelp(T, name, writer);
    return error.WrongArg;
}
pub const program = @import("arguments/program.zig");
pub const runArgs = program.runArgs;
pub const parseArgs = program.parseArgs;
