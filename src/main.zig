const std = @import("std");
const Allocator = std.mem.Allocator;
const git = @import("git");
const args = @import("args.zig");
const yazap = @import("yazap");
const App = yazap.App;
const Arg = yazap.Arg;
const lib = @import("lib");
fn setupAppOptions(app: *App, gpa: Allocator) !args.ProgramOptions {
    const gbuild = app.rootCommand();
    try args.populateArgs(&app, gbuild);
    const matches = app.parseProcess() catch {
        const cmd = app.process_args.?[1];
        if (args.isValidCmd(cmd)) {
            _ = try app.parseFrom(&.{ cmd, "-h" });
            try app.displaySubcommandHelp();
        } else {
            try app.displayHelp();
        }
        return error.WrongArg;
    };
    return args.parseArgs(gpa, &app, matches);
}
pub fn main() !u8 {
    _ = try git.init();
    defer _ = git.shutdown() catch {};
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();
    var app = App.init(allocator, "git-build", "A build system built around git");
    defer app.deinit();
    const options = setupAppOptions(&app, allocator) catch |e| switch (e) {
        error.WrongArg => return 1,
        else => |err| return err,
    };
    defer options.deinit(allocator);
    switch (options.cmd) {
        .init => |init| return args.runInit(allocator, init),
        .config => |conf| return args.runConfig(allocator, conf),
    }
    return 0;
}
