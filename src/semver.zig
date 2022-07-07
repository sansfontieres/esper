const std = @import("std");
const stdout = std.io.getStdOut().writer();

const ChildProcessFailed = error.ChildProcessFailed;

const Version = struct {
    major: u32 = 0,
    minor: u32 = 1, // We initialize the first version bump
    patch: u32 = 0,
    modified: bool = false,
};

const Options = struct {
    print: bool = false,
};

fn runChildProcess(allocator: std.mem.Allocator, argv: []const []const u8) anyerror!std.ChildProcess.ExecResult {
    return try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = argv,
    });
}

fn getTag(allocator: std.mem.Allocator) anyerror![]const u8 {
    var tag: []const u8 = undefined;
    const cmd = try runChildProcess(allocator, &[_][]const u8{
        "git",
        "describe",
        "--abbrev=0",
    });

    switch (cmd.term) {
        .Exited => |code| if (code == 0) {
            tag = cmd.stdout;
        } else {
            std.debug.print("No tag found, initializing at 0.1\n", .{});
            tag = "0.1";
        },
        else => return ChildProcessFailed,
    }
    return tag;
}

fn getVersion(tag: []const u8) anyerror!Version {
    var version: Version = .{};
    var tokens = std.mem.tokenize(u8, tag, ".");
    var i: u32 = 1;
    while (tokens.next()) |token| {
        try switch (i) {
            1 => version.major = try std.fmt.parseUnsigned(u32, token, 10),
            2 => version.minor = try std.fmt.parseUnsigned(u32, token, 10),
            3 => version.patch = try std.fmt.parseUnsigned(u32, token, 10),
            else => error.NotSemVer,
        };
        i += 1;
    }
    return version;
}

fn getShortlog(allocator: std.mem.Allocator, tag: []const u8) anyerror![]const u8 {
    var logs: []const u8 = undefined;

    const cmd = try runChildProcess(allocator, &[_][]const u8{
        "git",
        "shortlog",
        "--no-merges",
        try std.fmt.allocPrint(allocator, "{s}..HEAD", .{tag}),
    });
    switch (cmd.term) {
        .Exited => |code| if (code == 0) {
            logs = cmd.stdout;
        } else {
            std.debug.print("No previous logs found...\n", .{});
            logs = "Init";
        },
        else => return ChildProcessFailed,
    }
    return logs;
}

fn isInGit_directory(allocator: std.mem.Allocator) anyerror!void {
    const cmd = try runChildProcess(allocator, &[_][]const u8{
        "git",
        "rev-parse",
        "--abbrev-ref",
        "HEAD",
    });

    switch (cmd.term) {
        .Exited => |code| if (code != 0) {
            return error.NotInAGitRepository;
        },
        else => return ChildProcessFailed,
    }

    if (!std.mem.eql(u8, cmd.stdout, "front\n")) { // The main branch is front
        return error.NotInFrontBranch;
    }
}

fn addTag(allocator: std.mem.Allocator, version: Version, options: Options, shortlog: []const u8) anyerror!void {
    var tag: []const u8 = undefined;
    tag = try std.fmt.allocPrint(allocator, "{d}.{d}", .{ version.major, version.minor });

    if (version.patch > 0) { // We skip patch number if it’s zero
        tag = try std.mem.concat(
            allocator,
            u8,
            &[_][]const u8{ tag, ".", try std.fmt.allocPrint(allocator, "{d}", .{version.patch}) },
        );
    }

    if (options.print) {
        std.debug.print("{s}\n{s}\n", .{ tag, shortlog });
        return;
    }

    const shortlog_file = try std.fs.cwd().createFile(tag, .{});
    try shortlog_file.writer().print("{s}\n\n{s}\n", .{ tag, shortlog });
    defer {
        shortlog_file.close();
        std.fs.cwd().deleteFile(tag) catch {};
    }

    std.debug.print("Bumping to version {s}\n", .{tag});

    var cmd = std.ChildProcess.init(&[_][]const u8{
        "git",
        "tag",
        "-a",
        tag,
        "-e",
        "-F",
        tag,
    }, allocator);

    try cmd.spawn();
    _ = try cmd.wait();
}

fn parseArgs(args: [][]u8, version: *Version, options: *Options) anyerror!void {
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "patch")) {
            version.patch += 1;
            version.modified = true;
        }
        if (std.mem.eql(u8, arg, "minor")) {
            version.minor += 1;
            version.modified = true;
        }
        if (std.mem.eql(u8, arg, "major")) {
            version.major += 1;
            version.modified = true;
        }
        if (std.mem.eql(u8, arg, "print")) {
            options.print = true;
        }
    }
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    var options: Options = .{};

    _ = try isInGit_directory(allocator);

    var tag = std.mem.trimRight(u8, try getTag(allocator), "\n");

    var version = try getVersion(tag);

    var shortlog = try getShortlog(allocator, tag);

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try parseArgs(args, &version, &options);

    if (version.modified) {
        try addTag(allocator, version, options, shortlog);
    } else {
        std.debug.print("No update provided\n", .{});
    }
}
