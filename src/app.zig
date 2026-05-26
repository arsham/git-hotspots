const std = @import("std");
const cli = @import("cli.zig");
const model = @import("model.zig");
const git = @import("git.zig");
const report = @import("report.zig");
const provider_selection = @import("provider_selection.zig");
const explain = @import("explain.zig");
const version = @import("version.zig");
const Io = std.Io;

pub fn run(allocator: std.mem.Allocator, io: std.Io, args: []const [:0]const u8, stdout: *Io.Writer, stderr: *Io.Writer) !void {
    const mode = cli.parseArgs(allocator, args) catch |err| {
        switch (err) {
            error.HelpRequested => {
                try stdout.writeAll(cli.usage);
                return;
            },
            error.InvalidIncludePrefix => try stderr.print("error: --include-prefix must be a non-empty repo-relative path prefix without absolute roots, '..' segments, or control characters\n", .{}),
            error.InvalidExcludePrefix => try stderr.print("error: --exclude-prefix must be a non-empty repo-relative path prefix without absolute roots, '..' segments, or control characters\n", .{}),
            error.InvalidInspectPath => try stderr.print("error: --inspect must be a non-empty exact repo-relative Git path without absolute roots, '..' segments, or control characters\n", .{}),
            error.InvalidScope => try stderr.print("error: --scope accepts one lowercase value: all or project\n", .{}),
            error.InvalidInspectLimitCombination => try stderr.print("error: --limit cannot be combined with --inspect; inspect selects from the full scoped evidence universe\n", .{}),
            error.InvalidSymbolsCombination => try stderr.print("error: --symbols can only be combined with --inspect PATH\n", .{}),
            error.InvalidSymbolLineHistoryCombination => try stderr.print("error: --symbol-line-history can only be combined with --inspect PATH --symbols\n", .{}),
            error.InvalidSymbolLimitCombination => try stderr.print("error: --symbol-limit can only be combined with --inspect PATH --symbols\n", .{}),
            error.InvalidSymbolLimit => try stderr.print("error: --symbol-limit must be a positive integer\n", .{}),
            error.InvalidExplainCombination => try stderr.print("error: --explain cannot be combined with analysis flags (--repo, --limit, --format, --since, --scope, --include-prefix, --exclude-prefix, --inspect, --symbols, --symbol-line-history, --symbol-limit, --progress)\n", .{}),
            error.InvalidVersionCombination => try stderr.print("error: --version cannot be combined with --explain or analysis flags (--repo, --limit, --format, --since, --scope, --include-prefix, --exclude-prefix, --inspect, --symbols, --symbol-line-history, --symbol-limit, --progress)\n", .{}),
            error.InvalidArguments => try stderr.print("error: invalid arguments\n\n{s}", .{cli.usage}),
            else => try stderr.print("error: {s}\n", .{@errorName(err)}),
        }
        try stderr.flush();
        std.process.exit(2);
    };

    const cfg = switch (mode) {
        .explain => {
            try stdout.writeAll(explain.text);
            return;
        },
        .version => {
            try stdout.print("git-hotspots {s}\n", .{version.value});
            return;
        },
        .analyze => |cfg| cfg,
    };
    defer cli.freeConfig(allocator, cfg);

    const progress_started = Io.Clock.Timestamp.now(io, .awake);
    const progress = if (cfg.progress) stderr else null;

    var analysis = git.analyze(allocator, io, cfg, progress) catch |err| {
        switch (err) {
            error.NotGitRepository => try stderr.print("error: --repo must point to a local non-bare Git worktree\n", .{}),
            error.BareRepository => try stderr.print("error: bare repositories are not supported by this alpha; use a worktree\n", .{}),
            error.EmptyRepository => try stderr.print("error: repository has no commits to analyse\n", .{}),
            error.InvalidSince => try stderr.print("error: --since must name an existing revision\n", .{}),
            error.InspectTargetNotFound => try stderr.print("error: --inspect target has no matching Git-history evidence in the selected scope\n", .{}),
            else => try stderr.print("error: git history analysis failed: {s}\n", .{@errorName(err)}),
        }
        try stderr.flush();
        std.process.exit(1);
    };
    defer analysis.deinit();

    if (cfg.symbols) {
        try provider_selection.attachInspectSymbols(allocator, io, &analysis);
        if (cfg.symbol_line_history) try git.attachCurrentLineHistory(allocator, io, &analysis);
        analysis.symbol_display = .{ .limit = cfg.symbol_limit orelse model.default_symbol_display_limit, .explicit_limit = cfg.symbol_limit != null };
    }

    try writeProgress(progress, "rendering report");

    switch (cfg.format) {
        .table => try report.renderTable(stdout, analysis),
        .json => try report.renderJson(stdout, analysis),
        .markdown => try report.renderMarkdown(stdout, analysis),
    }
    if (progress) |writer| {
        const elapsed = progress_started.durationTo(Io.Clock.Timestamp.now(io, .awake));
        try writer.print("progress: done in {d}ms\n", .{elapsed.raw.toMilliseconds()});
        try writer.flush();
    }
}

fn writeProgress(progress: ?*Io.Writer, message: []const u8) !void {
    if (progress) |writer| {
        try writer.print("progress: {s}\n", .{message});
        try writer.flush();
    }
}
