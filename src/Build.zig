const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const Dir = std.fs.Dir;
const Cache = @import("Build/Cache.zig");
const Build = @This();

gpa: Allocator,
cache: Cache,
root_dir: fs.Dir,

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
