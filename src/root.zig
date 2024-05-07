const std = @import("std");
const Allocator = std.mem.Allocator;
const git = @import("git");
pub const Build = @import("Build.zig");
pub const Config = struct {
    target: [:0]u8 = undefined,
    src: ?[:0]u8 = null,
    pub fn destroy(self: *Config, gpa: Allocator) void {
        gpa.free(self.target);
        if (self.src) |d| gpa.free(d);
        gpa.destroy(self);
    }
};

pub inline fn stdErrWriter() std.fs.File.Writer {
    return std.io.getStdErr().writer();
}
pub inline fn stdOutWriter() std.fs.File.Writer {
    return std.io.getStdOut().writer();
}
pub inline fn stdInReader() std.fs.File.Reader {
    return std.io.getStdIn().reader();
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
pub fn getGitRepo(path: ?[]const u8) !git.Repository {
    var buf = try git.repository.discover(path orelse ".", false, null);
    defer buf.destroy();
    return try git.repository.open(buf.slice());
}
pub fn warnNoGitRepo() !u8 {
    const writer = stdErrWriter();
    const str =
        \\ git directory is not initilized.
        \\
        \\ You can initalize a git repository by running:
        \\     
        \\     git init .
        \\
        \\ Or you can initialize the repository and build system by running
        \\
        \\     git build init --repo -d .
        \\
    ;
    try writer.print("{s}", .{str});
    return 1;
}
pub fn warnNoConfig() !u8 {
    const writer = stdErrWriter();
    const str =
        \\ build config does not exist.
        \\
        \\ you can create one by running 
        \\
        \\  git build init
        \\
    ;
    try writer.print("{s}", .{str});
    return 1;
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
    const conf_type = @typeInfo(Config).Struct;
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
    inline for (conf_type.fields) |field| {
        switch (field.type) {
            inline [:0]u8 => {
                const b = conf_snapshot.getString("build." ++ field.name) catch {
                    printGitErr(stdErrWriter()) catch {};
                    return error.ConfigDoesNotExist;
                };

                @field(conf, field.name) = try std.mem.concatWithSentinel(gpa, u8, &.{b}, 0);
            },
            inline ?[:0]u8 => b: {
                const b = conf_snapshot.getString("build." ++ field.name) catch |e| switch (e) {
                    error.NotFound => {
                        @field(conf, field.name) = null;
                        break :b;
                    },
                    else => |err| {
                        std.debug.print("{s}\n", .{@errorName(err)});
                        printGitErr(stdErrWriter()) catch {};
                        return error.ConfigDoesNotExist;
                    },
                };
                @field(conf, field.name) = try std.mem.concatWithSentinel(gpa, u8, &.{b}, 0);
            },
            else => return error.ConfigDoesNotExist,
        }
    }
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
        switch (field.type) {
            inline [:0]u8 => git_conf.setString("build." ++ field.name, @field(config, field.name)) catch {
                printGitErr(stdErrWriter()) catch {};
                return error.ConfigWriteError;
            },
            inline ?[:0]u8 => {
                if (@field(config, field.name) != null) {
                    git_conf.setString("build." ++ field.name, @field(config, field.name).?) catch {
                        printGitErr(stdErrWriter()) catch {};
                        return error.ConfigWriteError;
                    };
                } else {
                    git_conf.deleteEntry("build." ++ field.name) catch |e| switch (e) {
                        error.NotFound => {},
                        else => {
                            printGitErr(stdErrWriter()) catch {};
                            return error.ConfigWriteError;
                        },
                    };
                }
            },
            else => return error.ConfigWriteError,
        }
    }
}
