const std = @import("std");
const Allocator = std.mem.Allocator;
const args = @import("args.zig");
const git = @import("git");
const app = @import("lib");
const yazap = @import("yazap");
const Command = yazap.Command;
const App = yazap.App;
const ArgMatch = yazap.ArgMatches;
const Arg = yazap.Arg;

pub const InitOpts = struct {
    force: bool = false,
    repo: bool = false,
    repo_dir: ?[]u8 = null,
    pub fn deinit(self: InitOpts, gpa: Allocator) void {
        if (self.repo_dir) |repo_dir|
            gpa.free(repo_dir);
    }
};
pub fn populateArgs(cmd: *Command) !void {
    var arg: [3]Arg = .{
        Arg.singleValueOption("repo_dir", 'D', "path to the directory to initilize"),
        Arg.booleanOption("force", 'f', "disregard an already configured project."),
        Arg.booleanOption("repo", null, "initalize git repository as well as project. If -D is not supplied cwd is used."),
    };
    try cmd.addArgs(&arg);
}
pub fn parseArgs(gpa: Allocator, prog_app: *App, matches: *const ArgMatch) !InitOpts {
    _ = prog_app;
    var opt = InitOpts{};
    opt.repo = matches.containsArg("repo");
    opt.force = matches.containsArg("force");
    if (matches.getSingleValue("repo_dir")) |repo_dir|
        opt.repo_dir = try gpa.dupe(u8, repo_dir);
    return opt;
}
pub fn runArgs(gpa: Allocator, sub_args: InitOpts) !u8 {
    const git_repo_initalized = try app.gitDirectoryIsInitialized();
    const init_repo = sub_args.repo;
    const force = sub_args.force;
    const repo_starting_dir = sub_args.repo_dir orelse ".";

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
    const abs_path = p: {
        const path = try std.fs.cwd().realpathAlloc(gpa, repo_starting_dir);
        var buf = std.ArrayList(u8).init(gpa);
        buf.items = path;
        buf.capacity = path.len;
        break :p try buf.toOwnedSliceSentinel(0);
    };
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
                \\
                \\ to change a config option please use:
                \\
                \\
                \\ git build config <get|set|rm> value [new value]
                \\
                \\
                \\ to run build initalization again please add the [--force|-f] option 
                \\
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
    var conf: app.Config = .{};
    var target = std.ArrayList(u8).init(gpa);
    try writer.writeAll("Welcome to git build!\n");
    try writer.writeAll("please enter a target name: ");
    try buf.flush();
    try reader.streamUntilDelimiter(target.writer(), '\n', null);
    conf.target = try target.toOwnedSliceSentinel(0);
    defer gpa.free(conf.target);
    try writer.writeAll("optional src dir (src): ");
    try buf.flush();
    try reader.streamUntilDelimiter(target.writer(), '\n', null);
    if (target.items.len != 0) {
        conf.src = try target.toOwnedSliceSentinel(0);
    }
    defer if (conf.src) |b| gpa.free(b);
    try app.setConfig(repo, &conf);
    return 0;
}
