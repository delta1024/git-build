const std = @import("std");
const git = @import("git");
pub fn main() !void {
    _ = try git.libInit();
    _ = git.libShutdown();
    const repo = try git.repositoryOpen(".");
    defer repo.free();
}
