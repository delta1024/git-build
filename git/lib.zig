const git = @cImport({
    @cInclude("git2.h");
});
/// Generic return codes
pub const GitErrorCode = enum(c_int) {
    ok = git.GIT_OK,
    @"error" = git.GIT_ERROR,
};
pub const Error = error{
    LibOpenError,
    LibShutdownError,
    RepoOpenError,
    RepoDiscoverError,
};
pub const GitError = struct {
    message: []const u8,
    class: c_int,
};
fn checkErr(comptime val: Error, err: c_int) Error!void {
    if (err < 0) return val;
}

/// Callers should not rely on this to determine whether an error has occurred. For error checking, callers should examine the return codes of libgit2 functions.
///
/// This call can only reliably report error messages when an error has occurred. (It may contain stale information if it is called after a different function that succeeds.)
///
/// The memory for this object is managed by libgit2. It should not be freed.
pub fn gitError() GitError {
    const err = git.git_error_last();
    return .{
        .message = @ptrCast(err.message),
        .class = err.klass,
    };
}
///This function must be called before any other libgit2 function in order to set up global state and threading.
///
/// This function may be called multiple times - it will return the number of times the initialization has been called (including this one) that have not subsequently been shutdown.
///
/// Returns the number of initilizations of the library.
pub fn libInit() Error!usize {
    const result = git.git_libgit2_init();
    try checkErr(error.LibOpenError, result);
    return @intCast(result);
}
/// Clean up the global state and threading context after calling it as many times as git_libgit2_init() was called - it will return the number of remainining initializations that have not been shutdown (after this one).
///
/// Returns the number of remaining initializations of the library, or an error code.
pub fn libShutdown() usize {
    const result = git.git_libgit2_shutdown();
    return @intCast(result);
}
pub const Repository = struct {
    ptr: *git.git_repository,
    pub fn free(self: Repository) void {
        git.git_repository_free(self.ptr);
    }
};
pub fn repositoryOpen(path: []const u8) Error!Repository {
    var repo: ?*git.git_repository = null;
    try checkErr(error.RepoOpenError, git.git_repository_open(&repo, @ptrCast(path)));
    if (repo) |rep|
        return .{ .ptr = rep }
    else
        return error.RepoOpenError;
}
pub fn repositoryDiscover(start_path: []const u8, across_fs: bool, ceiling_dirs: ?[]const u8) Error!GitBuf {
    var buff: git.git_buf = undefined;
    try checkErr(error.RepoDiscoverError, git.git_repository_discover(
        &buff,
        @ptrCast(start_path),
        @intCast(@intFromBool(across_fs)),
        @ptrCast(ceiling_dirs),
    ));
    return .{ .buff = buff };
}
pub const GitBuf = struct {
    buff: git.git_buf,
    pub fn slice(self: *const GitBuf) []const u8 {
        return self.buff.ptr[0 .. self.buff.size + 1];
    }
    pub fn destroy(self: *GitBuf) void {
        git.git_buf_dispose(@ptrCast(&self.buff));
    }
};
