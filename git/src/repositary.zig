const root = @import("root.zig");
const Error = root.Error;
const Buf = root.Buf;
const git = @cImport({
    @cInclude("git2.h");
});

pub const Repository = struct {
    ptr: *RawRepo,
    pub const RawRepo = git.git_repository;
    const Self = @This();
    pub fn destroy(self: *Self) void {
        git.git_repository_free(self.ptr);
        self.ptr = undefined;
    }
    pub fn path(self: *const Self) []const u8 {
        return git.git_repository_path(self.ptr);
    }
};
pub fn discover(start_path: []const u8, across_fs: bool, ceiling_dirs: ?[]const u8) Error!Buf {
    var b: Buf = undefined;
    const result = git.git_repository_discover(&b.data, @ptrCast(start_path), @intCast(@intFromBool(across_fs)), @ptrCast(ceiling_dirs));
    if (result != 0) return error.RepoHadErr;
    return b;
}
pub fn open(path: []const u8) Error!Repository {
    var repo: Repository = undefined;
    const result = git.git_repository_open(@ptrCast(&repo.ptr), @ptrCast(path));
    if (result != 0) return error.RepoHadErr;
    return repo;
}
