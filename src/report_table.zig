const std = @import("std");
const model = @import("model.zig");
const fmt = @import("report_format.zig");
const report_symbols = @import("report_symbols.zig");

pub fn renderTable(allocator: std.mem.Allocator, writer: anytype, analysis: model.Analysis) !void {
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
            try renderTableSymbolRows(allocator, writer, symbols, analysis.symbol_display);
        }
    }
    try writer.print("\nScores are deterministic prompts for investigation, not bug predictions or code-quality ratings.\n", .{});
}

fn renderTableSymbolRows(allocator: std.mem.Allocator, writer: anytype, symbols: model.SymbolReport, display: model.SymbolDisplay) !void {
    const indexes = try report_symbols.orderedHumanIndexes(allocator, symbols.symbols);
    defer allocator.free(indexes);
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
