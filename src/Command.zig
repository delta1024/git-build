const std = @import("std");
const mem = std.mem;
cmd_str: []const u8,
inputs: []const []const u8,
output: []const u8,
pub const INPUT_STR = "INPUT";
pub const OUTPUT_STR = "OUTPUT";
const Self = @This();

pub fn format(self: Self, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    const input_start = mem.indexOf(u8, self.cmd_str, INPUT_STR) orelse 0;
    const input_end = input_start + INPUT_STR.len;

    const before_input = self.cmd_str[0..input_start];

    const maybe_output_start = mem.indexOfPos(u8, self.cmd_str, input_end, OUTPUT_STR);
    const maybe_output_end = if (maybe_output_start) |out_start| out_start + OUTPUT_STR.len else null;

    const before_output = if (maybe_output_start) |out_start| self.cmd_str[input_end..out_start] else self.cmd_str[input_end..];

    const rest = if (maybe_output_end) |end| self.cmd_str[end..] else null;

    try writer.print("{s}", .{before_input});

    for (self.inputs, 0..) |input, i| {
        if (i > 0)
            try writer.print(" {s}", .{input})
        else
            try writer.print("{s}", .{input});
    }

    try writer.print("{s}", .{before_output});

    try writer.print("{s}", .{self.output});

    if (rest) |r|
        try writer.print("{s}", .{r});
}
test "Command.format" {
    const alloc = std.heap.page_allocator;
    const cmd = Self{
        .output = "test",
        .inputs = &.{"main.c"},
        .cmd_str = "gcc INPUT -o OUTPUT",
    };
    const str = try std.fmt.allocPrint(alloc, "{}", .{cmd});
    defer alloc.free(str);
    try std.testing.expectEqualStrings("gcc main.c -o test", str);
}
test "Command.format multi input" {
    const alloc = std.heap.page_allocator;
    const cmd = Self{
        .output = "test",
        .inputs = &.{ "main.c", "other.c" },
        .cmd_str = "gcc INPUT -o OUTPUT",
    };
    const str = try std.fmt.allocPrint(alloc, "{}", .{cmd});
    defer alloc.free(str);
    try std.testing.expectEqualStrings("gcc main.c other.c -o test", str);
}
