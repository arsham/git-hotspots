const std = @import("std");
const model = @import("model.zig");
const git = @import("git.zig");
const report = @import("report.zig");
const Io = std.Io;

const usage =
    \\git-hotspots: deterministic file-level Git-history hotspot prompts
    \\
    \\Usage:
    \\  git-hotspots [--repo PATH] [--limit N] [--format table|json] [--since REV]
    \\  git-hotspots --help
    \\
    \\Options:
    \\  --repo PATH       Local Git worktree to analyse (default: .)
    \\  --limit N         Maximum ranked files to emit (default: 10)
    \\  --format FORMAT   table or json (default: table)
    \\  --since REV       Analyse commits after REV through HEAD
    \\  --help            Show this help
    \\
    \\Hotspots are investigation prompts from local Git history, not bug predictions,
    \\developer rankings, or objective code-quality scores. The spike never fetches,
    \\pushes, uploads source, contacts remotes, or emits telemetry.
    \\
;

pub fn main(init: std.process.Init.Minimal) !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threaded: Io.Threaded = .init(allocator, .{
        .environ = init.environ,
        .argv0 = .init(init.args),
    });
    defer threaded.deinit();
    const io = threaded.io();

    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try init.args.toSlice(arena);

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var stderr_buffer: [4096]u8 = undefined;
    var stderr_writer = Io.File.stderr().writer(io, &stderr_buffer);
    const stderr = &stderr_writer.interface;
    defer stderr.flush() catch {};

    const cfg = parseArgs(allocator, args) catch |err| {
        switch (err) {
            error.HelpRequested => {
                try stdout.writeAll(usage);
                return;
            },
            error.InvalidArguments => try stderr.print("error: invalid arguments\n\n{s}", .{usage}),
            else => try stderr.print("error: {s}\n", .{@errorName(err)}),
        }
        try stderr.flush();
        std.process.exit(2);
    };
    defer freeConfig(allocator, cfg);

    var analysis = git.analyze(allocator, io, cfg) catch |err| {
        switch (err) {
            error.NotGitRepository => try stderr.print("error: --repo must point to a local non-bare Git worktree\n", .{}),
            error.BareRepository => try stderr.print("error: bare repositories are not supported by this spike; use a worktree\n", .{}),
            error.EmptyRepository => try stderr.print("error: repository has no commits to analyse\n", .{}),
            error.InvalidSince => try stderr.print("error: --since must name an existing revision\n", .{}),
            else => try stderr.print("error: git history analysis failed: {s}\n", .{@errorName(err)}),
        }
        try stderr.flush();
        std.process.exit(1);
    };
    defer analysis.deinit();

    switch (cfg.format) {
        .table => try report.renderTable(stdout, analysis),
        .json => try report.renderJson(stdout, analysis),
    }
}

const CliError = error{ HelpRequested, InvalidArguments } || std.mem.Allocator.Error;

fn parseArgs(allocator: std.mem.Allocator, args: []const [:0]const u8) CliError!model.Config {
    var cfg = model.Config{ .repo_path = try allocator.dupe(u8, ".") };
    errdefer freeConfig(allocator, cfg);

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) return error.HelpRequested;
        if (std.mem.eql(u8, arg, "--repo")) {
            i += 1;
            if (i >= args.len) return error.InvalidArguments;
            const v = args[i];
            allocator.free(cfg.repo_path);
            cfg.repo_path = try allocator.dupe(u8, v);
        } else if (std.mem.eql(u8, arg, "--limit")) {
            i += 1;
            if (i >= args.len) return error.InvalidArguments;
            const v = args[i];
            cfg.limit = std.fmt.parseInt(usize, v, 10) catch return error.InvalidArguments;
        } else if (std.mem.eql(u8, arg, "--format")) {
            i += 1;
            if (i >= args.len) return error.InvalidArguments;
            const v = args[i];
            if (std.mem.eql(u8, v, "table")) cfg.format = .table else if (std.mem.eql(u8, v, "json")) cfg.format = .json else return error.InvalidArguments;
        } else if (std.mem.eql(u8, arg, "--since")) {
            i += 1;
            if (i >= args.len) return error.InvalidArguments;
            const v = args[i];
            if (cfg.since) |old| allocator.free(old);
            cfg.since = try allocator.dupe(u8, v);
        } else return error.InvalidArguments;
    }
    if (cfg.limit == 0) return error.InvalidArguments;
    return cfg;
}

fn freeConfig(allocator: std.mem.Allocator, cfg: model.Config) void {
    allocator.free(cfg.repo_path);
    if (cfg.since) |s| allocator.free(s);
}

test "parse defaults are documented through config shape" {
    const cfg = model.Config{ .repo_path = "." };
    try std.testing.expectEqual(@as(usize, 10), cfg.limit);
    try std.testing.expectEqual(model.Format.table, cfg.format);
}

test {
    _ = @import("git.zig");
    _ = @import("report.zig");
    _ = @import("scoring.zig");
}
