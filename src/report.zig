const std = @import("std");
const model = @import("model.zig");
const provider = @import("provider.zig");
const version = @import("version.zig");

const LineDisplayRange = struct { start: u32, end: u32 };

const SymbolDisplaySummary = struct {
    total: usize,
    shown: usize,
    omitted: usize,
    limit: usize,
    explicit_limit: bool,

    fn limitSource(self: SymbolDisplaySummary) []const u8 {
        return if (self.explicit_limit) "explicit" else "default";
    }
};

const typescript_symbol_line_history_out_of_scope_caveat = "module names are repo-relative .ts/.mts/.cts/.tsx paths; package, workspace, Node, module-resolution, tsconfig, type checking, LSP, and symbol line history are out of scope";
const typescript_true_symbol_history_out_of_scope_caveat = "module names are repo-relative .ts/.mts/.cts/.tsx paths; package, workspace, Node, module-resolution, tsconfig, type checking, LSP, and true symbol history are out of scope";

fn symbolDisplaySummary(symbols: model.SymbolReport, display: model.SymbolDisplay) SymbolDisplaySummary {
    const shown = @min(symbols.symbols.len, display.limit);
    return .{
        .total = symbols.symbols.len,
        .shown = shown,
        .omitted = symbols.symbols.len - shown,
        .limit = display.limit,
        .explicit_limit = display.explicit_limit,
    };
}

fn symbolSortBasis(symbols: model.SymbolReport) []const u8 {
    return if (symbolsHaveLineHistory(symbols.symbols)) "current-line Git evidence summary" else "provider order";
}

pub fn renderTable(writer: anytype, analysis: model.Analysis) !void {
    try writer.print("git-hotspots: file-level Git-history investigation prompts\n", .{});
    try writer.print("commits={d} shallow={} partial={} dirty={} auto_fetch=false\n", .{ analysis.history.commit_count, analysis.history.is_shallow, analysis.history.is_partial, analysis.history.dirty_worktree });
    if (analysis.scope.filters_active) {
        try writer.print("scope: selected={s} include_prefixes=", .{model.scopePresetName(analysis.scope.selected_scope)});
        try renderInlineStringArray(writer, analysis.scope.include_prefixes);
        try writer.print(" exclude_prefixes=", .{});
        try renderInlineStringArray(writer, analysis.scope.exclude_prefixes);
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
        const summary = symbolDisplaySummary(symbols, analysis.symbol_display);
        try writer.print("symbols: provider={s} state=current-only freshness={s} failure={s} confidence={s} total={d} shown={d} omitted={d} limit={d} limit_source={s} sort_basis=\"{s}\"\n", .{ symbols.provider.name, @tagName(symbols.provider.freshness), @tagName(symbols.provider.failure), @tagName(symbols.provider.confidence), summary.total, summary.shown, summary.omitted, summary.limit, summary.limitSource(), symbolSortBasis(symbols) });
        try writer.print("symbols caveat: current working-tree enrichment only; file-level Git evidence, score, file order, lineage, and confidence are unchanged\n", .{});
    }
    try writer.print("\n{s:<5} {s:<7} {s:<7} {s:<7} {s:<10} {s:<7} {s}\n", .{ "rank", "score", "changes", "churn", "confidence", "lineage", "path" });
    for (analysis.results, 0..) |row, i| {
        try writer.print("{d:<5} {d:<7.1} {d:<7} {d:<7} {s:<10} {s:<7} {s}\n", .{ i + 1, row.score.total, row.change_count, row.churn, row.confidence, lineageIndicator(row), row.path });
    }
    if (analysis.symbol_report) |symbols| {
        const summary = symbolDisplaySummary(symbols, analysis.symbol_display);
        try writer.print("\ncurrent symbols (shown first by {s}):\n", .{symbolSortBasis(symbols)});
        try writer.print("  summary: total={d} shown={d} omitted={d} limit={d} limit_source={s} sort_basis=\"{s}\"\n", .{ summary.total, summary.shown, summary.omitted, summary.limit, summary.limitSource(), symbolSortBasis(symbols) });
        if (symbols.symbols.len == 0) {
            try writer.print("  none\n", .{});
        } else {
            try renderTableSymbolRows(writer, symbols, analysis.symbol_display);
        }
    }
    try writer.print("\nScores are deterministic prompts for investigation, not bug predictions or code-quality ratings.\n", .{});
}

fn renderTableSymbolRows(writer: anytype, symbols: model.SymbolReport, display: model.SymbolDisplay) !void {
    const indexes = try orderedHumanSymbolIndexes(symbols.symbols);
    defer std.heap.page_allocator.free(indexes);
    const shown = @min(indexes.len, display.limit);
    for (indexes[0..shown]) |index| {
        const symbol = symbols.symbols[index];
        const range = displayLineRange(symbol.current_range);
        try writer.print("  {s} {s} lines {d}-{d} confidence={s}\n", .{ @tagName(symbol.kind), symbol.name, range.start, range.end, @tagName(symbol.confidence) });
        if (symbol.current_line_history) |line_history| {
            try writer.print("    Current-line Git evidence: commits={d} lines={d} unblamable={d} freshness={s} failure={s} confidence={s} caveats=", .{ line_history.distinct_last_touch_commit_count, line_history.line_count, line_history.uncommitted_or_unblamable_line_count, @tagName(line_history.freshness), @tagName(line_history.failure), @tagName(line_history.confidence) });
            try renderCaveatInline(writer, line_history.caveats);
            try writer.writeByte('\n');
        }
    }
}

pub fn renderJson(writer: anytype, analysis: model.Analysis) !void {
    try writer.print("{{\n", .{});
    try writer.print("  \"schema_version\": \"1\",\n", .{});
    try writer.print("  \"tool\": {{ \"name\": \"git-hotspots\", \"version\": \"{s}\" }},\n", .{version.value});
    try writer.print("  \"analysis\": {{\n", .{});
    try writer.print("    \"history\": {{ \"head\": ", .{});
    try jsonString(writer, analysis.history.head);
    try writer.print(", \"head_timestamp\": {d}, ", .{analysis.history.head_timestamp});
    try writer.print("\"range\": ", .{});
    if (analysis.history.range) |r| try jsonString(writer, r) else try writer.print("null", .{});
    try writer.print(", \"is_shallow\": {}, \"is_partial\": {}, \"auto_fetch\": false, \"dirty_worktree\": {}, \"commit_count\": {d} }},\n", .{ analysis.history.is_shallow, analysis.history.is_partial, analysis.history.dirty_worktree, analysis.history.commit_count });
    try writer.print("    \"scope\": {{ \"selected_scope\": ", .{});
    try jsonString(writer, model.scopePresetName(analysis.scope.selected_scope));
    try writer.print(", \"filters_active\": {}, \"include_prefixes\": ", .{analysis.scope.filters_active});
    try stringArray(writer, analysis.scope.include_prefixes);
    try writer.print(", \"exclude_prefixes\": ", .{});
    try stringArray(writer, analysis.scope.exclude_prefixes);
    try writer.print(", \"outside_include_path_count\": {d}, \"outside_include_change_count\": {d}, \"excluded_path_count\": {d}, \"excluded_change_count\": {d} }},\n", .{ analysis.scope.outside_include_path_count, analysis.scope.outside_include_change_count, analysis.scope.excluded_path_count, analysis.scope.excluded_change_count });
    try writer.print("    \"caveats\": ", .{});
    try stringArray(writer, analysis.caveats);
    try writer.print("\n", .{});
    try writer.print("  }},\n", .{});
    if (analysis.symbol_report) |symbols| {
        try renderSymbolReportJson(writer, symbols, analysis.symbol_display);
        try writer.print(",\n", .{});
    }
    if (analysis.inspect) |inspect| {
        try writer.print("  \"inspect\": {{ \"requested_path\": ", .{});
        try jsonString(writer, inspect.requested_path);
        try writer.print(", \"matched_path\": ", .{});
        try jsonString(writer, inspect.matched_path);
        try writer.print(", \"rank\": {d} }},\n", .{inspect.rank});
    }
    try writer.print("  \"results\": [\n", .{});
    for (analysis.results, 0..) |row, i| {
        try writer.print("    {{\n", .{});
        try writer.print("      \"path\": ", .{});
        try jsonString(writer, row.path);
        try writer.print(",\n", .{});
        try writer.print("      \"lineage\": {{ \"aliases\": ", .{});
        try stringArray(writer, row.lineage_aliases);
        try writer.print(", \"partial\": {}, \"caveat\": ", .{row.lineage_partial});
        try jsonString(writer, "Git rename lineage is deterministic and limited to local --find-renames=40% file edges; copies, splits, merges, and symbol moves are not tracked");
        try writer.print(" }},\n", .{});
        try writer.print("      \"score\": {{ \"total\": {d:.3}, \"frequency\": {d:.3}, \"churn\": {d:.3}, \"recency\": {d:.3}, \"cochange\": {d:.3} }},\n", .{ row.score.total, row.score.frequency, row.score.churn, row.score.recency, row.score.cochange });
        try writer.print("      \"change_count\": {d}, \"additions\": {d}, \"deletions\": {d}, \"churn\": {d},\n", .{ row.change_count, row.additions, row.deletions, row.churn });
        try writer.print("      \"recency\": {{ \"last_changed_timestamp\": {d}, \"last_changed_commit\": ", .{row.last_changed_timestamp});
        try jsonString(writer, row.last_changed_commit);
        try writer.print(" }},\n", .{});
        try writer.print("      \"current_size\": ", .{});
        if (row.current_size) |s| try writer.print("{d}", .{s}) else try writer.print("null", .{});
        try writer.print(",\n", .{});
        try writer.print("      \"cochanges\": [", .{});
        for (row.cochanges, 0..) |cc, j| {
            if (j != 0) try writer.print(", ", .{});
            try writer.print("{{ \"path\": ", .{});
            try jsonString(writer, cc.path);
            try writer.print(", \"count\": {d} }}", .{cc.count});
        }
        try writer.print("],\n", .{});
        try writer.print("      \"confidence\": ", .{});
        try jsonString(writer, row.confidence);
        try writer.print(",\n", .{});
        try writer.print("      \"caveats\": ", .{});
        try stringArray(writer, row.caveats);
        try writer.print(",\n", .{});
        try writer.print("      \"evidence\": [", .{});
        for (row.evidence, 0..) |ev, j| {
            if (j != 0) try writer.print(", ", .{});
            try writer.print("{{ \"commit\": ", .{});
            try jsonString(writer, ev.commit);
            try writer.print(", \"timestamp\": {d}, \"additions\": ", .{ev.timestamp});
            if (ev.additions) |a| try writer.print("{d}", .{a}) else try writer.print("null", .{});
            try writer.print(", \"deletions\": ", .{});
            if (ev.deletions) |d| try writer.print("{d}", .{d}) else try writer.print("null", .{});
            try writer.print(" }}", .{});
        }
        try writer.print("]\n", .{});
        try writer.print("    }}{s}\n", .{if (i + 1 == analysis.results.len) "" else ","});
    }
    try writer.print("  ]\n", .{});
    try writer.print("}}\n", .{});
}

pub fn renderMarkdown(writer: anytype, analysis: model.Analysis) !void {
    try writer.writeAll("# git-hotspots report\n\n");
    try writer.writeAll("File-level Git-history investigation prompts, not bug predictions or code-quality ratings.\n\n");

    try writer.writeAll("## Run summary\n\n");
    try writer.print("- Tool: git-hotspots {s}\n", .{version.value});
    try writer.writeAll("- Head commit: ");
    try markdownText(writer, analysis.history.head);
    try writer.writeByte('\n');
    try writer.writeAll("- Range: ");
    if (analysis.history.range) |range| try markdownText(writer, range) else try writer.writeAll("None");
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
            try markdownText(writer, prefix);
        }
    }
    try writer.writeByte('\n');
    try writer.writeAll("- Exclude prefixes: ");
    if (analysis.scope.exclude_prefixes.len == 0) {
        try writer.writeAll("None");
    } else {
        for (analysis.scope.exclude_prefixes, 0..) |prefix, i| {
            if (i != 0) try writer.writeAll(", ");
            try markdownText(writer, prefix);
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
        try markdownText(writer, inspect.requested_path);
        try writer.writeByte('\n');
        try writer.writeAll("- Matched path: ");
        try markdownText(writer, inspect.matched_path);
        try writer.writeByte('\n');
        try writer.print("- Rank in scoped evidence universe: {d}\n\n", .{inspect.rank});
    }

    if (analysis.symbol_report) |symbols| {
        try renderSymbolReportMarkdown(writer, symbols, analysis.symbol_display);
    }

    try writer.writeAll("## Caveats\n\n");
    try renderMarkdownStringList(writer, analysis.caveats);

    try writer.writeAll("\n## Top hotspots\n\n");
    try writer.writeAll("| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |\n");
    try writer.writeAll("| ---: | --- | ---: | ---: | ---: | --- | --- | --- |\n");
    for (analysis.results, 0..) |row, i| {
        try writer.print("| {d} | ", .{i + 1});
        try markdownText(writer, row.path);
        try writer.print(" | {d:.1} | {d} | {d} | ", .{ row.score.total, row.change_count, row.churn });
        try markdownText(writer, row.confidence);
        try writer.writeAll(" | ");
        try markdownText(writer, lineageIndicator(row));
        try writer.writeAll(" | ");
        try markdownText(writer, row.last_changed_commit);
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
        try markdownText(writer, row.path);
        try writer.writeAll("\n\n");
        try writer.print("- Score breakdown: total={d:.3}, frequency={d:.3}, churn={d:.3}, recency={d:.3}, cochange={d:.3}\n", .{ row.score.total, row.score.frequency, row.score.churn, row.score.recency, row.score.cochange });
        try writer.print("- Changes: {d}\n", .{row.change_count});
        try writer.print("- Additions: {d}\n", .{row.additions});
        try writer.print("- Deletions: {d}\n", .{row.deletions});
        try writer.print("- Current size: ", .{});
        if (row.current_size) |size| try writer.print("{d}", .{size}) else try writer.writeAll("None");
        try writer.writeByte('\n');
        try writer.writeAll("- Confidence: ");
        try markdownText(writer, row.confidence);
        try writer.writeByte('\n');
        try writer.writeAll("- Last commit: ");
        try markdownText(writer, row.last_changed_commit);
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
                    try markdownText(writer, alias);
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
                try markdownText(writer, cc.path);
                try writer.print(" (count={d})\n", .{cc.count});
            }
        }

        try writer.writeAll("- Evidence commits:\n");
        if (row.evidence.len == 0) {
            try writer.writeAll("  - None\n");
        } else {
            for (row.evidence) |ev| {
                try writer.writeAll("  - commit=");
                try markdownText(writer, ev.commit);
                try writer.print(" timestamp={d} additions=", .{ev.timestamp});
                try renderOptionalU64(writer, ev.additions);
                try writer.writeAll(" deletions=");
                try renderOptionalU64(writer, ev.deletions);
                try writer.writeByte('\n');
            }
        }

        try writer.writeAll("- Row caveats:\n");
        if (row.caveats.len == 0) {
            try writer.writeAll("  - None\n");
        } else {
            for (row.caveats) |caveat| {
                try writer.writeAll("  - ");
                try markdownText(writer, caveat);
                try writer.writeByte('\n');
            }
        }
    }
}

fn displayLineRange(range: provider.CurrentRange) LineDisplayRange {
    return switch (range) {
        .lines => |lines| .{ .start = lines.start, .end = lines.end },
        .bytes => .{ .start = 0, .end = 0 },
    };
}

fn renderSymbolReportJson(writer: anytype, symbols: model.SymbolReport, display: model.SymbolDisplay) !void {
    const summary = symbolDisplaySummary(symbols, display);
    try writer.print("  \"symbols\": {{\n", .{});
    try writer.print("    \"current_only\": true,\n", .{});
    try writer.print("    \"human_display\": {{ \"total_count\": {d}, \"shown_count\": {d}, \"omitted_count\": {d}, \"default_limit\": {d}, \"active_limit\": {d}, \"limit_source\": ", .{ summary.total, summary.shown, summary.omitted, model.default_symbol_display_limit, summary.limit });
    try jsonString(writer, summary.limitSource());
    try writer.print(", \"sort_basis\": ", .{});
    try jsonString(writer, symbolSortBasis(symbols));
    try writer.print(" }},\n", .{});
    try writer.print("    \"provider\": {{ \"name\": ", .{});
    try jsonString(writer, symbols.provider.name);
    try writer.print(", \"kind\": ", .{});
    try jsonString(writer, @tagName(symbols.provider.kind));
    try writer.print(", \"version\": ", .{});
    try jsonString(writer, symbols.provider.version);
    try writer.print(", \"contract_version\": ", .{});
    try jsonString(writer, symbols.provider.contract_version);
    try writer.print(", \"freshness\": ", .{});
    try jsonString(writer, @tagName(symbols.provider.freshness));
    try writer.print(", \"failure\": ", .{});
    try jsonString(writer, @tagName(symbols.provider.failure));
    try writer.print(", \"confidence\": ", .{});
    try jsonString(writer, @tagName(symbols.provider.confidence));
    try writer.print(", \"caveats\": ", .{});
    const has_line_history = symbolsHaveLineHistory(symbols.symbols);
    try stringArrayWithLineHistoryContext(writer, symbols.provider.caveats, has_line_history);
    try writer.print(", \"provenance\": {{ \"input\": ", .{});
    try jsonString(writer, symbols.provider.input.identity);
    try writer.print(", \"local_only\": true }} }},\n", .{});
    try writer.print("    \"items\": [\n", .{});
    for (symbols.symbols, 0..) |symbol, i| {
        const range = displayLineRange(symbol.current_range);
        try writer.print("      {{ \"path\": ", .{});
        try jsonString(writer, symbol.path);
        try writer.print(", \"name\": ", .{});
        try jsonString(writer, symbol.name);
        try writer.print(", \"kind\": ", .{});
        try jsonString(writer, @tagName(symbol.kind));
        try writer.print(", \"range\": {{ \"type\": \"lines\", \"start\": {d}, \"end\": {d} }}, \"provider\": ", .{ range.start, range.end });
        try jsonString(writer, symbol.provider_name);
        try writer.print(", \"confidence\": ", .{});
        try jsonString(writer, @tagName(symbol.confidence));
        try writer.print(", \"caveats\": ", .{});
        try stringArrayWithLineHistoryContext(writer, symbol.caveats, symbol.current_line_history != null);
        if (symbol.current_line_history) |line_history| {
            try writer.print(", \"current_line_history\": ", .{});
            try renderCurrentLineHistoryJson(writer, line_history);
        }
        try writer.print(" }}{s}\n", .{if (i + 1 == symbols.symbols.len) "" else ","});
    }
    try writer.print("    ]\n  }}", .{});
}

fn renderSymbolReportMarkdown(writer: anytype, symbols: model.SymbolReport, display: model.SymbolDisplay) !void {
    const summary = symbolDisplaySummary(symbols, display);
    try writer.writeAll("## Symbols\n\n");
    try writer.writeAll("Symbols are opt-in current working-tree enrichment only. They do not change score, file order, lineage, confidence, or file-level Git evidence.\n\n");
    try writer.writeAll("- Provider: ");
    try markdownText(writer, symbols.provider.name);
    try writer.writeByte('\n');
    try writer.print("- State: current-only\n- Freshness: {s}\n- Failure: {s}\n- Confidence: {s}\n", .{ @tagName(symbols.provider.freshness), @tagName(symbols.provider.failure), @tagName(symbols.provider.confidence) });
    try writer.print("- Total symbols: {d}\n- Shown symbols: {d}\n- Omitted symbols: {d}\n- Human display limit: {d} ({s})\n- Sort basis: shown first by {s}\n", .{ summary.total, summary.shown, summary.omitted, summary.limit, summary.limitSource(), symbolSortBasis(symbols) });
    try writer.writeAll("- Caveats:\n");
    if (symbols.provider.caveats.len == 0) {
        try writer.writeAll("  - None\n");
    } else {
        const has_line_history = symbolsHaveLineHistory(symbols.symbols);
        for (symbols.provider.caveats) |caveat| {
            try writer.writeAll("  - ");
            try markdownText(writer, caveatForLineHistoryContext(caveat, has_line_history));
            try writer.writeByte('\n');
        }
    }
    const has_line_history = symbolsHaveLineHistory(symbols.symbols);
    if (has_line_history) {
        try writer.writeAll("\n| Name | Kind | Lines | Confidence | Current-line Git evidence |\n| --- | --- | ---: | --- | --- |\n");
    } else {
        try writer.writeAll("\n| Name | Kind | Lines | Confidence |\n| --- | --- | ---: | --- |\n");
    }
    if (symbols.symbols.len == 0) {
        if (has_line_history) try writer.writeAll("| None | - | - | - | - |\n\n") else try writer.writeAll("| None | - | - | - |\n\n");
        return;
    }
    const indexes = try orderedHumanSymbolIndexes(symbols.symbols);
    defer std.heap.page_allocator.free(indexes);
    for (indexes[0..summary.shown]) |index| {
        const symbol = symbols.symbols[index];
        const range = displayLineRange(symbol.current_range);
        try writer.writeAll("| ");
        try markdownText(writer, symbol.name);
        try writer.print(" | {s} | {d}-{d} | {s} |", .{ @tagName(symbol.kind), range.start, range.end, @tagName(symbol.confidence) });
        if (has_line_history) {
            if (symbol.current_line_history) |line_history| {
                try writer.print(" Current-line Git evidence: commits={d}; lines={d}; unblamable={d}; freshness={s}; failure={s}; confidence={s}; caveats=", .{ line_history.distinct_last_touch_commit_count, line_history.line_count, line_history.uncommitted_or_unblamable_line_count, @tagName(line_history.freshness), @tagName(line_history.failure), @tagName(line_history.confidence) });
                try renderMarkdownCaveatInline(writer, line_history.caveats);
                try writer.writeAll(" |\n");
            } else {
                try writer.writeAll(" - |\n");
            }
        } else try writer.writeByte('\n');
    }
    try writer.writeByte('\n');
}

fn symbolsHaveLineHistory(symbols: []const provider.CurrentSymbolEvidence) bool {
    for (symbols) |symbol| if (symbol.current_line_history != null) return true;
    return false;
}

fn orderedHumanSymbolIndexes(symbols: []const provider.CurrentSymbolEvidence) ![]usize {
    const indexes = try std.heap.page_allocator.alloc(usize, symbols.len);
    for (indexes, 0..) |*index, i| index.* = i;
    if (symbolsHaveLineHistory(symbols)) {
        std.mem.sort(usize, indexes, symbols, lessHumanSymbolIndex);
    }
    return indexes;
}

fn lessHumanSymbolIndex(symbols: []const provider.CurrentSymbolEvidence, lhs_index: usize, rhs_index: usize) bool {
    return switch (compareHumanSymbol(symbols[lhs_index], symbols[rhs_index])) {
        .lt => true,
        .gt => false,
        .eq => lhs_index < rhs_index,
    };
}

fn compareHumanSymbol(lhs: provider.CurrentSymbolEvidence, rhs: provider.CurrentSymbolEvidence) std.math.Order {
    const lhs_history = lhs.current_line_history;
    const rhs_history = rhs.current_line_history;
    if (lhs_history != null and rhs_history == null) return .lt;
    if (lhs_history == null and rhs_history != null) return .gt;
    if (lhs_history) |lh| {
        const rh = rhs_history.?;
        if (compareDesc(usize, lh.distinct_last_touch_commit_count, rh.distinct_last_touch_commit_count)) |order| return order;
        if (compareOptionalTimestampDesc(lh.most_recent_line_touched_timestamp, rh.most_recent_line_touched_timestamp)) |order| return order;
        if (compareDesc(u32, lh.line_count, rh.line_count)) |order| return order;
    }
    inline for (.{
        std.mem.order(u8, lhs.name, rhs.name),
        compareRangeForSort(lhs.current_range, rhs.current_range),
        std.mem.order(u8, lhs.provider_name, rhs.provider_name),
        std.mem.order(u8, lhs.path, rhs.path),
        std.mem.order(u8, @tagName(lhs.kind), @tagName(rhs.kind)),
    }) |order| {
        if (order != .eq) return order;
    }
    return .eq;
}

fn compareDesc(comptime T: type, lhs: T, rhs: T) ?std.math.Order {
    if (lhs > rhs) return .lt;
    if (lhs < rhs) return .gt;
    return null;
}

fn compareOptionalTimestampDesc(lhs: ?i64, rhs: ?i64) ?std.math.Order {
    if (lhs == null and rhs != null) return .gt;
    if (lhs != null and rhs == null) return .lt;
    if (lhs) |l| {
        const r = rhs.?;
        if (l > r) return .lt;
        if (l < r) return .gt;
    }
    return null;
}

fn compareRangeForSort(lhs: provider.CurrentRange, rhs: provider.CurrentRange) std.math.Order {
    const lhs_range = displayLineRange(lhs);
    const rhs_range = displayLineRange(rhs);
    if (lhs_range.start < rhs_range.start) return .lt;
    if (lhs_range.start > rhs_range.start) return .gt;
    if (lhs_range.end < rhs_range.end) return .lt;
    if (lhs_range.end > rhs_range.end) return .gt;
    return .eq;
}

fn renderCurrentLineHistoryJson(writer: anytype, line_history: provider.CurrentLineHistoryEvidence) !void {
    try writer.print("{{ \"basis\": ", .{});
    try jsonString(writer, line_history.basis);
    try writer.print(", \"current_only\": {}, \"line_count\": {d}, \"distinct_last_touch_commit_count\": {d}, \"most_recent_line_touched_timestamp\": ", .{ line_history.current_only, line_history.line_count, line_history.distinct_last_touch_commit_count });
    if (line_history.most_recent_line_touched_timestamp) |ts| try writer.print("{d}", .{ts}) else try writer.print("null", .{});
    try writer.print(", \"uncommitted_or_unblamable_line_count\": {d}, \"sample_commits\": ", .{line_history.uncommitted_or_unblamable_line_count});
    try stringArray(writer, line_history.sample_commits);
    try writer.print(", \"freshness\": ", .{});
    try jsonString(writer, @tagName(line_history.freshness));
    try writer.print(", \"failure\": ", .{});
    try jsonString(writer, @tagName(line_history.failure));
    try writer.print(", \"confidence\": ", .{});
    try jsonString(writer, @tagName(line_history.confidence));
    try writer.print(", \"caveats\": ", .{});
    try stringArray(writer, line_history.caveats);
    try writer.print(" }}", .{});
}

fn renderCaveatInline(writer: anytype, caveats: []const []const u8) !void {
    if (caveats.len == 0) {
        try writer.writeAll("none");
        return;
    }
    for (caveats, 0..) |caveat, i| {
        if (i != 0) try writer.writeAll("; ");
        try writer.writeAll(caveat);
    }
}

fn renderMarkdownCaveatInline(writer: anytype, caveats: []const []const u8) !void {
    if (caveats.len == 0) {
        try writer.writeAll("none");
        return;
    }
    for (caveats, 0..) |caveat, i| {
        if (i != 0) try writer.writeAll("; ");
        try markdownText(writer, caveat);
    }
}

fn stringArray(writer: anytype, values: []const []const u8) !void {
    try writer.print("[", .{});
    for (values, 0..) |v, i| {
        if (i != 0) try writer.print(", ", .{});
        try jsonString(writer, v);
    }
    try writer.print("]", .{});
}

fn stringArrayWithLineHistoryContext(writer: anytype, values: []const []const u8, line_history_context: bool) !void {
    try writer.print("[", .{});
    for (values, 0..) |v, i| {
        if (i != 0) try writer.print(", ", .{});
        try jsonString(writer, caveatForLineHistoryContext(v, line_history_context));
    }
    try writer.print("]", .{});
}

fn caveatForLineHistoryContext(caveat: []const u8, line_history_context: bool) []const u8 {
    if (line_history_context and std.mem.eql(u8, caveat, typescript_symbol_line_history_out_of_scope_caveat)) return typescript_true_symbol_history_out_of_scope_caveat;
    return caveat;
}

fn renderInlineStringArray(writer: anytype, values: []const []const u8) !void {
    try writer.print("[", .{});
    for (values, 0..) |value, i| {
        if (i != 0) try writer.print(",", .{});
        try writer.print("{s}", .{value});
    }
    try writer.print("]", .{});
}

fn renderMarkdownStringList(writer: anytype, values: []const []const u8) !void {
    if (values.len == 0) {
        try writer.writeAll("- None\n");
        return;
    }
    for (values) |value| {
        try writer.writeAll("- ");
        try markdownText(writer, value);
        try writer.writeByte('\n');
    }
}

fn renderOptionalU64(writer: anytype, value: ?u64) !void {
    if (value) |v| try writer.print("{d}", .{v}) else try writer.writeAll("None");
}

fn lineageIndicator(row: model.Result) []const u8 {
    if (row.lineage_partial) return "partial";
    if (row.lineage_aliases.len > 0) return "yes";
    return "no";
}

fn markdownText(writer: anytype, value: []const u8) !void {
    for (value) |c| switch (c) {
        '\\' => try writer.writeAll("\\\\"),
        '`' => try writer.writeAll("\\`"),
        '*' => try writer.writeAll("\\*"),
        '_' => try writer.writeAll("\\_"),
        '{' => try writer.writeAll("\\{"),
        '}' => try writer.writeAll("\\}"),
        '[' => try writer.writeAll("\\["),
        ']' => try writer.writeAll("\\]"),
        '(' => try writer.writeAll("\\("),
        ')' => try writer.writeAll("\\)"),
        '#' => try writer.writeAll("\\#"),
        '+' => try writer.writeAll("\\+"),
        '-' => try writer.writeAll("\\-"),
        '!' => try writer.writeAll("\\!"),
        '|' => try writer.writeAll("\\|"),
        '>' => try writer.writeAll("\\>"),
        '\n' => try writer.writeAll("\\n"),
        '\r' => try writer.writeAll("\\r"),
        '\t' => try writer.writeAll("\\t"),
        0...8, 11...12, 14...0x1f, 0x7f => try writer.print("\\x{x:0>2}", .{c}),
        else => try writer.writeByte(c),
    };
}

fn jsonString(writer: anytype, value: []const u8) !void {
    try writer.writeByte('"');
    for (value) |c| switch (c) {
        '"' => try writer.writeAll("\\\""),
        '\\' => try writer.writeAll("\\\\"),
        '\n' => try writer.writeAll("\\n"),
        '\r' => try writer.writeAll("\\r"),
        '\t' => try writer.writeAll("\\t"),
        0...8, 11...12, 14...0x1f => try writer.print("\\u{x:0>4}", .{c}),
        else => try writer.writeByte(c),
    };
    try writer.writeByte('"');
}

test "json string escapes paths" {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try jsonString(&aw.writer, "a b/é\t\\q\"");
    try std.testing.expectEqualStrings("\"a b/é\\t\\\\q\\\"\"", aw.written());
}

test "markdown text escapes markdown and control characters" {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try markdownText(&aw.writer, "# [a|b] `x`\t\\q\x01");
    try std.testing.expectEqualStrings("\\# \\[a\\|b\\] \\`x\\`\\t\\\\q\\x01", aw.written());
}

test "human symbol display limit keeps json-complete metadata separate" {
    var symbols = [_]provider.CurrentSymbolEvidence{
        .{ .path = "src/a.zig", .name = "alpha", .kind = .function, .current_range = .{ .lines = .{ .start = 10, .end = 12 } }, .provider_name = "tree-sitter-zig", .confidence = .high },
        .{ .path = "src/a.zig", .name = "beta", .kind = .function, .current_range = .{ .lines = .{ .start = 20, .end = 25 } }, .provider_name = "tree-sitter-zig", .confidence = .high },
        .{ .path = "src/a.zig", .name = "gamma", .kind = .function, .current_range = .{ .lines = .{ .start = 30, .end = 30 } }, .provider_name = "tree-sitter-zig", .confidence = .high },
    };
    const report_model = model.SymbolReport{ .provider = undefined, .symbols = symbols[0..] };
    const summary = symbolDisplaySummary(report_model, .{ .limit = 2, .explicit_limit = true });
    try std.testing.expectEqual(@as(usize, 3), summary.total);
    try std.testing.expectEqual(@as(usize, 2), summary.shown);
    try std.testing.expectEqual(@as(usize, 1), summary.omitted);
    try std.testing.expectEqualStrings("explicit", summary.limitSource());
}

test "human symbols with line history sort by evidence strength then stable identity" {
    var alpha_commits = [_][]const u8{"a"};
    var beta_commits = [_][]const u8{ "b", "c" };
    var gamma_commits = [_][]const u8{"d"};
    var caveats = [_][]const u8{};
    var symbols = [_]provider.CurrentSymbolEvidence{
        .{ .path = "src/a.zig", .name = "alpha", .kind = .function, .current_range = .{ .lines = .{ .start = 10, .end = 12 } }, .provider_name = "tree-sitter-zig", .confidence = .high, .current_line_history = .{ .line_count = 3, .distinct_last_touch_commit_count = 1, .most_recent_line_touched_timestamp = 10, .uncommitted_or_unblamable_line_count = 0, .sample_commits = alpha_commits[0..], .freshness = .fresh, .failure = .ok, .confidence = .high, .caveats = caveats[0..] } },
        .{ .path = "src/a.zig", .name = "beta", .kind = .function, .current_range = .{ .lines = .{ .start = 20, .end = 25 } }, .provider_name = "tree-sitter-zig", .confidence = .high, .current_line_history = .{ .line_count = 6, .distinct_last_touch_commit_count = 2, .most_recent_line_touched_timestamp = 5, .uncommitted_or_unblamable_line_count = 0, .sample_commits = beta_commits[0..], .freshness = .fresh, .failure = .ok, .confidence = .high, .caveats = caveats[0..] } },
        .{ .path = "src/a.zig", .name = "gamma", .kind = .function, .current_range = .{ .lines = .{ .start = 30, .end = 30 } }, .provider_name = "tree-sitter-zig", .confidence = .high, .current_line_history = .{ .line_count = 1, .distinct_last_touch_commit_count = 1, .most_recent_line_touched_timestamp = 20, .uncommitted_or_unblamable_line_count = 0, .sample_commits = gamma_commits[0..], .freshness = .fresh, .failure = .ok, .confidence = .high, .caveats = caveats[0..] } },
    };
    const indexes = try orderedHumanSymbolIndexes(symbols[0..]);
    defer std.heap.page_allocator.free(indexes);
    try std.testing.expectEqual(@as(usize, 1), indexes[0]);
    try std.testing.expectEqual(@as(usize, 2), indexes[1]);
    try std.testing.expectEqual(@as(usize, 0), indexes[2]);
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
