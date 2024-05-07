const std = @import("std");
const git = @import("git");
const args = @import("args.zig");
const yazap = @import("yazap");
const App = yazap.App;
const Arg = yazap.Arg;
const lib = @import("lib");
pub fn main() !u8 {
    _ = try git.init();
    defer _ = git.shutdown() catch {};
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();
    var app = App.init(allocator, "git-build", "A build system built around git");
    defer app.deinit();
    const gbuild = app.rootCommand();
    try args.populateArgs(&app, gbuild);
    const matches = app.parseProcess() catch {
        const cmd = app.process_args.?[1];
        const check = std.ComptimeStringMap(void, .{
            .{ "config", {} },
            .{ "init", {} },
        });
        if (check.has(cmd)) {
            _ = try app.parseFrom(&.{ cmd, "-h" });
            try app.displaySubcommandHelp();
        } else {
            try app.displayHelp();
        }
        return 1;
    };
    const options = args.parseArgs(allocator, &app, matches) catch |err| switch (err) {
        error.WrongArg => {
            return 1;
        },

        else => |e| return e,
    };
    defer options.deinit(allocator);
    switch (options.cmd) {
        .init => |init| return args.runInit(allocator, init),
        .config => |conf| return args.runConfig(allocator, conf),
        .no_opt => unreachable,
    }
    return 0;
}
