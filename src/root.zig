const std = @import("std");
const Allocator = std.mem.Allocator;
const git = @import("git");
pub const Build = @import("Build.zig");
pub const Config = struct {
    target: []u8,
    pub fn destroy(self: *Config, gpa: Allocator) void {
        gpa.free(self.target);
        gpa.destroy(self);
        self.* = undefined;
    }
};

pub inline fn stdErrWriter() std.fs.File.Writer {
    return std.io.getStdErr().writer();
}
pub fn printGitErr(writer: anytype) !void {
    const err = git.getLatestError();
    try writer.print("git error: {s}\n", .{err});
}
pub fn gitDirectoryIsInitialized() !bool {
    _ = git.repository.openExt(false, ".", .{ .no_search = true }, null) catch |err| switch (err) {
        error.NotFound => return false,
        error.OpenableRepo => return true,
        else => {
            const e = git.getLatestError();
            try std.io.getStdErr().writer().print("{s}\n", .{e});
            std.process.exit(1);
        },
    };
    unreachable;
}
pub fn configExists(repo: *git.Repository) bool {
    const git_conf = repo.config() catch {
        printGitErr(stdErrWriter()) catch {};
        return false;
    };
    defer git_conf.deinit();
    const conf_snapshot = git_conf.snapshot() catch {
        printGitErr(stdErrWriter()) catch {};
        return false;
    };
    defer conf_snapshot.deinit();
    _ = conf_snapshot.getString("build.target") catch |err| switch (err) {
        error.NotFound => return false,
        else => {
            printGitErr(stdErrWriter()) catch {};
            return false;
        },
    };
    return true;
}
pub const ConfigDoesNotExist = error{
    ConfigDoesNotExist,
};
pub fn getConfig(repo: *git.Repository, gpa: Allocator) (ConfigDoesNotExist || error{OutOfMemory})!*Config {
    const conf = try gpa.create(Config);
    errdefer gpa.destroy(conf);
    const git_conf = repo.config() catch {
        printGitErr(stdErrWriter()) catch {};
        return error.ConfigDoesNotExist;
    };
    defer git_conf.deinit();
    const conf_snapshot = git_conf.snapshot() catch {
        printGitErr(stdErrWriter()) catch {};
        return error.ConfigDoesNotExist;
    };
    defer conf_snapshot.deinit();
    const target = conf_snapshot.getString("build.target") catch {
        printGitErr(stdErrWriter()) catch {};
        return error.ConfigDoesNotExist;
    };
    conf.* = .{
        .target = try gpa.dupe(u8, target),
    };
    return conf;
}
pub const ConfigWriteError = error{
    ConfigWriteError,
};
pub fn setConfig(repo: *git.Repository, config: *const Config) ConfigWriteError!void {
    var git_conf = repo.config() catch {
        printGitErr(stdErrWriter()) catch {};
        return error.ConfigWriteError;
    };
    defer git_conf.deinit();
    const conf_type_info = @typeInfo(Config).Struct;
    inline for (conf_type_info.fields) |field| {
        git_conf.setString("build." ++ field.name, @field(config, field.name)) catch {
            printGitErr(stdErrWriter()) catch {};
            return error.ConfigWriteError;
        };
    }
}
