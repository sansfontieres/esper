const std = @import("std");
const builtin = @import("builtin");

const Utils = struct {
    file: []const u8,
    desc: []const u8,

    pub fn name(self: @This()) []const u8 {
        std.debug.assert(std.mem.endsWith(u8, self.file, ".zig"));
        return self.file[0 .. self.file.len - 4];
    }
};

const utils = [_]Utils{
    .{ .file = "semver.zig", .desc = "A git tag bumper following semver" },
    .{ .file = "prompt.zig", .desc = "A shell prompt" },
};

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();
    const install_all = b.step("all", "Compile all, except the prompt (see pick_prompt.rc)");
    for (utils) |util| {
        const name = util.name();
        const file_path = std.fs.path.join(b.allocator, &[_][]const u8{ "src", util.file }) catch unreachable;
        const exe = b.addExecutable(name, file_path);
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.install();
        const install_cmd = b.addInstallArtifact(exe);
        {
            const step_key = b.fmt("{s}", .{name});
            const step_desc = b.fmt("{s}", .{util.desc});
            const install_step = b.step(step_key, step_desc);
            install_step.dependOn(&install_cmd.step);
            if (std.mem.eql(u8, name, "prompt") == false) {
                install_all.dependOn(&install_cmd.step);
            }
        }
    }
}
