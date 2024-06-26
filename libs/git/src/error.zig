const git = @cImport({
    @cInclude("git2.h");
});

pub const Error = error{
    /// Generic error
    Error,
    /// Requested object could not be found
    NotFound,
    /// Object exists preventing operation
    Exists,
    /// More than one object matches
    Ambiguous,
    /// Output buffer too short to hold data
    Bufs,
    User,
    BareRepo,
    UnBornBranch,
    UnMerged,
    NonFastForward,
    InvalidSpec,
    Conflict,
    Locked,
    Modified,
    Auth,
    Certificate,
    Applied,
    Peel,
    Eof,
    Invalid,
    UnCommited,
    Directory,
    MergeConflict,
    PassThrough,
    IterOver,
    Retry,
    MisMatch,
    IndexDirty,
    ApplyFail,
    Owner,
    TimeOut,
    UnChanged,
    NotSupported,
    ReadOnly,
    AllocationFailure,
    GenericErr,
    OpenableRepo,
};
pub fn checkErr(maybe_err: c_int) Error!void {
    return switch (maybe_err) {
        git.GIT_ERROR => error.Error,
        git.GIT_ENOTFOUND => error.NotFound,
        git.GIT_EAMBIGUOUS => error.Ambiguous,
        git.GIT_EBUFS => error.Bufs,
        git.GIT_EUSER => error.User,
        git.GIT_EBAREREPO => error.BareRepo,
        git.GIT_EUNBORNBRANCH => error.UnBornBranch,
        git.GIT_EUNMERGED => error.UnMerged,
        git.GIT_ENONFASTFORWARD => error.NonFastForward,
        git.GIT_EINVALIDSPEC => error.InvalidSpec,
        git.GIT_ECONFLICT => error.Conflict,
        git.GIT_ELOCKED => error.Locked,
        git.GIT_EMODIFIED => error.Modified,
        git.GIT_EAUTH => error.Auth,
        git.GIT_ECERTIFICATE => error.Certificate,
        git.GIT_EAPPLIED => error.Applied,
        git.GIT_EPEEL => error.Peel,
        git.GIT_EEOF => error.Eof,
        git.GIT_EINVALID => error.Invalid,
        git.GIT_EUNCOMMITTED => error.UnCommited,
        git.GIT_EDIRECTORY => error.Directory,
        git.GIT_EMERGECONFLICT => error.MergeConflict,
        git.GIT_PASSTHROUGH => error.PassThrough,
        git.GIT_ITEROVER => error.IterOver,
        git.GIT_RETRY => error.Retry,
        git.GIT_EMISMATCH => error.MisMatch,
        git.GIT_EINDEXDIRTY => error.IndexDirty,
        git.GIT_EAPPLYFAIL => error.ApplyFail,
        git.GIT_EOWNER => error.Owner,
        git.GIT_TIMEOUT => error.TimeOut,

        else => {},
    };
}
