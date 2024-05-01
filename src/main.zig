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
    pub const Opts = struct {
        help: bool = false,
        pub const meta = .{
            .usage_summary = " [cmd|--help]",
            .full_text =
            \\Commands:
            \\print  Print a fun message
            ,
            .option_docs = .{
                .help = "print help",
            },
        };
    };
    pub const Verbs = union(enum) {
        print: void,
    };
};
fn printHelp() u8 {
    argsParser.printHelp(Options.Opts, "git-build", std.io.getStdErr().writer()) catch {};
    return 1;
}
pub fn main() !u8 {
    _ = try git.init();
    defer _ = git.shutdown() catch |err| @panic(@errorName(err));
    var repo_path = try git.repository.discover(".", false, null);
    defer repo_path.destroy();

    std.debug.print("{s}\n", .{repo_path.slice()});
    var repo = try git.repository.open(repo_path.slice());
    defer repo.destroy();
    return 0;
}
