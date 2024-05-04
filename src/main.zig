const std = @import("std");
const git = @import("git");
const argsParser = @import("args");
const Options = struct {
    // const argsAllocator = std.heap.page_allocator;
    // const options = argsParser.parseWithVerbForCurrentProcess(Options.Opts, Options.Verbs, argsAllocator, .print) catch return printHelp();
    // if (options.options.help) {
    //     _ = printHelp();
    //     return 0;
    // }
    // if (options.verb) |verb| switch (verb) {
    //     .print => std.debug.print("hello", .{}),
    // };
    // try argsParser.printHelp(Options.Opts, "git-build", std.io.getStdErr().writer());
    // return 1;
    // /
    pub const Opts = struct {
        help: bool = false,
        pub const meta = .{
            .usage_summary = " [cmd|--help]",
            .full_text = 
            \\Commands:
            \\
            ++ Verbs.desc,

            .option_docs = .{
                .help = "print help",
            },
        };
    };
    pub const Verbs = union(enum) {
        pub const desc = "print  Print a fun message";
        print: void,
    };
};
fn printHelp() u8 {
    argsParser.printHelp(Options.Opts, "git-build", std.io.getStdErr().writer()) catch {};
    return 1;
}
const Build = @import("Build.zig");
pub fn main() !u8 {
    const gpa = std.heap.page_allocator;
    var build = try Build.init(gpa);
    const cache = &build.cache;
    var man = cache.obtain();
    defer man.deinit();
    _ = try man.addFile("src/main.zig");
    _ = try man.addFile("src/Build.zig");
    if (try man.hit()) {
        std.debug.print("hit\n", .{});
    } else {
        try man.writeManifest();
    }
    return 0;
}
