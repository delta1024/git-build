const std = @import("std");

const git = @cImport({
    @cInclude("git2.h");
});

pub const Error = error{
    AllocationFailure,
    RepoHadErr,
};

pub fn init() Error!u32 {
    const ret = git.git_libgit2_init();
    if (ret < 0) return error.RepoHadErr;
    return @intCast(ret);
}
pub fn shutdown() Error!u32 {
    const ret = git.git_libgit2_shutdown();
    if (ret < 0) return error.RepoHadErr;
    return @intCast(ret);
}

pub const buf = @import("buf.zig");
pub const Buf = buf.Buf;

pub const repository = @import("repositary.zig");
pub const Repository = repository.Repository;
