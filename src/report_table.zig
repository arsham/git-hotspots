const std = @import("std");
const model = @import("model.zig");
const fmt = @import("report_format.zig");
const historical = @import("report_historical_symbols.zig");
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
    if (analysis.project_symbol_report) |project_symbols| {
        const total = project_symbols.totalSymbols();
        const shown = @min(total, analysis.symbol_display.limit);
        try writer.print("project symbols: state=current-only files={d} total={d} shown={d} omitted={d} limit={d} unsupported={d} unavailable={d} failed={d} skipped={d} sort_basis=\"parent file rank, then current-line Git evidence/provider order\"\n", .{ project_symbols.files.len, total, shown, total - shown, analysis.symbol_display.limit, project_symbols.unsupported_count, project_symbols.unavailable_count, project_symbols.failed_count, project_symbols.skipped_count });
        try writer.print("symbols caveat: current working-tree enrichment for retained ranked files only; file-level Git evidence, score, file order, lineage, and confidence are unchanged\n", .{});
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
    if (analysis.project_symbol_report) |project_symbols| try renderProjectSymbolRows(allocator, writer, project_symbols, analysis.symbol_display);
    if (analysis.historical_symbol_report) |historical_symbols| try renderHistoricalSymbolRows(writer, analysis, historical_symbols);
    if (analysis.relation_report) |relation_report| try renderSymbolRelationshipRows(writer, analysis, relation_report);
    try writer.print("\nScores are deterministic prompts for investigation, not bug predictions or code-quality ratings.\n", .{});
}

fn renderSymbolRelationshipRows(writer: anytype, analysis: model.Analysis, report: model.RelationAggregationReport) !void {
    const shown = @min(report.records.len, analysis.symbol_display.limit);
    try writer.print("\nsymbol relationships for retained ranked files:\n", .{});
    try writer.print("  summary: candidates={d} retained_candidates={d} current_symbol_candidates={d} providers={d} records={d} shown={d} omitted={d} record_bound={d} record_bound_exceeded={} omitted_records={d}\n", .{ report.candidate_file_count, report.retained_candidate_file_count, report.current_symbol_candidate_count, report.providers.len, report.records.len, shown, report.records.len - shown, report.relation_record_bound, report.relation_record_bound_exceeded, report.omitted_record_count });
    try writer.print("  caveats: ", .{});
    try fmt.renderCaveatInline(writer, report.caveats);
    try writer.writeByte('\n');
    if (report.records.len == 0) {
        try writer.print("  none\n", .{});
        return;
    }
    for (report.records[0..shown]) |record| {
        try writer.print("  {s} {s} source={s} target={s} unresolved={} provider={s} input={s} freshness={s} failure={s} confidence={s} basis={s} caveats=", .{ @tagName(record.kind), @tagName(record.direction), record.source_key, record.target_key, std.mem.startsWith(u8, record.target_key, "unresolved:"), record.provider_name, record.provider_input_identity, @tagName(record.freshness), @tagName(record.failure), @tagName(record.confidence), record.evidence_basis });
        try fmt.renderCaveatInline(writer, record.caveats);
        try writer.writeByte('\n');
    }
}

fn renderHistoricalSymbolRows(writer: anytype, analysis: model.Analysis, report: model.HistoricalSymbolReport) !void {
    const display = historical.displaySummary(report, analysis.symbol_display);
    const provider_summary = historical.providerStateSummary(report);
    try writer.print("\nhistorical symbols for retained ranked files:\n", .{});
    try writer.print("  summary: candidates={d} retained_candidates={d} aggregates={d} shown={d} omitted={d} limit={d} limit_source={s} aggregate_bound={d} aggregate_bound_exceeded={} fallback_records={d} fallback_count={d}\n", .{ report.candidate_path_count, report.retained_candidate_path_count, report.aggregates.len, display.shown, display.omitted, display.limit, display.limitSource(), report.aggregate_record_bound, report.aggregate_record_bound_exceeded, provider_summary.fallback_record_count, provider_summary.fallback_count });
    try writer.print("  provider_states: ok={d} unavailable={d} unsupported={d} failed={d} timed_out={d} skipped={d}\n", .{ provider_summary.ok, provider_summary.unavailable, provider_summary.unsupported, provider_summary.failed, provider_summary.timed_out, provider_summary.skipped });
    try writer.print("  sort_basis=\"{s}\"\n", .{historical.sort_basis});
    try writer.print("  caveats: ", .{});
    try renderHistoricalCaveatsInline(writer, report.caveats);
    try writer.writeByte('\n');
    if (report.aggregates.len == 0) {
        try writer.print("  none\n", .{});
        return;
    }
    for (report.aggregates[0..display.shown]) |record| {
        const parent = historical.parentMeta(analysis.results, record.parent_path);
        const parent_path = if (parent) |meta| meta.path else record.parent_path;
        const parent_rank = if (parent) |meta| meta.rank else 0;
        const parent_score = if (parent) |meta| meta.score else 0;
        try writer.print("  file rank={d} score={d:.1} path={s} evidence_path={s} ", .{ parent_rank, parent_score, parent_path, record.parent_path });
        if (record.symbol_name) |name| {
            try writer.print("{s} {s}", .{ if (record.symbol_kind) |kind| historical.kindName(kind) else "symbol", name });
        } else {
            try writer.print("file-fallback", .{});
        }
        if (record.revision_range) |range| try writer.print(" lines={d}-{d}", .{ range.start, range.end });
        try writer.print(" status={s} changes={d} added_pressure={d} deleted_pressure={d} latest=", .{ historical.statusName(record.status), record.change_count, record.added_line_pressure, record.deleted_line_pressure });
        if (record.latest_timestamp) |ts| try writer.print("{d}", .{ts}) else try writer.print("none", .{});
        try writer.print(" provider_state={s} confidence={s} fallback_count={d} sample_commits=", .{ historical.providerStateName(record.provider_state), historical.confidenceName(record.confidence), record.fallback_count });
        try fmt.renderInlineStringArray(writer, record.sample_commit_ids);
        try writer.print(" caveats=", .{});
        try fmt.renderCaveatInline(writer, record.caveats);
        try writer.writeByte('\n');
    }
}

fn renderHistoricalCaveatsInline(writer: anytype, caveats: []const []const u8) !void {
    var emitted = false;
    for (historical.report_level_caveats) |caveat| {
        if (emitted) try writer.writeAll("; ");
        try writer.writeAll(caveat);
        emitted = true;
    }
    for (caveats) |caveat| {
        if (emitted) try writer.writeAll("; ");
        try writer.writeAll(caveat);
        emitted = true;
    }
    if (!emitted) try writer.writeAll("none");
}

fn renderProjectSymbolRows(allocator: std.mem.Allocator, writer: anytype, project_symbols: model.ProjectSymbolReport, display: model.SymbolDisplay) !void {
    try writer.print("\ncurrent symbols for ranked files:\n", .{});
    try writer.print("  summary: files={d} total={d} unsupported={d} unavailable={d} failed={d} skipped={d}\n", .{ project_symbols.files.len, project_symbols.totalSymbols(), project_symbols.unsupported_count, project_symbols.unavailable_count, project_symbols.failed_count, project_symbols.skipped_count });
    var remaining = display.limit;
    for (project_symbols.files) |file| {
        if (remaining == 0) break;
        try writer.print("  file rank={d} score={d:.1} path={s} provider={s} failure={s} confidence={s}\n", .{ file.parent_rank, file.parent_score, file.file_path, file.provider.name, @tagName(file.provider.failure), @tagName(file.provider.confidence) });
        if (file.symbols.len == 0) {
            try writer.print("    none\n", .{});
            continue;
        }
        const indexes = try report_symbols.orderedHumanIndexes(allocator, file.symbols);
        defer allocator.free(indexes);
        const shown = @min(indexes.len, remaining);
        for (indexes[0..shown]) |index| {
            const symbol = file.symbols[index];
            const range = report_symbols.displayLineRange(symbol.current_range);
            try writer.print("    {s} {s} lines {d}-{d} confidence={s}\n", .{ @tagName(symbol.kind), symbol.name, range.start, range.end, @tagName(symbol.confidence) });
            if (symbol.current_line_history) |line_history| {
                try writer.print("      Current-line Git evidence: commits={d} lines={d} unblamable={d} freshness={s} failure={s} confidence={s} caveats=", .{ line_history.distinct_last_touch_commit_count, line_history.line_count, line_history.uncommitted_or_unblamable_line_count, @tagName(line_history.freshness), @tagName(line_history.failure), @tagName(line_history.confidence) });
                try fmt.renderCaveatInline(writer, line_history.caveats);
                try writer.writeByte('\n');
            }
        }
        remaining -= shown;
    }
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
