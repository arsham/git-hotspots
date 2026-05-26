const std = @import("std");
const model = @import("model.zig");
const provider = @import("provider.zig");
const version = @import("version.zig");
const fmt = @import("report_format.zig");
const report_symbols = @import("report_symbols.zig");
const report_json = @import("report_json.zig");

pub fn renderTable(writer: anytype, analysis: model.Analysis) !void {
    try writer.print("git-hotspots: file-level Git-history investigation prompts\n", .{});
    try writer.print("commits={d} shallow={} partial={} dirty={} auto_fetch=false\n", .{ analysis.history.commit_count, analysis.history.is_shallow, analysis.history.is_partial, analysis.history.dirty_worktree });
    if (analysis.scope.filters_active) {
        try writer.print("scope: selected={s} include_prefixes=", .{model.scopePresetName(analysis.scope.selected_scope)});
        try fmt.renderInlineStringArray(writer, analysis.scope.include_prefixes);
        try writer.print(" exclude_prefixes=", .{});
        try fmt.renderInlineStringArray(writer, analysis.scope.exclude_prefixes);
        try writer.print(" outside_include_paths={d} outside_include_changes={d} excluded_paths={d} excluded_changes={d}\n", .{ analysis.scope.outside_include_path_count, analysis.scope.outside_include_change_count, analysis.scope.excluded_path_count, analysis.scope.excluded_change_count });
    }
    if (analysis.caveats.len > 0) {
        try writer.print("caveats: ", .{});
        for (analysis.caveats, 0..) |c, i| {
            if (i != 0) try writer.print("; ", .{});
            try writer.print("{s}", .{c});
        }
        try writer.print("\n", .{});
    }
    if (analysis.inspect) |inspect| {
        try writer.print("inspect: requested={s} matched={s} rank={d}\n", .{ inspect.requested_path, inspect.matched_path, inspect.rank });
    }
    if (analysis.symbol_report) |symbols| {
        const summary = report_symbols.displaySummary(symbols, analysis.symbol_display);
        try writer.print("symbols: provider={s} state=current-only freshness={s} failure={s} confidence={s} total={d} shown={d} omitted={d} limit={d} limit_source={s} sort_basis=\"{s}\"\n", .{ symbols.provider.name, @tagName(symbols.provider.freshness), @tagName(symbols.provider.failure), @tagName(symbols.provider.confidence), summary.total, summary.shown, summary.omitted, summary.limit, summary.limitSource(), report_symbols.sortBasis(symbols) });
        try writer.print("symbols caveat: current working-tree enrichment only; file-level Git evidence, score, file order, lineage, and confidence are unchanged\n", .{});
    }
    try writer.print("\n{s:<5} {s:<7} {s:<7} {s:<7} {s:<10} {s:<7} {s}\n", .{ "rank", "score", "changes", "churn", "confidence", "lineage", "path" });
    for (analysis.results, 0..) |row, i| {
        try writer.print("{d:<5} {d:<7.1} {d:<7} {d:<7} {s:<10} {s:<7} {s}\n", .{ i + 1, row.score.total, row.change_count, row.churn, row.confidence, report_symbols.lineageIndicator(row), row.path });
    }
    if (analysis.symbol_report) |symbols| {
        const summary = report_symbols.displaySummary(symbols, analysis.symbol_display);
        try writer.print("\ncurrent symbols (shown first by {s}):\n", .{report_symbols.sortBasis(symbols)});
        try writer.print("  summary: total={d} shown={d} omitted={d} limit={d} limit_source={s} sort_basis=\"{s}\"\n", .{ summary.total, summary.shown, summary.omitted, summary.limit, summary.limitSource(), report_symbols.sortBasis(symbols) });
        if (symbols.symbols.len == 0) {
            try writer.print("  none\n", .{});
        } else {
            try renderTableSymbolRows(writer, symbols, analysis.symbol_display);
        }
    }
    try writer.print("\nScores are deterministic prompts for investigation, not bug predictions or code-quality ratings.\n", .{});
}

fn renderTableSymbolRows(writer: anytype, symbols: model.SymbolReport, display: model.SymbolDisplay) !void {
    const indexes = try report_symbols.orderedHumanIndexes(symbols.symbols);
    defer std.heap.page_allocator.free(indexes);
    const shown = @min(indexes.len, display.limit);
    for (indexes[0..shown]) |index| {
        const symbol = symbols.symbols[index];
        const range = report_symbols.displayLineRange(symbol.current_range);
        try writer.print("  {s} {s} lines {d}-{d} confidence={s}\n", .{ @tagName(symbol.kind), symbol.name, range.start, range.end, @tagName(symbol.confidence) });
        if (symbol.current_line_history) |line_history| {
            try writer.print("    Current-line Git evidence: commits={d} lines={d} unblamable={d} freshness={s} failure={s} confidence={s} caveats=", .{ line_history.distinct_last_touch_commit_count, line_history.line_count, line_history.uncommitted_or_unblamable_line_count, @tagName(line_history.freshness), @tagName(line_history.failure), @tagName(line_history.confidence) });
            try fmt.renderCaveatInline(writer, line_history.caveats);
            try writer.writeByte('\n');
        }
    }
}

pub fn renderJson(writer: anytype, analysis: model.Analysis) !void {
    return report_json.renderJson(writer, analysis);
}

pub fn renderMarkdown(writer: anytype, analysis: model.Analysis) !void {
    try writer.writeAll("# git-hotspots report\n\n");
    try writer.writeAll("File-level Git-history investigation prompts, not bug predictions or code-quality ratings.\n\n");

    try writer.writeAll("## Run summary\n\n");
    try writer.print("- Tool: git-hotspots {s}\n", .{version.value});
    try writer.writeAll("- Head commit: ");
    try fmt.markdownText(writer, analysis.history.head);
    try writer.writeByte('\n');
    try writer.writeAll("- Range: ");
    if (analysis.history.range) |range| try fmt.markdownText(writer, range) else try writer.writeAll("None");
    try writer.writeByte('\n');
    try writer.print("- Commit count: {d}\n", .{analysis.history.commit_count});
    try writer.print("- Shallow history: {}\n", .{analysis.history.is_shallow});
    try writer.print("- Partial history: {}\n", .{analysis.history.is_partial});
    try writer.print("- Dirty worktree: {}\n", .{analysis.history.dirty_worktree});
    try writer.writeAll("- Auto fetch: false\n");
    try writer.writeAll("- Paths: repo-relative\n\n");

    try writer.writeAll("## Scope\n\n");
    try writer.print("- Selected scope: {s}\n", .{model.scopePresetName(analysis.scope.selected_scope)});
    try writer.print("- Filters active: {}\n", .{analysis.scope.filters_active});
    try writer.writeAll("- Include prefixes: ");
    if (analysis.scope.include_prefixes.len == 0) {
        try writer.writeAll("None");
    } else {
        for (analysis.scope.include_prefixes, 0..) |prefix, i| {
            if (i != 0) try writer.writeAll(", ");
            try fmt.markdownText(writer, prefix);
        }
    }
    try writer.writeByte('\n');
    try writer.writeAll("- Exclude prefixes: ");
    if (analysis.scope.exclude_prefixes.len == 0) {
        try writer.writeAll("None");
    } else {
        for (analysis.scope.exclude_prefixes, 0..) |prefix, i| {
            if (i != 0) try writer.writeAll(", ");
            try fmt.markdownText(writer, prefix);
        }
    }
    try writer.writeByte('\n');
    try writer.print("- Outside include path count: {d}\n", .{analysis.scope.outside_include_path_count});
    try writer.print("- Outside include change count: {d}\n", .{analysis.scope.outside_include_change_count});
    try writer.print("- Excluded path count: {d}\n", .{analysis.scope.excluded_path_count});
    try writer.print("- Excluded change count: {d}\n\n", .{analysis.scope.excluded_change_count});

    if (analysis.inspect) |inspect| {
        try writer.writeAll("## Inspect\n\n");
        try writer.writeAll("- Requested path: ");
        try fmt.markdownText(writer, inspect.requested_path);
        try writer.writeByte('\n');
        try writer.writeAll("- Matched path: ");
        try fmt.markdownText(writer, inspect.matched_path);
        try writer.writeByte('\n');
        try writer.print("- Rank in scoped evidence universe: {d}\n\n", .{inspect.rank});
    }

    if (analysis.symbol_report) |symbols| {
        try renderSymbolReportMarkdown(writer, symbols, analysis.symbol_display);
    }

    try writer.writeAll("## Caveats\n\n");
    try fmt.renderMarkdownStringList(writer, analysis.caveats);

    try writer.writeAll("\n## Top hotspots\n\n");
    try writer.writeAll("| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |\n");
    try writer.writeAll("| ---: | --- | ---: | ---: | ---: | --- | --- | --- |\n");
    for (analysis.results, 0..) |row, i| {
        try writer.print("| {d} | ", .{i + 1});
        try fmt.markdownText(writer, row.path);
        try writer.print(" | {d:.1} | {d} | {d} | ", .{ row.score.total, row.change_count, row.churn });
        try fmt.markdownText(writer, row.confidence);
        try writer.writeAll(" | ");
        try fmt.markdownText(writer, report_symbols.lineageIndicator(row));
        try writer.writeAll(" | ");
        try fmt.markdownText(writer, row.last_changed_commit);
        try writer.writeAll(" |\n");
    }
    if (analysis.results.len == 0) try writer.writeAll("\nNo hotspots matched the requested scope.\n");

    try writer.writeAll("\n## Evidence\n");
    if (analysis.results.len == 0) {
        try writer.writeAll("\nNo result evidence to show.\n");
        return;
    }

    for (analysis.results, 0..) |row, i| {
        try writer.print("\n### {d}. ", .{i + 1});
        try fmt.markdownText(writer, row.path);
        try writer.writeAll("\n\n");
        try writer.print("- Score breakdown: total={d:.3}, frequency={d:.3}, churn={d:.3}, recency={d:.3}, cochange={d:.3}\n", .{ row.score.total, row.score.frequency, row.score.churn, row.score.recency, row.score.cochange });
        try writer.print("- Changes: {d}\n", .{row.change_count});
        try writer.print("- Additions: {d}\n", .{row.additions});
        try writer.print("- Deletions: {d}\n", .{row.deletions});
        try writer.print("- Current size: ", .{});
        if (row.current_size) |size| try writer.print("{d}", .{size}) else try writer.writeAll("None");
        try writer.writeByte('\n');
        try writer.writeAll("- Confidence: ");
        try fmt.markdownText(writer, row.confidence);
        try writer.writeByte('\n');
        try writer.writeAll("- Last commit: ");
        try fmt.markdownText(writer, row.last_changed_commit);
        try writer.writeByte('\n');

        try writer.writeAll("- Lineage: ");
        if (row.lineage_aliases.len == 0 and !row.lineage_partial) {
            try writer.writeAll("None\n");
        } else {
            try writer.writeAll("Git rename edges only; no copy, split, merge, symbol, or semantic move tracking\n");
            if (row.lineage_aliases.len > 0) {
                try writer.writeAll("  - Accepted aliases: ");
                for (row.lineage_aliases, 0..) |alias, alias_i| {
                    if (alias_i != 0) try writer.writeAll(", ");
                    try fmt.markdownText(writer, alias);
                }
                try writer.writeByte('\n');
            }
            if (row.lineage_partial) try writer.writeAll("  - Caveat: lineage may be partial because at least one observed rename edge was outside active scope filters\n");
        }

        try writer.writeAll("- Top co-changes:\n");
        if (row.cochanges.len == 0) {
            try writer.writeAll("  - None\n");
        } else {
            for (row.cochanges) |cc| {
                try writer.writeAll("  - ");
                try fmt.markdownText(writer, cc.path);
                try writer.print(" (count={d})\n", .{cc.count});
            }
        }

        try writer.writeAll("- Evidence commits:\n");
        if (row.evidence.len == 0) {
            try writer.writeAll("  - None\n");
        } else {
            for (row.evidence) |ev| {
                try writer.writeAll("  - commit=");
                try fmt.markdownText(writer, ev.commit);
                try writer.print(" timestamp={d} additions=", .{ev.timestamp});
                try fmt.renderOptionalU64(writer, ev.additions);
                try writer.writeAll(" deletions=");
                try fmt.renderOptionalU64(writer, ev.deletions);
                try writer.writeByte('\n');
            }
        }

        try writer.writeAll("- Row caveats:\n");
        if (row.caveats.len == 0) {
            try writer.writeAll("  - None\n");
        } else {
            for (row.caveats) |caveat| {
                try writer.writeAll("  - ");
                try fmt.markdownText(writer, caveat);
                try writer.writeByte('\n');
            }
        }
    }
}

fn renderSymbolReportMarkdown(writer: anytype, symbols: model.SymbolReport, display: model.SymbolDisplay) !void {
    const summary = report_symbols.displaySummary(symbols, display);
    try writer.writeAll("## Symbols\n\n");
    try writer.writeAll("Symbols are opt-in current working-tree enrichment only. They do not change score, file order, lineage, confidence, or file-level Git evidence.\n\n");
    try writer.writeAll("- Provider: ");
    try fmt.markdownText(writer, symbols.provider.name);
    try writer.writeByte('\n');
    try writer.print("- State: current-only\n- Freshness: {s}\n- Failure: {s}\n- Confidence: {s}\n", .{ @tagName(symbols.provider.freshness), @tagName(symbols.provider.failure), @tagName(symbols.provider.confidence) });
    try writer.print("- Total symbols: {d}\n- Shown symbols: {d}\n- Omitted symbols: {d}\n- Human display limit: {d} ({s})\n- Sort basis: shown first by {s}\n", .{ summary.total, summary.shown, summary.omitted, summary.limit, summary.limitSource(), report_symbols.sortBasis(symbols) });
    try writer.writeAll("- Caveats:\n");
    if (symbols.provider.caveats.len == 0) {
        try writer.writeAll("  - None\n");
    } else {
        const has_line_history = report_symbols.haveLineHistory(symbols.symbols);
        for (symbols.provider.caveats) |caveat| {
            try writer.writeAll("  - ");
            try fmt.markdownText(writer, fmt.caveatForLineHistoryContext(caveat, has_line_history));
            try writer.writeByte('\n');
        }
    }
    const has_line_history = report_symbols.haveLineHistory(symbols.symbols);
    if (has_line_history) {
        try writer.writeAll("\n| Name | Kind | Lines | Confidence | Current-line Git evidence |\n| --- | --- | ---: | --- | --- |\n");
    } else {
        try writer.writeAll("\n| Name | Kind | Lines | Confidence |\n| --- | --- | ---: | --- |\n");
    }
    if (symbols.symbols.len == 0) {
        if (has_line_history) try writer.writeAll("| None | - | - | - | - |\n\n") else try writer.writeAll("| None | - | - | - |\n\n");
        return;
    }
    const indexes = try report_symbols.orderedHumanIndexes(symbols.symbols);
    defer std.heap.page_allocator.free(indexes);
    for (indexes[0..summary.shown]) |index| {
        const symbol = symbols.symbols[index];
        const range = report_symbols.displayLineRange(symbol.current_range);
        try writer.writeAll("| ");
        try fmt.markdownText(writer, symbol.name);
        try writer.print(" | {s} | {d}-{d} | {s} |", .{ @tagName(symbol.kind), range.start, range.end, @tagName(symbol.confidence) });
        if (has_line_history) {
            if (symbol.current_line_history) |line_history| {
                try writer.print(" Current-line Git evidence: commits={d}; lines={d}; unblamable={d}; freshness={s}; failure={s}; confidence={s}; caveats=", .{ line_history.distinct_last_touch_commit_count, line_history.line_count, line_history.uncommitted_or_unblamable_line_count, @tagName(line_history.freshness), @tagName(line_history.failure), @tagName(line_history.confidence) });
                try fmt.renderMarkdownCaveatInline(writer, line_history.caveats);
                try writer.writeAll(" |\n");
            } else {
                try writer.writeAll(" - |\n");
            }
        } else try writer.writeByte('\n');
    }
    try writer.writeByte('\n');
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
    try renderMarkdown(&aw.writer, analysis);
    const out = aw.written();

    try std.testing.expect(std.mem.indexOf(u8, out, "# git-hotspots report\n\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "File-level Git-history investigation prompts, not bug predictions or code-quality ratings.") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "## Run summary\n\n- Tool: git-hotspots 0.1.0-alpha.1") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "## Scope") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "## Caveats") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "## Top hotspots") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "## Evidence") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\\# heading\\|path\\t\\`x\\`") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "co\\|path\\t\\`x\\`") != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, out, '\t') == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "/private/root") == null);
}
