const std = @import("std");
const Allocator = std.mem.Allocator;
const args = @import("args.zig");

const argParser = @import("args");
pub const Args = argParser.ParseArgsResult(Opts, Verb);
pub const SubArgs = args.SubProgramArgs(Args);
pub const printHelp = args.GenHelpFn(Opts, "help");

pub const Opts = struct {
    help: bool = false,
    pub const meta = .{
        .usage_summary = "[subcommand]",
        .full_text =
        \\Sub Options:
        \\       init
        ,
        .option_docs = .{
            .help = "print this help message",
        },
    };
    pub const shorthands = .{
        .h = "help",
    };
};
const Verb = union(enum) {
    init: void,
};

const Iter = struct {
    buf: []const []const u8,
    idx: usize = 0,
    pub fn next(self: *Iter) ?[]const u8 {
        if (self.idx == self.buf.len) return null;
        defer self.idx += 1;
        return self.buf[self.idx];
    }
};
pub fn parseArgs(gpa: Allocator, sub_args: []const [:0]const u8) !Args {
    var iter = Iter{ .buf = sub_args };
    const arg = argParser.parseWithVerb(Opts, Verb, &iter, gpa, .silent) catch {
        _ = try printHelp();
        unreachable;
    };
    return arg;
}
pub fn runArgs(gpa: Allocator, sub_args: SubArgs) !u8 {
    _ = gpa;
    if (sub_args.sub_opts.options.help) _ = printHelp() catch return 0;
    if (sub_args.sub_opts.verb == null) {
        _ = args.printHelp() catch return 0;
    }
    switch (sub_args.sub_opts.verb.?) {
        .init => {
            _ = @import("init.zig").printHelp() catch return 0;
        },
    }
    return 0;
}
