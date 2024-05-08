pub const std = @import("std");
const Step = @This();
const Build = @import("../Build.zig");
const LazyPath = Build.LazyPath;
const GeneratedFile = Build.GeneratedFile;
pub const Error = e: {
    const File = std.fs.File;
    break :e File.OpenError || File.ReadError || @import("git").Error;
};
pub const MakeFn = fn (*Step) Error!void;

makeFn: MakeFn,
output_file: *const GeneratedFile,
dependencies: std.ArrayList(*Step),

pub fn getOutputFile(self: *Step) LazyPath {
    return .{ .generated = self.output_file };
}

pub fn make(self: *Step) !void {
    for (self.dependencies.items) |dep| {
        try dep.make();
    }
    try self.MakeFn(self);
}

pub const Object = struct {
    step: Step,
    output: GeneratedFile = undefined,
    name: []const u8,
    src_files: ?std.ArrayList(LazyPath) = null,
    command: ?[]const u8 = null,
    pub const ObjectCreateOptions = struct {
        name: []const u8,
        src_files: ?std.ArrayList(LazyPath) = null,
        command: ?[]const u8 = null,
    };
    pub fn init(build: *Build, opts: ObjectCreateOptions) *Object {
        const obj = build.gpa.create(Object) catch {};
        obj.* = .{
            .step = .{
                .makeFn = make_,
                .dependencies = std.ArrayList(*Step).init(build.gpa),
                .output_file = undefined,
            },
            .name = opts.name,
            .src_files = opts.src_files,
            .command = opts.command,
        };
        obj.output = .{ .step = &obj.step };
        obj.step.output_file = &obj.output;
        return obj;
    }
    fn make_(step: *Step) !void {
        _ = step;
    }
};
pub const Binary = struct {
    step: Step,
    output: GeneratedFile,
    name: []const u8,
    inputs: std.ArrayList(LazyPath),
    pub fn init(build: *Build, name: []const u8) Binary {
        const b = build.gpa.create(Binary) catch {};
        b.* = .{
            .step = .{
                .dependencies = std.ArrayList(*Step).init(build.gpa),
                .output_file = undefined,
                .makeFn = make_,
            },
            .output = undefined,
            .name = name,
            .inputs = std.ArrayList(LazyPath).init(build.gpa),
        };
        b.output = .{ .step = &b.step };
        b.step.output_file = &b.output;
        return b;
    }
    fn make_(step: *Step) !void {
        _ = step;
    }
};
