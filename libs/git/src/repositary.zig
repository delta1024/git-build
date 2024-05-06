const root = @import("root.zig");
const Error = root.Error;
const checkErr = @import("error.zig").checkErr;
const Buf = root.Buf;
const Config = root.Config;
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
    pub fn config(self: *const Self) Error!Config {
        var conf: Config = undefined;
        try checkErr(git.git_repository_config(@ptrCast(&conf.ptr), @ptrCast(self.ptr)));
        return conf;
    }
};
pub fn discover(start_path: []const u8, across_fs: bool, ceiling_dirs: ?[]const u8) Error!Buf {
    var b: Buf = undefined;
    const result = git.git_repository_discover(&b.data, @ptrCast(start_path), @intCast(@intFromBool(across_fs)), @ptrCast(ceiling_dirs));
    try checkErr(result);
    return b;
}
pub fn open(path: []const u8) Error!Repository {
    var repo: Repository = undefined;
    const result = git.git_repository_open(@ptrCast(&repo.ptr), @ptrCast(path));
    try checkErr(result);
    return repo;
}
pub const OpenExtOptions = struct {
    no_search: bool = false,
    cross_fs: bool = false,
    open_bare: bool = false,
    no_dotgit: bool = false,
    from_env: bool = false,
};
pub fn openExt(open_repo: bool, path: ?[]const u8, flags: OpenExtOptions, ceiling_dirs: ?[]const u8) Error!Repository {
    var flag: ?git.git_repository_open_flag_t = null;
    if (flags.no_search) {
        if (flag != null)
            flag = flag.? | git.GIT_REPOSITORY_OPEN_NO_SEARCH
        else
            flag = git.GIT_REPOSITORY_OPEN_NO_SEARCH;
    } else if (flags.cross_fs) {
        if (flag != null)
            flag = flag.? | git.GIT_REPOSITORY_OPEN_CROSS_FS
        else
            flag = git.GIT_REPOSITORY_OPEN_CROSS_FS;
    } else if (flags.open_bare) {
        if (flag != null)
            flag = flag.? | git.GIT_REPOSITORY_OPEN_BARE
        else
            flag = git.GIT_REPOSITORY_OPEN_BARE;
    } else if (flags.no_dotgit) {
        if (flag != null)
            flag = flag.? | git.GIT_REPOSITORY_OPEN_NO_DOTGIT
        else
            flag = git.GIT_REPOSITORY_OPEN_NO_DOTGIT;
    } else if (flags.from_env) {
        if (flag != null)
            flag = flag.? | git.GIT_REPOSITORY_OPEN_FROM_ENV
        else
            flag = git.GIT_REPOSITORY_OPEN_FROM_ENV;
    }
    var repo: Repository = undefined;
    const response = git.git_repository_open_ext(if (open_repo) @ptrCast(&repo.ptr) else null, @ptrCast(path), flag.?, @ptrCast(ceiling_dirs));
    if (response == git.GIT_ENOTFOUND) return error.NotFound;
    if (response == -1) return error.GenericErr;
    if (!open_repo) return error.OpenableRepo;
    return repo;
}
pub fn init(path: []const u8, is_bare: bool) Error!Repository {
    var repo: Repository = undefined;
    try checkErr(git.git_repository_init(@ptrCast(&repo.ptr), @ptrCast(path), @intCast(@intFromBool(is_bare))));
    return repo;
}
