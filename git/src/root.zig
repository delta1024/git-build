const std = @import("std");

const git = @cImport({
    @cInclude("git2.h");
});

pub const Error = @import("error.zig").Error;
const checkErr = @import("error.zig").checkErr;

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
