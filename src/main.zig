const std = @import("std");
const model = @import("model.zig");
const git = @import("git.zig");
const report = @import("report.zig");
const Io = std.Io;

const usage =
    \\git-hotspots: deterministic file-level Git-history hotspot prompts
    \\
    \\Usage:
    \\  git-hotspots [--repo PATH] [--limit N] [--format table|json|markdown] [--since REV] [--exclude-prefix PATH]...
    \\  git-hotspots --help
    \\
    \\Options:
    \\  --repo PATH       Local Git worktree to analyse (default: .)
    \\  --limit N         Maximum ranked files to emit (default: 10)
    \\  --format FORMAT   table, json, or markdown (default: table)
    \\  --since REV       Analyse commits after REV through HEAD
    \\  --exclude-prefix PATH
    \\                    Repeatable repo-relative literal Git path prefix to exclude
    \\                    before scoring; use / separators, not globs
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
            error.InvalidExcludePrefix => try stderr.print("error: --exclude-prefix must be a non-empty repo-relative path prefix without absolute roots, '..' segments, or control characters\n", .{}),
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
        .markdown => try report.renderMarkdown(stdout, analysis),
    }
}

const CliError = error{ HelpRequested, InvalidArguments, InvalidExcludePrefix } || std.mem.Allocator.Error;

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
            if (std.mem.eql(u8, v, "table")) cfg.format = .table else if (std.mem.eql(u8, v, "json")) cfg.format = .json else if (std.mem.eql(u8, v, "markdown")) cfg.format = .markdown else return error.InvalidArguments;
        } else if (std.mem.eql(u8, arg, "--since")) {
            i += 1;
            if (i >= args.len) return error.InvalidArguments;
            const v = args[i];
            if (cfg.since) |old| allocator.free(old);
            cfg.since = try allocator.dupe(u8, v);
        } else if (std.mem.eql(u8, arg, "--exclude-prefix")) {
            i += 1;
            if (i >= args.len) return error.InvalidArguments;
            try appendExcludePrefix(allocator, &cfg, args[i]);
        } else return error.InvalidArguments;
    }
    if (cfg.limit == 0) return error.InvalidArguments;
    return cfg;
}

fn freeConfig(allocator: std.mem.Allocator, cfg: model.Config) void {
    allocator.free(cfg.repo_path);
    if (cfg.since) |s| allocator.free(s);
    for (cfg.exclude_prefixes) |prefix| allocator.free(prefix);
    if (cfg.exclude_prefixes.len > 0) allocator.free(cfg.exclude_prefixes);
}

fn appendExcludePrefix(allocator: std.mem.Allocator, cfg: *model.Config, raw: []const u8) CliError!void {
    const normalized = try normalizeExcludePrefix(allocator, raw);
    errdefer allocator.free(normalized);

    const expanded = try allocator.alloc([]const u8, cfg.exclude_prefixes.len + 1);
    @memcpy(expanded[0..cfg.exclude_prefixes.len], cfg.exclude_prefixes);
    expanded[cfg.exclude_prefixes.len] = normalized;
    if (cfg.exclude_prefixes.len > 0) allocator.free(cfg.exclude_prefixes);
    cfg.exclude_prefixes = expanded;
}

fn normalizeExcludePrefix(allocator: std.mem.Allocator, raw: []const u8) CliError![]const u8 {
    var prefix = raw;
    while (std.mem.startsWith(u8, prefix, "./")) prefix = prefix[2..];
    if (prefix.len == 0) return error.InvalidExcludePrefix;
    if (std.fs.path.isAbsolute(prefix) or prefix[0] == '\\') return error.InvalidExcludePrefix;
    if (prefix.len >= 2 and std.ascii.isAlphabetic(prefix[0]) and prefix[1] == ':') return error.InvalidExcludePrefix;
    for (prefix) |c| if (c < 0x20 or c == 0x7f) return error.InvalidExcludePrefix;

    var segments = std.mem.splitScalar(u8, prefix, '/');
    while (segments.next()) |segment| {
        if (std.mem.eql(u8, segment, "..")) return error.InvalidExcludePrefix;
    }
    return allocator.dupe(u8, prefix);
}

test "parse defaults are documented through config shape" {
    const cfg = model.Config{ .repo_path = "." };
    try std.testing.expectEqual(@as(usize, 10), cfg.limit);
    try std.testing.expectEqual(model.Format.table, cfg.format);
}

test "parse repeatable exclude prefixes" {
    const args = [_][:0]const u8{ "git-hotspots", "--exclude-prefix", "./.flow/", "--exclude-prefix", "vendor/" };
    const cfg = try parseArgs(std.testing.allocator, &args);
    defer freeConfig(std.testing.allocator, cfg);
    try std.testing.expectEqual(@as(usize, 2), cfg.exclude_prefixes.len);
    try std.testing.expectEqualStrings(".flow/", cfg.exclude_prefixes[0]);
    try std.testing.expectEqualStrings("vendor/", cfg.exclude_prefixes[1]);
}

test "reject invalid exclude prefixes" {
    const cases = [_][]const u8{ "", "/tmp", "../src", "src/../lib", "bad\npath" };
    for (cases) |value| {
        var cfg = model.Config{ .repo_path = try std.testing.allocator.dupe(u8, ".") };
        defer freeConfig(std.testing.allocator, cfg);
        try std.testing.expectError(error.InvalidExcludePrefix, appendExcludePrefix(std.testing.allocator, &cfg, value));
    }
}

test {
    _ = @import("git.zig");
    _ = @import("report.zig");
    _ = @import("scoring.zig");
}
