const std = @import("std");
const builtin = @import("builtin");

const Utils = struct {
    file: []const u8,

    pub fn name(self: @This()) []const u8 {
        std.debug.assert(std.mem.endsWith(u8, self.file, ".zig"));
        return self.file[0 .. self.file.len - 4];
    }
};

const utils = [_]Utils{
    .{ .file = "semver.zig" },
};

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    for (utils) |util| {
        const name = util.name();
        const file_path = std.fs.path.join(b.allocator, &[_][]const u8{ "src", util.file }) catch unreachable;
        const exe = b.addExecutable(name, file_path);
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.install();
    }
}
