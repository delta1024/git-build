const std = @import("std");
const git = @import("git");
const argsParser = @import("args");
const Options = struct {
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

    // _ = try git.libInit();
    // defer _ = git.libShutdown();
    //
    // var repo_path = try git.repositoryDiscover(".", true, null);
    // defer repo_path.destroy();
    // std.debug.print("{s}\n", .{repo_path.slice()});
    // const repo = try git.repositoryOpen(repo_path.slice());
    // defer repo.free();
}
