//! A simple shell prompt with an optionnal hostname if it’s a remote session,
//! and a colored prompt symbol on exit code != 0.
//! I use it with zsh, for any other shell, you would have to replace
//! “%{” and “%}” pairs with what pleases your shell.
//! The prompt symbol is a semicolon, so I can copy/paste whole lines of
//! commands without throwing an error.
//! Usage: prompt [<exit_code>]
const std = @import("std");

pub fn main() anyerror!void {
    var stdout = std.io.getStdOut().writer();

    //  added arround escape codes to please both zsh and zig
    try stdout.print("%{{\x1B[32m%}}", .{});

    if (std.os.getenv("SSH_CONNECTION")) |_| {
        var host_buff: [std.os.HOST_NAME_MAX]u8 = undefined;
        var host = std.os.gethostname(&host_buff) catch undefined;
        try stdout.print("{s}:", .{host});
    }

    const home = std.os.getenv("HOME");
    var cwd_buff: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var cwd = std.os.getcwd(&cwd_buff) catch undefined;

    var rel_home = blk: {
        var b = false;
        if (home.?.len <= cwd.len) {
            b = std.mem.eql(u8, home.?, cwd[0..home.?.len]);
        }
        break :blk b;
    };

    if (rel_home) {
        try stdout.print("~{s}", .{cwd[home.?.len..]});
    } else {
        try stdout.print("{s}", .{cwd});
    }

    try stdout.print("%{{\x1B[0m%}}", .{});

    var arg: []const u8 = undefined;
    if (std.mem.len(std.os.argv) > 1) {
        arg = std.mem.span(std.os.argv[1]);
    } else {
        arg = "0";
    }

    var code = std.fmt.parseInt(u32, arg, 10) catch 0;
    if (code == 0) {
        try stdout.print("; ", .{});
    } else {
        try stdout.print("%{{\x1B[31m%}};%{{\x1B[0m%}} ", .{});
    }
}
