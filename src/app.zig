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
            error.MissingRepoValue => try stderr.print("error: --repo requires a local Git worktree path; use git-hotspots --repo PATH\n", .{}),
            error.MissingLimitValue => try stderr.print("error: --limit requires a positive integer value; use git-hotspots --limit N\n", .{}),
            error.InvalidLimit => try stderr.print("error: --limit must be a positive integer; use git-hotspots --limit 10\n", .{}),
            error.MissingFormatValue => try stderr.print("error: --format requires a value; use git-hotspots --format table|json|markdown\n", .{}),
            error.InvalidFormat => try stderr.print("error: --format accepts one value: table, json, or markdown\n", .{}),
            error.MissingSinceValue => try stderr.print("error: --since requires a Git revision; use git-hotspots --since REV\n", .{}),
            error.MissingIncludePrefixValue => try stderr.print("error: --include-prefix requires a repo-relative path prefix; use git-hotspots --include-prefix PATH\n", .{}),
            error.MissingExcludePrefixValue => try stderr.print("error: --exclude-prefix requires a repo-relative path prefix; use git-hotspots --exclude-prefix PATH\n", .{}),
            error.MissingInspectValue => try stderr.print("error: --inspect requires an exact repo-relative Git path; use git-hotspots --inspect PATH\n", .{}),
            error.UnknownOption => try stderr.print("error: unknown option; run git-hotspots --help for supported options\n", .{}),
            error.UnexpectedArgument => try stderr.print("error: unexpected positional argument; use named options such as git-hotspots --repo PATH\n", .{}),
            error.InvalidIncludePrefix => try stderr.print("error: --include-prefix must be a non-empty repo-relative path prefix without absolute roots, '..' segments, or control characters\n", .{}),
            error.InvalidExcludePrefix => try stderr.print("error: --exclude-prefix must be a non-empty repo-relative path prefix without absolute roots, '..' segments, or control characters\n", .{}),
            error.InvalidInspectPath => try stderr.print("error: --inspect must be a non-empty exact repo-relative Git path without absolute roots, '..' segments, or control characters; use git-hotspots --inspect src/main.zig\n", .{}),
            error.InvalidScope => try stderr.print("error: --scope accepts one lowercase value: all or project; use git-hotspots --scope project or git-hotspots --scope all\n", .{}),
            error.InvalidInspectLimitCombination => try stderr.print("error: --limit cannot be combined with --inspect; use git-hotspots --inspect PATH or git-hotspots --limit N\n", .{}),
            error.InvalidSymbolsCombination => try stderr.print("error: --symbols can be used with project analysis or --inspect PATH; use git-hotspots --repo . --symbols or git-hotspots --inspect src/main.zig --symbols\n", .{}),
            error.InvalidSymbolLineHistoryCombination => try stderr.print("error: --symbol-line-history requires --symbols; use git-hotspots --repo . --symbols --symbol-line-history\n", .{}),
            error.InvalidSymbolLimitCombination => try stderr.print("error: --symbol-limit requires --symbols; use git-hotspots --repo . --symbols --symbol-limit N\n", .{}),
            error.InvalidSymbolLimit => try stderr.print("error: --symbol-limit must be a positive integer; use git-hotspots --symbols --symbol-limit 25\n", .{}),
            error.InvalidExplainCombination => try stderr.print("error: --explain cannot be combined with analysis flags; use git-hotspots --explain\n", .{}),
            error.InvalidVersionCombination => try stderr.print("error: --version cannot be combined with --explain or analysis flags; use git-hotspots --version\n", .{}),
            error.InvalidArguments => try stderr.print("error: invalid arguments; run git-hotspots --help for supported options\n", .{}),
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
        if (analysis.inspect != null) {
            try provider_selection.attachInspectSymbols(allocator, io, &analysis);
        } else {
            try provider_selection.attachProjectSymbols(allocator, io, &analysis);
        }
        if (cfg.symbol_line_history) try git.attachCurrentLineHistory(allocator, io, &analysis);
        analysis.symbol_display = .{ .limit = cfg.symbol_limit orelse model.default_symbol_display_limit, .explicit_limit = cfg.symbol_limit != null };
    }

    try writeProgress(progress, "rendering report");

    switch (cfg.format) {
        .table => try report.renderTable(allocator, stdout, analysis),
        .json => try report.renderJson(allocator, stdout, analysis),
        .markdown => try report.renderMarkdown(allocator, stdout, analysis),
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
