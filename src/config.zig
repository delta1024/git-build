const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const app = @import("lib");
const git = @import("git");
const argParser = @import("args");
const arg = @import("args.zig");

pub const SubArgs = arg.SubProgramArgs(Args);
pub const printHelp = arg.GenHelpFn(Opts, "config");
pub const Args = argParser.ParseArgsResult(Opts, Verb);

const Iter = arg.Iter;
pub const Opts = struct {
    pub const meta = .{
        .usage_summary = "<command> option [value]",
        .full_text =
        \\ commands:
        \\      set      set a config value
        \\      get      view a config value
        \\       rm      remove a config value
        ,
    };
};
pub const Verb = union(enum) {
    set: struct {},
    get: struct {},
    rm: struct {},
};

pub fn parseArgs(gpa: Allocator, vals: []const [:0]const u8) !Args {
    var iter = Iter{ .params = vals };
    return argParser.parseWithVerb(Opts, Verb, &iter, gpa, .print) catch {
        _ = try printHelp();
        unreachable;
    };
}

pub fn runArgs(gpa: Allocator, args: SubArgs) !u8 {
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

    switch (args.sub_opts.verb orelse return printHelp()) {
        .set => {
            if (args.sub_opts.positionals.len != 2) {
                try app.stdErrWriter().writeAll("option 'set' takes a config field and it's value");
                return 1;
            }
            const field = args.sub_opts.positionals[0];
            const value_str = args.sub_opts.positionals[1];
            if (mem.eql(u8, field, "target")) {
                gpa.free(config.target);
                config.target = try gpa.dupeZ(u8, value_str);
            } else {
                try app.stdErrWriter().print("{s} is not a valid config field", .{field});
                return 1;
            }
            try app.setConfig(&repo, config);
            return 0;
        },
        .get => {
            if (args.sub_opts.positionals.len != 1) {
                try app.stdOutWriter().writeAll("option 'get' only take the name of the field to access\n");
                return 1;
            }
            const field = args.sub_opts.positionals[0];
            if (mem.eql(u8, field, "target")) {
                try app.stdOutWriter().print("{s}: {s}\n", .{ field, config.target });
            } else {
                try app.stdErrWriter().print("{s} is not a valid config field\n", .{field});
                return 1;
            }
            return 0;
        },
        .rm => {
            if (args.sub_opts.positionals.len != 1) {
                try app.stdOutWriter().writeAll("option 'rm' only take the name of the field to remove\n");
                return 1;
            }
            const field = args.sub_opts.positionals[0];
            if (std.mem.eql(u8, field, "target")) {
                try app.stdErrWriter().writeAll("cannot remove 'target' option.\n");
                return 1;
            } else {
                try app.stdErrWriter().print("{s} is not a valid config field\n", .{field});
                return 1;
            }
            return 0;
        },
    }
}
