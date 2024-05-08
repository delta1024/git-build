const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const Dir = std.fs.Dir;
const Cache = @import("Build/Cache.zig");
const Step = @import("Build/Step.zig");
const Build = @This();

gpa: Allocator,
cache: Cache,
root_dir: fs.Dir,

pub const LazyPath = union(enum) {
    src_path: struct {
        owner: *Build,
        sub_path: []const u8,
    },
    generated: *const GeneratedFile,
    pub fn getPath(lp: LazyPath) []const u8 {
        switch (lp) {
            .src_path => |sp| return sp.owner.path(sp.sub_path),
            .geterated => |gf| return gf.path orelse @panic("file not built yet."),
        }
    }
    pub fn addDependency(self: LazyPath, step: *Step) void {
        switch (self) {
            .generated => |g| step.dependencies.append(g.step) catch {},
            else => {},
        }
    }
};
pub const GeneratedFile = struct {
    step: *Step,
    path: ?[]const u8 = null,
};
pub fn init(gpa: Allocator) !Build {
    const root_dir = fs.cwd();
    const manifest_dir = try root_dir.makeOpenPath(Cache.cache_manifest_dir, .{});
    const obj_dir = try root_dir.makeOpenPath(Cache.cache_obj_dir, .{});
    const bin_dir = try root_dir.makeOpenPath(Cache.cache_bin_dir, .{});
    var cache = Cache{
        .gpa = gpa,
        .manifest_dir = manifest_dir,
    };
    cache.addPrefex(.{ .prefix = null, .handle = root_dir });
    cache.addPrefex(.{ .prefix = Cache.cache_obj_dir, .handle = obj_dir });
    cache.addPrefex(.{ .prefix = Cache.cache_bin_dir, .handle = bin_dir });
    return Build{
        .gpa = gpa,
        .root_dir = root_dir,
        .cache = cache,
    };
}
pub fn path(b: *Build, sub_path: []const u8) []const u8 {
    return b.root_dir.realpathAlloc(b.gpa, sub_path) catch {};
}
