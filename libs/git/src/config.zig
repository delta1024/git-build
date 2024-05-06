const std = @import("std");
const git = @cImport({
    @cInclude("git2.h");
});
const checkErr = @import("error.zig").checkErr;
const Error = @import("error.zig").Error;
pub const Config = struct {
    pub const GitType = git.git_config;
    ptr: *GitType,
    pub fn deinit(self: Config) void {
        git.git_config_free(@ptrCast(self.ptr));
    }
    pub fn snapshot(self: Config) !Config {
        var out: Config = undefined;
        try checkErr(git.git_config_snapshot(@ptrCast(&out.ptr), @ptrCast(self.ptr)));
        return out;
    }
    pub fn getString(self: *const Config, name: []const u8) Error![]const u8 {
        var out: [*c]const u8 = undefined;
        try checkErr(git.git_config_get_string(@ptrCast(&out), @ptrCast(self.ptr), @ptrCast(name)));
        const ptr = @as([*:0]const u8, @ptrCast(out));
        return ptr[0..std.mem.indexOfSentinel(u8, 0, ptr)];
    }
    pub fn setString(self: *Config, name: []const u8, value: []const u8) !void {
        try checkErr(git.git_config_set_string(@ptrCast(self.ptr), @ptrCast(name), @ptrCast(value)));
    }
    pub fn deleteEntry(self: *Config, name: []const u8) Error!void {
        try checkErr(git.git_config_delete_entry(@ptrCast(self.ptr), @ptrCast(name)));
    }
};
