const root = @import("root.zig");
const git = @cImport({
    @cInclude("git2.h");
});
const Error = root.Error;
pub const Buf = struct {
    data: RawBuf,
    pub const RawBuf = git.git_buf;
    const Self = @This();
    pub fn grow(self: *Self, target_size: usize) Error!void {
        const res = git.git_buf_grow(&self.data, target_size);
        if (res == -1) return error.AllocationFailure;
    }
    pub fn destroy(self: *Self) void {
        git.git_buf_dispose(&self.data);
    }
    pub fn slice(self: *const Self) []const u8 {
        return self.data.ptr[0..self.data.size];
    }
};
pub fn new(target_size: usize) Error!Buf {
    var buf = Buf{
        .data = .{
            .ptr = null,
            .reserved = undefined,
            .size = 0,
        },
    };
    try buf.grow(target_size);
    return buf;
}
