const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const app = @import("lib");
const git = @import("git");
const arg = @import("args.zig");
const yazap = @import("yazap");
const App = yazap.App;
const Arg = yazap.Arg;
const Command = yazap.Command;
const ArgMatches = yazap.ArgMatches;

pub const ConfigOpts = union(enum) {
    set: [2][:0]u8,
    get: [:0]u8,
    rm: [:0]u8,
    pub fn deinit(self: ConfigOpts, gpa: Allocator) void {
        switch (self) {
            .set => |s| for (s[0..]) |v| gpa.free(v),
            .get => |g| gpa.free(g),
            .rm => |r| gpa.free(r),
        }
    }
};
pub const Verb = union(enum) {
    set: struct {},
    get: struct {},
    rm: struct {},
};

pub fn populateArgs(main_app: *App, cmd: *Command) !void {
    var set_cmd = main_app.createCommand("set", "set a config value");
    try set_cmd.addArg(Arg.positional("OPTION", null, null));
    try set_cmd.addArg(Arg.positional("VALUE", null, null));
    try cmd.addSubcommand(set_cmd);

    var get_cmd = main_app.createCommand("get", "get a config value");
    try get_cmd.addArg(Arg.positional("OPTION", null, null));
    try cmd.addSubcommand(get_cmd);

    var rm_cmd = main_app.createCommand("rm", "remove a config value");
    try rm_cmd.addArg(Arg.positional("OPTION", null, null));
    try cmd.addSubcommand(rm_cmd);
}
pub fn parseArgs(gpa: Allocator, handle: *App, matches: *const ArgMatches) !ConfigOpts {
    if (matches.subcommandMatches("set")) |set_match| {
        var opt = std.ArrayList(u8).init(gpa);
        errdefer opt.deinit();
        var val = std.ArrayList(u8).init(gpa);
        errdefer val.deinit();
        try opt.appendSlice(set_match.getSingleValue("OPTION").?);
        try val.appendSlice(set_match.getSingleValue("VALUE").?);
        return .{ .set = .{
            try opt.toOwnedSliceSentinel(0),
            try val.toOwnedSliceSentinel(0),
        } };
    } else if (matches.subcommandMatches("get")) |get_match| {
        var opt = std.ArrayList(u8).init(gpa);
        errdefer opt.deinit();
        try opt.appendSlice(get_match.getSingleValue("OPTION").?);
        return .{ .get = try opt.toOwnedSliceSentinel(0) };
    } else if (matches.subcommandMatches("rm")) |rm_match| {
        var opt = std.ArrayList(u8).init(gpa);
        errdefer opt.deinit();
        try opt.appendSlice(rm_match.getSingleValue("OPTION").?);
        try opt.append(0);
        return .{ .rm = try opt.toOwnedSliceSentinel(0) };
    } else {
        _ = try handle.parseFrom(&.{ "config", "-h" });
        try handle.displaySubcommandHelp();
        return error.WrongError;
    }
}

pub fn runArgs(gpa: Allocator, args: ConfigOpts) !u8 {
    if (!try app.gitDirectoryIsInitialized()) {
        return app.warnNoGitRepo();
    }
    var repo = try app.getGitRepo(null);
    defer repo.destroy();
    if (!app.configExists(&repo)) {
        return app.warnNoConfig();
    }
    var config = try app.getConfig(&repo, gpa);
    defer config.destroy(gpa);

    switch (args) {
        .set => |opts| {
            if (mem.eql(u8, opts[0], "target")) {
                gpa.free(config.target);
                config.target = try std.mem.concatWithSentinel(gpa, u8, &.{opts[1]}, 0);
            } else if (mem.eql(u8, opts[0], "src_dir")) {
                if (config.src) |dir| gpa.free(dir);
                config.src = try std.mem.concatWithSentinel(gpa, u8, &.{opts[1]}, 0);
            } else {
                try app.stdErrWriter().print("{s} is not a valid config field", .{opts[0]});
                return 1;
            }
            try app.setConfig(&repo, config);
            return 0;
        },
        .get => |field| {
            if (mem.eql(u8, field, "target")) {
                try app.stdOutWriter().print("{s}: {s}\n", .{ field, config.target });
            } else if (mem.eql(u8, field, "src_dir")) {
                if (config.src) |dir|
                    try app.stdOutWriter().print("{s}: {s}\n", .{ field, dir })
                else
                    try app.stdOutWriter().print("{s} is not set\n", .{field});
            } else {
                try app.stdErrWriter().print("{s} is not a valid config field\n", .{field});
                return 1;
            }
            return 0;
        },
        .rm => |field| {
            if (mem.eql(u8, field, "target")) {
                try app.stdErrWriter().writeAll("cannot remove 'target' option.\n");
                return 1;
            } else if (mem.eql(u8, field, "src_dir")) {
                if (config.src) |dir| gpa.free(dir);
                config.src = null;
            } else {
                try app.stdErrWriter().print("{s} is not a valid config field\n", .{field});
                return 1;
            }
            try app.setConfig(&repo, config);
            return 0;
        },
    }
}
