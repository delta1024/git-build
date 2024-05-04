const std = @import("std");
const fs = std.fs;
const fmt = std.fmt;
const mem = std.mem;
const assert = std.debug.assert;
const Cache = @import("Cache.zig");
const BinDigest = Cache.BinDigest;
const HexDigest = Cache.HexDigest;
const HashHelper = Cache.HashHelper;
const File = Cache.File;
const Hasher = Cache.Hasher;
const hasher_init = Cache.hasher_init;
const manifest_header = Cache.manifest_header;
const hex_digest_len = Cache.hex_digest_len;
const bin_digest_len = Cache.bin_digest_len;
const hashFile = Cache.hashFile;
const Manifest = @This();
pub const manifest_file_max_size = 1000 * 1024 * 1024;
cache: *Cache,
manifest_file: ?fs.File,
files: Files = .{},
hex_digest: HexDigest,
hash: HashHelper,

manifest_dirty: bool,
const PrefixPath = Cache.PrefixPath;
pub const Error = error{InvalidFormat};
pub const Files = std.ArrayHashMapUnmanaged(File, void, FilesContext, false);
pub const FilesContext = struct {
    pub fn hash(_: FilesContext, file: File) u32 {
        return file.path.hash();
    }
    pub fn eql(_: FilesContext, a: File, b: File, _: usize) bool {
        return a.path.hash() == b.path.hash();
    }
};
const FilesAdapter = struct {
    pub fn eql(context: @This(), a: PrefixPath, b: File, _: usize) bool {
        _ = context;
        return a.hash() == b.path.hash();
    }
    pub fn hash(_: @This(), path: PrefixPath) u32 {
        return path.hash();
    }
};
pub fn addFile(self: *Manifest, path: []const u8) !usize {
    const gpa = self.cache.gpa;
    try self.files.ensureUnusedCapacity(gpa, 1);
    const prefix = try self.cache.findPrefix(path);
    errdefer gpa.free(prefix.path);

    const gop = self.files.getOrPutAssumeCapacityAdapted(prefix, FilesAdapter{});

    if (gop.found_existing) {
        return gop.index;
    }

    gop.key_ptr.* = .{
        .path = prefix,
        .contents = null,
        .bin_digest = undefined,
        .stat = undefined,
    };
    self.hash.hasher.update(&mem.toBytes(prefix.prefix));
    self.hash.addBytes(prefix.path);
    return gop.index;
}

pub fn hit(self: *Manifest) !bool {
    assert(self.manifest_file == null);
    const gpa = self.cache.gpa;
    // retreve the current hash and store on stack
    var bin_digest: BinDigest = undefined;
    self.hash.hasher.final(&bin_digest);
    _ = fmt.bufPrint(
        &self.hex_digest,
        "{s}",
        .{fmt.fmtSliceHexLower(&bin_digest)},
    ) catch unreachable;

    self.hash.hasher = hasher_init;
    self.hash.hasher.update(&bin_digest);
    const ext = ".txt";

    // calculate the manifest file name.
    var manifest_file_path: [hex_digest_len + ext.len]u8 = undefined;
    @memcpy(manifest_file_path[0..hex_digest_len], &self.hex_digest);
    manifest_file_path[hex_digest_len..][0..ext.len].* = ext.*;

    if (self.cache.manifest_dir.createFile(&manifest_file_path, .{
        .read = true,
        .truncate = false,
        .lock = .exclusive,
    })) |manifest_file| {
        self.manifest_file = manifest_file;
    } else |err| switch (err) {
        error.WouldBlock => {
            self.manifest_file = try self.cache.manifest_dir.openFile(&manifest_file_path, .{
                .mode = .read_write,
                .lock = .shared,
            });
        },
        else => |e| return e,
    }

    const manifest_file_contents = try self.manifest_file.?.readToEndAlloc(gpa, manifest_file_max_size);
    defer gpa.free(manifest_file_contents);

    var line_iter = mem.tokenizeScalar(u8, manifest_file_contents, '\n');
    var idx: usize = 0;

    if (if (line_iter.next()) |line| !mem.eql(u8, line, manifest_header) else false) {
        self.manifest_dirty = true;
        for (self.files.keys()) |*key| {
            try self.populateFileHash(key);
        }
        return false;
    }
    const input_file_count = self.files.count();
    var file_changed = false;
    // Iterate through each line and do the following:
    while (line_iter.next()) |line| {
        defer idx += 1;

        var iter = mem.tokenizeScalar(u8, line, ' ');

        const size = iter.next() orelse return error.InvalidFormat;

        const inode_str = iter.next() orelse return error.InvalidFormat;
        const mtime_nanosec_str = iter.next() orelse return error.InvalidFormat;
        const digest_str = iter.next() orelse return error.InvalidFormat;
        const prefix_str = iter.next() orelse return error.InvalidFormat;
        const file_path = iter.rest();

        const stat_size = fmt.parseInt(u64, size, 10) catch return error.InvalidFormat;
        const stat_inode = fmt.parseInt(fs.File.INode, inode_str, 10) catch return error.InvalidFormat;
        const stat_mtime = fmt.parseInt(i64, mtime_nanosec_str, 10) catch return error.InvalidFormat;
        const file_bin_digest = b: {
            var bd: BinDigest = undefined;
            _ = fmt.hexToBytes(&bd, digest_str) catch return error.InvalidFormat;
            break :b bd;
        };

        const prefix = fmt.parseInt(usize, prefix_str, 10) catch return error.InvalidFormat;
        if (prefix >= self.cache.prifix_dirs) return error.InvalidFormat;

        if (file_path.len == 0) return error.InvalidFormat;

        const cache_hash_file = f: {
            const prefex_path: PrefixPath = .{
                .prefix = prefix,
                .path = try gpa.dupe(u8, file_path),
            };
            defer gpa.free(prefex_path.path);

            if (idx < input_file_count) {
                const file = &self.files.keys()[idx];
                if (file.path.hash() != prefex_path.hash()) {
                    return error.InvalidFormat;
                }

                file.stat = .{
                    .size = stat_size,
                    .inode = stat_inode,
                    .mtime = stat_mtime,
                };
                file.bin_digest = file_bin_digest;
                break :f file;
            }

            const gop = try self.files.getOrPutAdapted(gpa, prefex_path, FilesAdapter{});
            errdefer _ = self.files.pop();

            if (!gop.found_existing) {
                gop.key_ptr.* = .{
                    .path = .{
                        .prefix = prefix,
                        .path = try gpa.dupe(u8, file_path),
                    },
                    .contents = null,
                    .stat = .{
                        .size = stat_size,
                        .inode = stat_inode,
                        .mtime = stat_mtime,
                    },
                    .bin_digest = file_bin_digest,
                };
            }
            break :f gop.key_ptr;
        };

        const pp = cache_hash_file.path;
        const dir = self.cache.pre_dirs[pp.prefix].handle;
        const this_file = dir.openFile(pp.path, .{ .mode = .read_only }) catch |err| switch (err) {
            error.FileNotFound => {
                self.manifest_dirty = true;
                return false;
            },
            else => |e| return e,
        };
        defer this_file.close();

        const stat = try this_file.stat();

        const fsize = cache_hash_file.stat.size == stat.size;
        const finode = cache_hash_file.stat.inode == stat.inode;
        const fmtime = cache_hash_file.stat.mtime == stat.mtime;

        if (!fsize or !finode or !fmtime) {
            self.manifest_dirty = true;
            cache_hash_file.stat = .{
                .size = stat.size,
                .mtime = stat.mtime,
                .inode = stat.inode,
            };

            var this_file_digest: BinDigest = undefined;
            try hashFile(this_file, &this_file_digest);

            if (!mem.eql(u8, &cache_hash_file.bin_digest, &this_file_digest)) {
                cache_hash_file.bin_digest = this_file_digest;
                file_changed = true;
            }
        }
        if (!file_changed) {
            self.hash.hasher.update(&cache_hash_file.bin_digest);
        }
    }
    if (file_changed) {
        self.unhit(bin_digest, input_file_count);
        return false;
    }
    if (idx < input_file_count) {
        self.manifest_dirty = true;
        while (idx < input_file_count) : (idx += 1) {
            try self.populateFileHash(&self.files.keys()[idx]);
        }
        return false;
    }
    return true;
}
pub fn unhit(self: *Manifest, bin_digest: BinDigest, input_file_count: usize) void {
    // Reset the hash.
    self.hash.hasher = hasher_init;
    self.hash.hasher.update(&bin_digest);

    // Remove files not in the initial hash
    while (self.files.count() != input_file_count) {
        const file = self.files.pop();
        file.key.path.deinit(self.cache.gpa);
    }

    for (self.files.keys()) |key| {
        self.hash.addBytes(&key.bin_digest);
    }
}
fn populateFileHash(self: *Manifest, ch_file: *File) !void {
    const pp = ch_file.path;
    const dir = self.cache.pre_dirs[pp.prefix].handle;
    const file = try dir.openFile(pp.path, .{});
    defer file.close();

    const actual_stat = try file.stat();
    ch_file.stat = .{
        .size = actual_stat.size,
        .mtime = actual_stat.mtime,
        .inode = actual_stat.inode,
    };

    try hashFile(file, &ch_file.bin_digest);

    self.hash.hasher.update(&ch_file.bin_digest);
}

pub fn writeManifest(self: *Manifest) !void {
    const manifest_file = self.manifest_file.?;

    if (self.manifest_dirty) {
        self.manifest_dirty = false;

        var contents = std.ArrayList(u8).init(self.cache.gpa);
        defer contents.deinit();

        const writer = contents.writer();
        try writer.writeAll(manifest_header ++ "\n");
        for (self.files.keys()) |file| {
            try writer.print("{d} {d} {d} {} {d} {s}\n", .{
                file.stat.size,
                file.stat.inode,
                file.stat.mtime,
                fmt.fmtSliceHexLower(&file.bin_digest),
                file.path.prefix,
                file.path.path,
            });
        }

        try manifest_file.setEndPos(contents.items.len);
        try manifest_file.pwriteAll(contents.items, 0);
    }
}
pub fn final(self: *Manifest) HexDigest {
    assert(self.manifest_file != null);
    var bin_digest: BinDigest = undefined;
    self.hash.hasher.final(&bin_digest);

    var out_digest: HexDigest = undefined;
    _ = fmt.bufPrint(
        &out_digest,
        "{s}",
        .{fmt.fmtSliceHexLower(&bin_digest)},
    ) catch unreachable;
    return out_digest;
}
pub fn deinit(self: *Manifest) void {
    const gpa = self.cache.gpa;
    if (self.manifest_file) |file| file.close();
    while (self.files.popOrNull()) |kv| gpa.free(kv.key.path.path);
    self.files.deinit(gpa);
}
