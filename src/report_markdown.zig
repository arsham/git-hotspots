const std = @import("std");
const model = @import("model.zig");
const version = @import("version.zig");
const fmt = @import("report_format.zig");
const historical = @import("report_historical_symbols.zig");
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
    if (analysis.project_symbol_report) |project_symbols| {
        try renderProjectSymbolReportMarkdown(allocator, writer, project_symbols, analysis.symbol_display);
    }
    if (analysis.historical_symbol_report) |historical_symbols| {
        try renderHistoricalSymbolReportMarkdown(writer, analysis, historical_symbols);
    }
    if (analysis.relation_report) |relation_report| {
        try renderSymbolRelationshipReportMarkdown(writer, analysis, relation_report);
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

fn renderHistoricalSymbolReportMarkdown(writer: anytype, analysis: model.Analysis, report: model.HistoricalSymbolReport) !void {
    const display = historical.displaySummary(report, analysis.symbol_display);
    const provider_summary = historical.providerStateSummary(report);
    try writer.writeAll("## Historical symbols\n\n");
    try writer.writeAll("Historical symbols are opt-in true historical hunk attribution for retained ranked-file candidates only. They do not change score, file order, lineage, confidence, or file-level Git evidence.\n\n");
    try writer.print("- Candidate paths: {d}\n- Retained candidate paths: {d}\n- Aggregate records: {d}\n- Shown records: {d}\n- Omitted records: {d}\n- Human display limit: {d} ({s})\n", .{ report.candidate_path_count, report.retained_candidate_path_count, report.aggregates.len, display.shown, display.omitted, display.limit, display.limitSource() });
    try writer.print("- Aggregate record bound: {d}\n- Aggregate record bound exceeded: {}\n- Fallback records: {d}\n- Fallback count: {d}\n", .{ report.aggregate_record_bound, report.aggregate_record_bound_exceeded, provider_summary.fallback_record_count, provider_summary.fallback_count });
    try writer.print("- Provider states: ok={d}, unavailable={d}, unsupported={d}, failed={d}, timed_out={d}, skipped={d}\n", .{ provider_summary.ok, provider_summary.unavailable, provider_summary.unsupported, provider_summary.failed, provider_summary.timed_out, provider_summary.skipped });
    try writer.writeAll("- Sort basis: ");
    try fmt.markdownText(writer, historical.sort_basis);
    try writer.writeAll("\n- Caveats:\n");
    for (historical.report_level_caveats) |caveat| {
        try writer.writeAll("  - ");
        try fmt.markdownText(writer, caveat);
        try writer.writeByte('\n');
    }
    for (report.caveats) |caveat| {
        try writer.writeAll("  - ");
        try fmt.markdownText(writer, caveat);
        try writer.writeByte('\n');
    }
    try writer.writeByte('\n');
    try writer.writeAll("| File rank | File | Evidence path | Score | Name | Kind | Revision lines | Status | Changes | Added pressure | Deleted pressure | Latest timestamp | Provider state | Confidence | Fallbacks | Sample commits | Caveats |\n");
    try writer.writeAll("| ---: | --- | --- | ---: | --- | --- | ---: | --- | ---: | ---: | ---: | ---: | --- | --- | ---: | --- | --- |\n");
    if (report.aggregates.len == 0) {
        try writer.writeAll("| - | None | - | - | - | - | - | - | - | - | - | - | - | - | - | - | - |\n\n");
        return;
    }
    for (report.aggregates[0..display.shown]) |record| {
        const parent = historical.parentMeta(analysis.results, record.parent_path);
        if (parent) |meta| try writer.print("| {d} | ", .{meta.rank}) else try writer.writeAll("| - | ");
        if (parent) |meta| try fmt.markdownText(writer, meta.path) else try fmt.markdownText(writer, record.parent_path);
        try writer.writeAll(" | ");
        try fmt.markdownText(writer, record.parent_path);
        try writer.writeAll(" | ");
        if (parent) |meta| try writer.print("{d:.1}", .{meta.score}) else try writer.writeAll("-");
        try writer.writeAll(" | ");
        if (record.symbol_name) |name| try fmt.markdownText(writer, name) else try writer.writeAll("file fallback");
        try writer.writeAll(" | ");
        if (record.symbol_kind) |kind| try writer.writeAll(historical.kindName(kind)) else try writer.writeAll("-");
        try writer.writeAll(" | ");
        if (record.revision_range) |range| try writer.print("{d}-{d}", .{ range.start, range.end }) else try writer.writeAll("-");
        try writer.print(" | {s} | {d} | {d} | {d} | ", .{ historical.statusName(record.status), record.change_count, record.added_line_pressure, record.deleted_line_pressure });
        if (record.latest_timestamp) |ts| try writer.print("{d}", .{ts}) else try writer.writeAll("-");
        try writer.print(" | {s} | {s} | {d} | ", .{ historical.providerStateName(record.provider_state), historical.confidenceName(record.confidence), record.fallback_count });
        try renderMarkdownInlineStrings(writer, record.sample_commit_ids);
        try writer.writeAll(" | ");
        try fmt.renderMarkdownCaveatInline(writer, record.caveats);
        try writer.writeAll(" |\n");
    }
    try writer.writeByte('\n');
}

fn renderMarkdownInlineStrings(writer: anytype, values: []const []const u8) !void {
    if (values.len == 0) {
        try writer.writeAll("none");
        return;
    }
    for (values, 0..) |value, i| {
        if (i != 0) try writer.writeAll(", ");
        try fmt.markdownText(writer, value);
    }
}

fn renderSymbolRelationshipReportMarkdown(writer: anytype, analysis: model.Analysis, report: model.RelationAggregationReport) !void {
    const shown = @min(report.records.len, analysis.symbol_display.limit);
    try writer.writeAll("## Symbol relationships\n\n");
    try writer.writeAll("Symbol relationships are opt-in bounded local provider evidence for retained ranked-file candidates only. They do not change score, file order, lineage, confidence, or file-level Git evidence, and they are not call-graph truth, dependency proof, ownership, developer metrics, or bug prediction.\n\n");
    try writer.print("- Candidate files: {d}\n- Retained candidate files: {d}\n- Current symbol candidates: {d}\n- Provider reports: {d}\n- Relation records: {d}\n- Shown records: {d}\n- Omitted records: {d}\n- Human display limit: {d} ({s})\n", .{ report.candidate_file_count, report.retained_candidate_file_count, report.current_symbol_candidate_count, report.providers.len, report.records.len, shown, report.records.len - shown, analysis.symbol_display.limit, if (analysis.symbol_display.explicit_limit) "explicit" else "default" });
    try writer.print("- Relation record bound: {d}\n- Relation record bound exceeded: {}\n- Bound-omitted records: {d}\n", .{ report.relation_record_bound, report.relation_record_bound_exceeded, report.omitted_record_count });
    try writer.writeAll("- Sort basis: source endpoint, target endpoint, kind, direction, provider, evidence basis\n- Caveats:\n");
    if (report.caveats.len == 0) {
        try writer.writeAll("  - None\n");
    } else {
        for (report.caveats) |caveat| {
            try writer.writeAll("  - ");
            try fmt.markdownText(writer, caveat);
            try writer.writeByte('\n');
        }
    }
    try writer.writeByte('\n');
    try writer.writeAll("| Kind | Direction | Source endpoint | Target endpoint | Unresolved target | Provider | Provider input | Freshness | Failure | Confidence | Evidence basis | Caveats |\n");
    try writer.writeAll("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |\n");
    if (report.records.len == 0) {
        try writer.writeAll("| None | - | - | - | - | - | - | - | - | - | - | - |\n\n");
        return;
    }
    for (report.records[0..shown]) |record| {
        try writer.print("| {s} | {s} | ", .{ @tagName(record.kind), @tagName(record.direction) });
        try fmt.markdownText(writer, record.source_key);
        try writer.writeAll(" | ");
        try fmt.markdownText(writer, record.target_key);
        try writer.print(" | {} | ", .{std.mem.startsWith(u8, record.target_key, "unresolved:")});
        try fmt.markdownText(writer, record.provider_name);
        try writer.writeAll(" | ");
        try fmt.markdownText(writer, record.provider_input_identity);
        try writer.print(" | {s} | {s} | {s} | ", .{ @tagName(record.freshness), @tagName(record.failure), @tagName(record.confidence) });
        try fmt.markdownText(writer, record.evidence_basis);
        try writer.writeAll(" | ");
        try fmt.renderMarkdownCaveatInline(writer, record.caveats);
        try writer.writeAll(" |\n");
    }
    try writer.writeByte('\n');
}

fn renderProjectSymbolReportMarkdown(allocator: std.mem.Allocator, writer: anytype, project_symbols: model.ProjectSymbolReport, display: model.SymbolDisplay) !void {
    const total = project_symbols.totalSymbols();
    const shown_total = @min(total, display.limit);
    try writer.writeAll("## Project symbols\n\n");
    try writer.writeAll("Symbols are opt-in current working-tree enrichment for retained ranked file hotspots only. They do not change score, file order, lineage, confidence, or file-level Git evidence.\n\n");
    try writer.print("- Files with supported provider reports: {d}\n- Total symbols: {d}\n- Shown symbols: {d}\n- Omitted symbols: {d}\n- Human display limit: {d} ({s})\n", .{ project_symbols.files.len, total, shown_total, total - shown_total, display.limit, if (display.explicit_limit) "explicit" else "default" });
    try writer.print("- Unsupported ranked files: {d}\n- Unavailable ranked files: {d}\n- Provider failures: {d}\n- Provider skipped: {d}\n", .{ project_symbols.unsupported_count, project_symbols.unavailable_count, project_symbols.failed_count, project_symbols.skipped_count });
    try writer.writeAll("- Sort basis: parent file rank, then current-line Git evidence/provider order\n\n");
    try writer.writeAll("| File rank | File | Score | Provider | Failure | Name | Kind | Lines | Confidence | Current-line Git evidence |\n");
    try writer.writeAll("| ---: | --- | ---: | --- | --- | --- | --- | ---: | --- | --- |\n");
    var remaining = display.limit;
    for (project_symbols.files) |file| {
        if (remaining == 0) break;
        if (file.symbols.len == 0) {
            try writer.print("| {d} | ", .{file.parent_rank});
            try fmt.markdownText(writer, file.file_path);
            try writer.print(" | {d:.1} | ", .{file.parent_score});
            try fmt.markdownText(writer, file.provider.name);
            try writer.print(" | {s} | None | - | - | - | - |\n", .{@tagName(file.provider.failure)});
            continue;
        }
        const indexes = try report_symbols.orderedHumanIndexes(allocator, file.symbols);
        defer allocator.free(indexes);
        const shown = @min(indexes.len, remaining);
        for (indexes[0..shown]) |index| {
            const symbol = file.symbols[index];
            const range = report_symbols.displayLineRange(symbol.current_range);
            try writer.print("| {d} | ", .{file.parent_rank});
            try fmt.markdownText(writer, file.file_path);
            try writer.print(" | {d:.1} | ", .{file.parent_score});
            try fmt.markdownText(writer, file.provider.name);
            try writer.print(" | {s} | ", .{@tagName(file.provider.failure)});
            try fmt.markdownText(writer, symbol.name);
            try writer.print(" | {s} | {d}-{d} | {s} |", .{ @tagName(symbol.kind), range.start, range.end, @tagName(symbol.confidence) });
            if (symbol.current_line_history) |line_history| {
                try writer.print(" commits={d}; lines={d}; unblamable={d}; freshness={s}; failure={s}; confidence={s}; caveats=", .{ line_history.distinct_last_touch_commit_count, line_history.line_count, line_history.uncommitted_or_unblamable_line_count, @tagName(line_history.freshness), @tagName(line_history.failure), @tagName(line_history.confidence) });
                try fmt.renderMarkdownCaveatInline(writer, line_history.caveats);
                try writer.writeAll(" |\n");
            } else {
                try writer.writeAll(" - |\n");
            }
        }
        remaining -= shown;
    }
    if (total == 0 and project_symbols.files.len == 0) try writer.writeAll("| - | None | - | - | - | - | - | - | - | - |\n");
    try writer.writeByte('\n');
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
