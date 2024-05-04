const std = @import("std");
const Allocator = std.mem.Allocator;
const printHelp = @import("../arguments.zig").printHelp;
const argParser = @import("args");
pub const Args = argParser.ParseArgsResult(Opts, Verbs);
pub const Opts = struct {
    src_dir: ?[]const u8 = null,
    pub const meta = .{
        .usage_summary = "<cmd>",
        .full_text = std.fmt.comptimePrint(help_str, help_args),
        .option_docs = .{
            .src_dir = "override config src dir",
        },
    };
};
const help_str =
    \\Commands:
    \\  config {s: >3}{s} 
    \\    help {s: >3}{s}
;
const help_args = .{
    " ",
    "Edit a config option",
    " ",
    "Print this help",
};
pub const Verbs = union(enum) {
    config: struct {},
    help: void,
};
pub fn parseArgs(gpa: Allocator) !Args {
    const args = argParser.parseWithVerbForCurrentProcess(Opts, Verbs, gpa, .print) catch {
        _ = try printHelp(Opts, "git build");
        return undefined;
    };
    return args;
}

pub fn runArgs(args: *const Args, gpa: Allocator) !u8 {
    if (args.verb == null)
        return printHelp(Opts, "git build");

    switch (args.verb.?) {
        .config => return 0,
        .help => _ = printHelp(Opts, "git build") catch |err| switch (err) {
            error.WrongArg => return 0,
            else => |e| return e,
        },
    }
    _ = gpa;
    unreachable;
}
