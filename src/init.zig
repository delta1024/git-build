const std = @import("std");
const Allocator = std.mem.Allocator;
const argParser = @import("args");
const args = @import("args.zig");
const Iter = args.Iter;
pub const SubArgs = args.SubProgramArgs(Args);
pub const printHelp = args.GenHelpFn(Opts, "init");
const git = @import("git");
const app = @import("lib");
pub const Args = argParser.ParseArgsResult(Opts, null);
pub const Opts = struct {
    force: bool = false,
    repo: bool = false,
    repo_dir: ?[]const u8 = null,
    pub const shorthands = .{
        .f = "force",
        .d = "repo_dir",
    };
    pub const meta = .{
        .usage_summary = "[options]",
        .option_docs = .{
            .force = "disregard already configured project",
            .repo = "initalize git repository with project",
            .repo_dir = "optional git repository path",
        },
    };
};
pub fn parseArgs(gpa: Allocator, params: []const [:0]const u8) !Args {
    var iter = Iter{ .params = params };
    const sub = argParser.parse(Opts, &iter, gpa, .print) catch {
        _ = try printHelp();
        unreachable;
    };
    return sub;
}
pub fn runArgs(gpa: Allocator, sub_args: SubArgs) !u8 {
    const git_repo_initalized = try app.gitDirectoryIsInitialized();
    const init_repo = sub_args.sub_opts.options.repo;
    const force = sub_args.sub_opts.options.force;
    const repo_starting_dir = sub_args.sub_opts.options.repo_dir orelse ".";

    if (!git_repo_initalized and init_repo) {
        return initalizeRepoAndProject(gpa, repo_starting_dir);
    }
    if (init_repo) {
        const writer = app.stdErrWriter();
        try writer.print("Cannot initilize an already initalized git repo.\nTry dropping the '--repo' option.\n", .{});
        return error.WrongArg;
    }
    if (!git_repo_initalized) {
        return app.warnNoGitRepo();
    }
    const abs_path = try std.fs.cwd().realpathAlloc(gpa, repo_starting_dir);
    defer gpa.free(abs_path);
    var repo = r: {
        var repo_path = git.repository.discover(abs_path, false, null) catch {
            const writer = app.stdErrWriter();
            try app.printGitErr(writer);
            return 1;
        };
        defer repo_path.destroy();
        const cur_repo = git.repository.open(repo_path.slice()) catch {
            const writer = app.stdErrWriter();
            try app.printGitErr(writer);
            return 1;
        };
        break :r cur_repo;
    };
    defer repo.destroy();
    if (!force) {
        if (app.configExists(&repo)) {
            const writer = app.stdErrWriter();
            try writer.print(
                \\ build config already exists.
                \\ to change a config option please use:
                \\
                \\ git build config <get|set|rm> value [new value]
                \\
                \\ to run build initalization again please add the [--force|-f] option to git build init
            , .{});
            return 1;
        }
    }
    return initializeProject(gpa, &repo);
}
fn initalizeRepoAndProject(gpa: Allocator, repo_dir: []const u8) !u8 {
    var repo = git.repository.init(repo_dir, false) catch {
        const writer = app.stdErrWriter();
        try app.printGitErr(writer);
        return 1;
    };
    defer repo.destroy();
    return initializeProject(gpa, &repo);
}
fn initializeProject(gpa: Allocator, repo: *git.Repository) !u8 {
    const stdout = std.io.getStdOut();
    var buf = std.io.bufferedWriter(stdout.writer());
    const writer = buf.writer();
    const reader = std.io.getStdIn().reader();
    var conf: app.Config = undefined;
    var target = std.ArrayList(u8).init(gpa);
    try writer.writeAll("Welcome to git build!\n");
    try writer.writeAll("please enter a target name: ");
    try buf.flush();
    try reader.streamUntilDelimiter(target.writer(), '\n', null);
    try target.append(0);
    conf.target = try target.toOwnedSlice();
    defer gpa.free(conf.target);
    try app.setConfig(repo, &conf);
    return 0;
}
