const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
target: []u8,
inputs: [][]u8,
dep_files: ?[][]u8,
cmd: []u8,

const Spec = @This();
pub const Error = Allocator.Error || InvalidFormat;
pub const InvalidFormat = error{
    WrongFormat,
};
pub fn parse(gpa: Allocator, source: []const u8) Error!*Spec {
    var inputs = std.ArrayList([]u8).init(gpa);
    defer {
        while (inputs.popOrNull()) |ptr| gpa.free(ptr);
        inputs.deinit();
    }

    var deps = std.ArrayList([]u8).init(gpa);
    defer {
        while (deps.popOrNull()) |ptr| gpa.free(ptr);
        deps.deinit();
    }

    const Seen = struct {
        target: bool = false,
        cmd: bool = false,
        input: bool = false,
    };
    var modes_seen: Seen = .{};

    const spec = try gpa.create(Spec);
    spec.dep_files = null;
    errdefer {
        if (modes_seen.target) gpa.free(spec.target);
        if (modes_seen.cmd) gpa.free(spec.cmd);
        if (modes_seen.input) {
            for (spec.inputs) |i| gpa.free(i);
            gpa.free(spec.inputs);
        }
        gpa.destroy(spec);
    }
    const Mode = enum {
        line,
        field,
        target,
        input,
        input_multiline,
        input_deps,
        cmd,
        done,
    };
    const mode_map = std.ComptimeStringMap(Mode, .{
        .{ "target", .target },
        .{ "inputs", .input },
        .{ "cmd", .cmd },
    });
    var mode: Mode = .line;
    var line_iter = mem.tokenizeScalar(u8, source, '\n');
    var field_iter: ?mem.TokenIterator(u8, .scalar) = null;
    var input_iter: ?mem.TokenIterator(u8, .scalar) = null;
    var scratch = std.ArrayList(u8).init(gpa);
    defer scratch.deinit();
    var input_scratch = std.ArrayList(u8).init(gpa);
    defer input_scratch.deinit();
    var has_dep = false;

    while (mode != .done) {
        switch (mode) {
            .line => {
                const line = line_iter.next() orelse {
                    mode = .done;
                    continue;
                };
                field_iter = mem.tokenizeScalar(u8, line, ':');
                mode = .field;
            },
            .field => {
                const field_name = field_iter.?.next() orelse return error.WrongFormat;
                const field_contents = field_iter.?.rest();
                field_iter = null;
                switch (mode_map.get(field_name) orelse return error.WrongFormat) {
                    .cmd => {
                        try scratch.appendSlice(field_contents);
                        mode = .cmd;
                    },
                    .target => {
                        try scratch.appendSlice(field_contents);
                        mode = .target;
                    },
                    .input => {
                        if (mem.containsAtLeast(u8, field_contents, 1, "{")) {
                            mode = .input_multiline;
                        } else {
                            input_iter = mem.tokenizeScalar(u8, field_contents, ' ');
                            mode = .input;
                        }
                    },
                    else => unreachable,
                }
            },
            .cmd => {
                spec.cmd = try scratch.toOwnedSlice();
                modes_seen.cmd = true;
                mode = .line;
            },
            .target => {
                spec.target = try scratch.toOwnedSlice();
                modes_seen.target = true;
                mode = .line;
            },
            .input_multiline => {
                var cur_line = line_iter.next() orelse return error.WrongFormat;
                multi: while (true) {
                    if (mem.startsWith(u8, cur_line, "}")) {
                        input_iter = mem.tokenizeScalar(u8, input_scratch.items, ' ');
                        mode = .input;
                        break :multi;
                    }
                    if (mem.indexOf(u8, cur_line, ",")) |comma_idx| {
                        try input_scratch.appendSlice(cur_line[0..comma_idx]);
                        try input_scratch.append(' ');
                        cur_line = line_iter.next() orelse return error.WrongFormat;
                    } else return error.WrongFormat;
                }
            },
            .input => {
                const in = input_iter.?.next() orelse {
                    spec.inputs = try inputs.toOwnedSlice();
                    modes_seen.input = true;
                    mode = .line;
                    continue;
                };
                if (mem.startsWith(u8, in, "(")) {
                    const buf = b: {
                        has_dep = true;
                        const oneshot = mem.endsWith(u8, in, ")");
                        const less: usize = if (oneshot) 2 else 1;
                        const b = try gpa.alloc(u8, in.len - less);
                        errdefer gpa.free(b);
                        const str = if (oneshot) in[1 .. in.len - 1] else in[1..in.len];
                        @memcpy(b, str);
                        if (!oneshot)
                            mode = .input_deps;
                        break :b b;
                    };
                    try deps.append(buf);
                } else {
                    const buf = try gpa.alloc(u8, in.len);
                    errdefer gpa.free(buf);
                    @memcpy(buf, in[0..in.len]);
                    try inputs.append(buf);
                }
            },
            .input_deps => {
                const in = input_iter.?.next() orelse {
                    has_dep = true;
                    mode = .input;
                    continue;
                };
                if (mem.containsAtLeast(u8, in, 1, ")")) {
                    {
                        const buff = try gpa.alloc(u8, in.len - 1);
                        errdefer gpa.free(buff);
                        @memcpy(buff, in[0 .. in.len - 1]);
                        try deps.append(buff);
                    }
                    has_dep = true;
                    mode = .input;
                    continue;
                }
                const buff = try gpa.alloc(u8, in.len);
                errdefer gpa.free(buff);
                @memcpy(buff, in[0..in.len]);
                try deps.append(buff);
            },
            .done => unreachable,
        }
    }
    if (has_dep) {
        spec.dep_files = try deps.toOwnedSlice();
    }
    return spec;
}
pub fn destroy(self: *Spec, gpa: Allocator) void {
    gpa.free(self.target);
    for (self.inputs) |input| gpa.free(input);
    gpa.free(self.inputs);
    if (self.dep_files) |deps| {
        for (deps) |dep| gpa.free(dep);
        gpa.free(deps);
    }
    gpa.free(self.cmd);
    gpa.destroy(self);
}
pub fn format(self: *const Spec, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    try writer.print("target: {s}\n", .{self.target});
    try writer.writeAll("inputs: ");
    for (self.inputs) |input| try writer.print("{s} ", .{input});
    try writer.writeAll("\n");
    if (self.dep_files) |deps| {
        try writer.print("deps: ", .{});
        for (deps) |dep| try writer.print("{s} ", .{dep});
        try writer.print("\n", .{});
    }
    try writer.print("cmd: {s}\n", .{self.cmd});
}
