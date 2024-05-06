const std = @import("std");

const git = @cImport({
    @cInclude("git2.h");
});

pub const Error = @import("error.zig").Error;
const checkErr = @import("error.zig").checkErr;

pub const config = @import("config.zig");
pub const Config = config.Config;
pub const GitError = struct {
    class: i32,
    message: []const u8,
    pub const RawError = git.git_error;
    pub fn init(err: [*c]const RawError) GitError {
        const err_ptr = @as([*:0]const u8, @ptrCast(err.*.message));

        return .{
            .class = err.*.klass,
            .message = err_ptr[0..std.mem.indexOfSentinel(u8, 0, err_ptr)],
        };
    }
    pub fn format(self: GitError, comptime fmt: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        if (fmt.len == 0) @compileError("missing format specifier");

        switch (fmt[0]) {
            's' => try writer.print("{s}", .{self.message}),
            'd' => try writer.print("{d}", .{self.class}),
            else => @compileError("Invalid formating option"),
        }
    }
};
pub fn getLatestError() GitError {
    const err = git.git_error_last();
    return GitError.init(err);
}
pub fn init() Error!u32 {
    const ret = git.git_libgit2_init();
    try checkErr(ret);
    return @intCast(ret);
}
pub fn shutdown() Error!u32 {
    const ret = git.git_libgit2_shutdown();
    try checkErr(ret);
    return @intCast(ret);
}

pub const buf = @import("buf.zig");
pub const Buf = buf.Buf;

pub const repository = @import("repositary.zig");
pub const Repository = repository.Repository;
