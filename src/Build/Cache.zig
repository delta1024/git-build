const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const fmt = std.fmt;
const Allocator = std.mem.Allocator;
const Dir = std.fs.Dir;
const Cache = @This();

gpa: Allocator,
manifest_dir: fs.Dir,
hash: HashHelper = .{},
pre_dirs: [prefix_dir_count]Directory = undefined,

prifix_dirs: usize = 0,

const Self = @This();

pub const prefix_dir_count = 3;
pub const Hasher = std.crypto.auth.siphash.SipHash128(1, 3);
pub const hasher_init: Hasher = Hasher.init(&[_]u8{
    0x33, 0x52, 0xa2, 0x84,
    0xcf, 0x17, 0x56, 0x57,
    0x01, 0xbb, 0xcd, 0xe4,
    0x77, 0xd6, 0xf0, 0x60,
});
pub const manifest_header = "0";
pub const bin_digest_len = 16;
pub const hex_digest_len = bin_digest_len * 2;
pub const HexDigest = [hex_digest_len]u8;
pub const BinDigest = [bin_digest_len]u8;
pub const cache_obj_dir = "build/o";
pub const cache_bin_dir = "build/b";
pub const cache_manifest_dir = "build/h";
pub const HashHelper = struct {
    hasher: Hasher = hasher_init,
    pub fn addBytes(self: *HashHelper, bytes: []const u8) void {
        self.hasher.update(std.mem.asBytes(&bytes.len));
        self.hasher.update(bytes);
    }

    pub fn addOptional(self: *HashHelper, val: anytype) void {
        self.hasher.update(mem.asBytes(val != null));
        self.hasher.update(val orelse return);
    }

    pub fn final(self: *HashHelper) HexDigest {
        var bin_digest: BinDigest = undefined;
        self.hasher.final(&bin_digest);

        var out_digest: HexDigest = undefined;
        _ = std.fmt.bufPrint(
            &out_digest,
            "{s}",
            .{std.fmt.fmtSliceHexLower(&bin_digest)},
        );
        return HexDigest;
    }
};
pub const PrefixPath = struct {
    prefix: usize,
    path: []u8,
    pub fn deinit(self: PrefixPath, gpa: Allocator) void {
        gpa.free(self.path);
    }
    pub fn hash(self: PrefixPath) u32 {
        var hasher = hasher_init;
        switch (self.prefix) {
            0 => {},
            1 => hasher.update(cache_obj_dir),
            2 => hasher.update(cache_bin_dir),
            else => unreachable,
        }
        hasher.update(self.path);

        var bin_digest: BinDigest = undefined;
        hasher.final(&bin_digest);

        var out_digest: HexDigest = undefined;
        _ = fmt.bufPrint(
            &out_digest,
            "{s}",
            .{fmt.fmtSliceHexLower(&bin_digest)},
        ) catch unreachable;
        return mem.bytesToValue(u32, &out_digest);
    }
    pub fn getPrefixStr(self: PrefixPath) ?[]const u8 {
        return switch (self.prefix) {
            1 => cache_obj_dir,
            2 => cache_bin_dir,
            else => null,
        };
    }
};
pub const File = struct {
    path: PrefixPath,
    stat: Stat,
    bin_digest: BinDigest,
    contents: ?[]const u8,
    pub const Stat = struct {
        inode: fs.File.INode,
        size: u64,
        mtime: i128,
    };
};
pub const Directory = struct {
    prefix: ?[]const u8,
    handle: fs.Dir,
};
pub const Manifest = @import("Manifest.zig");
pub fn addPrefex(self: *Self, dir: Directory) void {
    self.pre_dirs[self.prifix_dirs] = dir;
    self.prifix_dirs += 1;
}
pub fn prefixes(self: *const Self) []const Directory {
    return self.pre_dirs[0..self.prifix_dirs];
}
pub fn findPrefix(self: *const Self, file_path: []const u8) !PrefixPath {
    const gpa = self.gpa;
    const resolved_path = try fs.path.resolve(gpa, &[_][]const u8{file_path});
    errdefer gpa.free(resolved_path);
    return findPrefexResolved(self, resolved_path);
}
pub fn findPrefexResolved(self: *const Self, resolved_path: []u8) !PrefixPath {
    const gpa = self.gpa;
    const prefix_slice = self.prefixes();
    var i: usize = 1;
    while (i < prefix_slice.len) : (i += 1) {
        const p = prefix_slice[i].prefix.?;
        const sub_path = getPrefixSubpath(gpa, p, resolved_path) catch |err| switch (err) {
            error.NotASubPath => continue,
            else => |e| return e,
        };
        gpa.free(resolved_path);
        return PrefixPath{
            .prefix = i,
            .path = sub_path,
        };
    }
    return PrefixPath{
        .prefix = 0,
        .path = resolved_path,
    };
}
pub fn getPrefixSubpath(allocator: Allocator, prefix: []const u8, path: []u8) ![]u8 {
    const relative = try std.fs.path.relative(allocator, prefix, path);
    errdefer allocator.free(relative);
    var component_iterator = std.fs.path.NativeComponentIterator.init(relative) catch {
        return error.NotASubPath;
    };
    if (component_iterator.root() != null) {
        return error.NotASubPath;
    }

    const first_component = component_iterator.first();
    if (first_component != null and std.mem.eql(u8, first_component.?.name, "..")) {
        return error.NotASubPath;
    }
    return relative;
}
pub fn obtain(self: *Self) Manifest {
    return Manifest{
        .cache = self,
        .hash = self.hash,
        .manifest_file = null,
        .hex_digest = undefined,
        .manifest_dirty = false,
    };
}
pub fn hashFile(file: fs.File, bin_digest: *[Hasher.mac_length]u8) !void {
    var buf: [1024]u8 = undefined;
    var hasher = hasher_init;
    while (true) {
        const bytes_read = try file.read(&buf);
        if (bytes_read == 0) break;
        hasher.update(buf[0..bytes_read]);
    }
    hasher.final(bin_digest);
}
pub fn parsePrefix(self: *Self, p: []const u8) !PrefixPath {
    const path = fs.path.resolve(self.gpa, &.{p});
    const prefix = switch (path[0]) {
        '/' => 0,
        else => p: {
            const exts = std.ComptimeStringMap(u8, .{
                .{ ".o", 1 },
            });
            if (exts.get(fs.path.extension(path))) |pa|
                break :p pa
            else {
                if (mem.containsAtLeast(u8, path, 1, "."))
                    break :p 0
                else
                    break :p 2;
            }
        },
    };
    return .{
        .prefix = prefix,
        .path = self.gpa.dupe(u8, path),
    };
}
