const std = @import("std");
const git = @import("git");
const Allocator = std.mem.Allocator;
const argParser = @import("args");

const Error = error{
    WrongArg,
} || std.fs.File.Writer.Error || git.Error;
pub fn GenHelpFn(comptime T: type, comptime name: ?[]const u8) fn () Error!u8 {
    const C = struct {
        pub fn write() Error!u8 {
            const writer = std.io.getStdErr().writer();
            try argParser.printHelp(T, "git-build" ++ if (name) |n| " " ++ n else "", writer);
            return error.WrongArg;
        }
    };
    return C.write;
}
pub const printHelp = GenHelpFn(Opts, null);
pub const Args = argParser.ParseArgsResult(Opts, Verbs);
pub const Opts = struct {
    src_dir: ?[]const u8 = null,
    pub const meta = .{
        .usage_summary = "<cmd>",
        .full_text = std.fmt.comptimePrint(help_str, help_fmt_args),
        .option_docs = .{
            .src_dir = "override config src dir",
        },
    };
};
const help_str =
    \\Commands:
    \\  config {s: >3}{s} 
    \\    init {s: >3}{s}
    \\         {s: >3}{s}
    \\    help {s: >3}{s}
;
const help_fmt_args = .{
    " ",
    "Edit a config option",
    " ",
    "Run project initialization script.",
    " ",
    "An optional path may be provided",
    " ",
    "Print this help",
};
pub const Verbs = union(enum) {
    config: struct {},
    init: init.Opts,
    help: help.Opts,
};
pub const Iter = struct {
    params: []const Slice,
    idx: usize = 0,
    pub const Slice = [:0]const u8;
    pub fn next(self: *Iter) ?Slice {
        if (self.idx == self.params.len) return null;
        defer self.idx += 1;
        return self.params[self.idx];
    }
};
const init = @import("init.zig");
const help = @import("help.zig");
const config = @import("config.zig");
pub fn SubProgramArgs(comptime T: type) type {
    return struct {
        global_options: *const Opts,
        sub_opts: *const T,
    };
}
pub fn parseArgs(gpa: Allocator) !Args {
    const args = argParser.parseWithVerbForCurrentProcess(Opts, Verbs, gpa, .print) catch {
        _ = try printHelp();
        unreachable;
    };
    return args;
}

pub fn runArgs(args: *const Args, gpa: Allocator) !u8 {
    if (args.verb == null)
        return printHelp();

    switch (args.verb.?) {
        .config => {
            var conf_args = try config.parseArgs(gpa, args.positionals);
            defer conf_args.deinit();
            return config.runArgs(gpa, .{
                .global_options = &args.options,
                .sub_opts = &conf_args,
            });
        },
        .help => |h| {
            var help_args = try help.parseArgs(gpa, args.positionals);
            defer help_args.deinit();
            help_args.options = h;
            return help.runArgs(gpa, .{
                .global_options = &args.options,
                .sub_opts = &help_args,
            });
        },
        .init => |i| {
            var init_args = try init.parseArgs(gpa, args.positionals);
            defer init_args.deinit();
            init_args.options = i;
            return init.runArgs(gpa, .{
                .global_options = &args.options,
                .sub_opts = &init_args,
            });
        },
    }
    unreachable;
}
