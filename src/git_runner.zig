const std = @import("std");

pub fn runGit(allocator: std.mem.Allocator, io: std.Io, repo: []const u8, args: []const []const u8) !std.process.RunResult {
    var argv = std.array_list.Managed([]const u8).init(allocator);
    defer argv.deinit();
    try argv.append("git");
    try argv.append("-c");
    try argv.append("core.quotePath=false");
    try argv.append("-C");
    try argv.append(repo);
    for (args) |arg| try argv.append(arg);
    return std.process.run(allocator, io, .{ .argv = argv.items, .stdout_limit = .limited(50 * 1024 * 1024), .stderr_limit = .limited(1024 * 1024) });
}

pub fn runGitOk(allocator: std.mem.Allocator, io: std.Io, repo: []const u8, args: []const []const u8) ![]u8 {
    const rr = try runGit(allocator, io, repo, args);
    allocator.free(rr.stderr);
    switch (rr.term) {
        .exited => |code| if (code == 0) return rr.stdout,
        else => {},
    }
    allocator.free(rr.stdout);
    return error.GitFailed;
}
