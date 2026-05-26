const std = @import("std");
const model = @import("model.zig");
const version = @import("version.zig");
const fmt = @import("report_format.zig");
const report_symbols = @import("report_symbols.zig");

pub fn renderMarkdown(allocator: std.mem.Allocator, writer: anytype, analysis: model.Analysis) !void {
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
        try renderSymbolReportMarkdown(allocator, writer, symbols, analysis.symbol_display);
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

fn renderSymbolReportMarkdown(allocator: std.mem.Allocator, writer: anytype, symbols: model.SymbolReport, display: model.SymbolDisplay) !void {
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
    const indexes = try report_symbols.orderedHumanIndexes(allocator, symbols.symbols);
    defer allocator.free(indexes);
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
