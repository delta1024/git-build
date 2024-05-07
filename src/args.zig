const std = @import("std");
const git = @import("git");
const Allocator = std.mem.Allocator;
const argParser = @import("args");
const yazap = @import("yazap");
const App = yazap.App;
const Arg = yazap.Arg;
const Command = yazap.Command;
const ArgMatches = yazap.ArgMatches;

pub const ProgramOptions = struct {
    opts: Opts = .{},
    cmd: Cmds = undefined,
    pub const Cmds = union(enum) {
        init: init.InitOpts,
        config: config.ConfigOpts,
    };
    pub const Opts = struct {
        src_dir: ?[]u8 = null,
        pub fn deinit(self: Opts, gpa: Allocator) void {
            if (self.src_dir) |f| gpa.free(f);
        }
    };
    pub fn deinit(self: ProgramOptions, gpa: Allocator) void {
        self.opts.deinit(gpa);
        switch (self.cmd) {
            .init => |i| i.deinit(gpa),
            .config => |c| c.deinit(gpa),
        }
    }
};
const init = @import("init.zig");
pub const runInit = init.runArgs;
const config = @import("config.zig");
pub const runConfig = config.runArgs;

pub fn populateArgs(app: *App, gbuild: *Command) !void {
    try gbuild.addArg(Arg.singleValueOption("src_dir", null, "override config src dir"));
    var init_cmd = app.createCommand("init", "initalize a project build");
    try init.populateArgs(&init_cmd);
    try gbuild.addSubcommand(init_cmd);
    var conf_cmd = app.createCommand("config", "modify a config value");
    try config.populateArgs(app, &conf_cmd);
    try gbuild.addSubcommand(conf_cmd);
}
pub fn isValidCmd(str: [:0]const u8) bool {
    return std.ComptimeStringMap(void, .{
        .{ "config", {} },
        .{ "init", {} },
    }).has(str);
}
pub fn parseArgs(gpa: Allocator, app: *App, matches: *const ArgMatches) !ProgramOptions {
    var opts: ProgramOptions = .{};
    if (matches.getSingleValue("src_dir")) |path| {
        opts.opts.src_dir = try gpa.dupe(u8, path);
    }
    if (matches.subcommandMatches("init")) |ini_cmd| {
        opts.cmd = .{ .init = init.parseArgs(gpa, app, &ini_cmd) catch |err| {
            return err;
        } };
    } else if (matches.subcommandMatches("config")) |conf_cmd| {
        opts.cmd = .{ .config = config.parseArgs(gpa, app, &conf_cmd) catch |err| {
            return err;
        } };
    } else {
        try app.displayHelp();
        return error.WrongArg;
    }
    return opts;
}
