const std = @import("std");
const model = @import("model.zig");
const provider = @import("provider.zig");
const version = @import("version.zig");
const fmt = @import("report_format.zig");
const report_symbols = @import("report_symbols.zig");
const report_historical_symbols = @import("report_historical_symbols.zig");
const report_json = @import("report_json.zig");
const report_markdown = @import("report_markdown.zig");
const report_table = @import("report_table.zig");

pub fn renderTable(allocator: std.mem.Allocator, writer: anytype, analysis: model.Analysis) !void {
    return report_table.renderTable(allocator, writer, analysis);
}

pub fn renderJson(allocator: std.mem.Allocator, writer: anytype, analysis: model.Analysis) !void {
    return report_json.renderJson(allocator, writer, analysis);
}

pub fn renderMarkdown(allocator: std.mem.Allocator, writer: anytype, analysis: model.Analysis) !void {
    return report_markdown.renderMarkdown(allocator, writer, analysis);
}

test "markdown report has stable sections and no raw private root" {
    var include_prefixes = [_][]const u8{"src/"};
    var prefixes = [_][]const u8{ ".flow/", "glob/*" };
    var global_caveats = [_][]const u8{"dirty worktree detected; ranking uses committed history only"};
    var cochanges = [_]model.CoChange{.{ .path = "co|path\t`x`.zig", .count = 2 }};
    var row_caveats = [_][]const u8{"path # caveat\tbinary"};
    var evidence = [_]model.Evidence{.{ .commit = "abc123", .timestamp = 123, .additions = 1, .deletions = null }};
    var lineage_aliases = [_][]const u8{"old # heading|path\t`x`.zig"};
    var results = [_]model.Result{.{
        .path = "# heading|path\t`x`.zig",
        .lineage_aliases = lineage_aliases[0..],
        .score = .{ .frequency = 1.0, .churn = 2.0, .recency = 3.0, .cochange = 4.0, .total = 10.0 },
        .change_count = 2,
        .additions = 7,
        .deletions = 5,
        .churn = 12,
        .last_changed_timestamp = 456,
        .last_changed_commit = "def456",
        .current_size = null,
        .cochanges = cochanges[0..],
        .confidence = "medium",
        .caveats = row_caveats[0..],
        .evidence = evidence[0..],
    }};
    const analysis = model.Analysis{
        .allocator = std.testing.allocator,
        .repo_root = "/private/root",
        .history = .{ .head = "head123", .head_timestamp = 999, .range = null, .is_shallow = false, .is_partial = false, .dirty_worktree = true, .commit_count = 3 },
        .scope = .{ .selected_scope = .project, .filters_active = true, .include_prefixes = include_prefixes[0..], .exclude_prefixes = prefixes[0..], .outside_include_path_count = 3, .outside_include_change_count = 4, .excluded_path_count = 2, .excluded_change_count = 5 },
        .results = results[0..],
        .caveats = global_caveats[0..],
    };

    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try renderMarkdown(std.testing.allocator, &aw.writer, analysis);
    const out = aw.written();

    try std.testing.expect(std.mem.indexOf(u8, out, "# git-hotspots report\n\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "File-level Git-history investigation prompts, not bug predictions or code-quality ratings.") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "## Run summary\n\n- Tool: git-hotspots 0.1.0-alpha.3") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "## Scope") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "## Caveats") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "## Top hotspots") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "## Evidence") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\\# heading\\|path\\t\\`x\\`") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "co\\|path\\t\\`x\\`") != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, out, '\t') == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "/private/root") == null);
}
