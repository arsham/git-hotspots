const std = @import("std");
const model = @import("model.zig");
const provider = @import("provider.zig");
const version = @import("version.zig");
const fmt = @import("report_format.zig");
const historical = @import("report_historical_symbols.zig");
const report_symbols = @import("report_symbols.zig");

pub fn renderJson(allocator: std.mem.Allocator, writer: anytype, analysis: model.Analysis) !void {
    try writer.print("{{\n", .{});
    try writer.print("  \"schema_version\": \"1\",\n", .{});
    try writer.print("  \"tool\": {{ \"name\": \"git-hotspots\", \"version\": \"{s}\" }},\n", .{version.value});
    try writer.print("  \"analysis\": {{\n", .{});
    try writer.print("    \"history\": {{ \"head\": ", .{});
    try fmt.jsonString(writer, analysis.history.head);
    try writer.print(", \"head_timestamp\": {d}, ", .{analysis.history.head_timestamp});
    try writer.print("\"range\": ", .{});
    if (analysis.history.range) |r| try fmt.jsonString(writer, r) else try writer.print("null", .{});
    try writer.print(", \"is_shallow\": {}, \"is_partial\": {}, \"auto_fetch\": false, \"dirty_worktree\": {}, \"commit_count\": {d} }},\n", .{ analysis.history.is_shallow, analysis.history.is_partial, analysis.history.dirty_worktree, analysis.history.commit_count });
    try writer.print("    \"scope\": {{ \"selected_scope\": ", .{});
    try fmt.jsonString(writer, model.scopePresetName(analysis.scope.selected_scope));
    try writer.print(", \"filters_active\": {}, \"include_prefixes\": ", .{analysis.scope.filters_active});
    try fmt.stringArray(writer, analysis.scope.include_prefixes);
    try writer.print(", \"exclude_prefixes\": ", .{});
    try fmt.stringArray(writer, analysis.scope.exclude_prefixes);
    try writer.print(", \"outside_include_path_count\": {d}, \"outside_include_change_count\": {d}, \"excluded_path_count\": {d}, \"excluded_change_count\": {d} }},\n", .{ analysis.scope.outside_include_path_count, analysis.scope.outside_include_change_count, analysis.scope.excluded_path_count, analysis.scope.excluded_change_count });
    try writer.print("    \"caveats\": ", .{});
    try fmt.stringArray(writer, analysis.caveats);
    try writer.print("\n", .{});
    try writer.print("  }},\n", .{});
    if (analysis.symbol_report) |symbols| {
        try renderSymbolReportJson(writer, symbols, analysis.symbol_display);
        try writer.print(",\n", .{});
    }
    if (analysis.project_symbol_report) |project_symbols| {
        try renderProjectSymbolReportJson(allocator, writer, project_symbols, analysis.symbol_display);
        try writer.print(",\n", .{});
    }
    if (analysis.historical_symbol_report != null) {
        try renderHistoricalSymbolReportJson(writer, analysis);
        try writer.print(",\n", .{});
    }
    if (analysis.relation_report != null) {
        try renderSymbolRelationshipsJson(writer, analysis);
        try writer.print(",\n", .{});
    }
    if (analysis.inspect) |inspect| {
        try writer.print("  \"inspect\": {{ \"requested_path\": ", .{});
        try fmt.jsonString(writer, inspect.requested_path);
        try writer.print(", \"matched_path\": ", .{});
        try fmt.jsonString(writer, inspect.matched_path);
        try writer.print(", \"rank\": {d} }},\n", .{inspect.rank});
    }
    try writer.print("  \"results\": [\n", .{});
    for (analysis.results, 0..) |row, i| {
        try writer.print("    {{\n", .{});
        try writer.print("      \"path\": ", .{});
        try fmt.jsonString(writer, row.path);
        try writer.print(",\n", .{});
        try writer.print("      \"lineage\": {{ \"aliases\": ", .{});
        try fmt.stringArray(writer, row.lineage_aliases);
        try writer.print(", \"partial\": {}, \"caveat\": ", .{row.lineage_partial});
        try fmt.jsonString(writer, "Git rename lineage is deterministic and limited to local --find-renames=40% file edges; copies, splits, merges, and symbol moves are not tracked");
        try writer.print(" }},\n", .{});
        try writer.print("      \"score\": {{ \"total\": {d:.3}, \"frequency\": {d:.3}, \"churn\": {d:.3}, \"recency\": {d:.3}, \"cochange\": {d:.3} }},\n", .{ row.score.total, row.score.frequency, row.score.churn, row.score.recency, row.score.cochange });
        try writer.print("      \"change_count\": {d}, \"additions\": {d}, \"deletions\": {d}, \"churn\": {d},\n", .{ row.change_count, row.additions, row.deletions, row.churn });
        try writer.print("      \"recency\": {{ \"last_changed_timestamp\": {d}, \"last_changed_commit\": ", .{row.last_changed_timestamp});
        try fmt.jsonString(writer, row.last_changed_commit);
        try writer.print(" }},\n", .{});
        try writer.print("      \"current_size\": ", .{});
        if (row.current_size) |s| try writer.print("{d}", .{s}) else try writer.print("null", .{});
        try writer.print(",\n", .{});
        try writer.print("      \"cochanges\": [", .{});
        for (row.cochanges, 0..) |cc, j| {
            if (j != 0) try writer.print(", ", .{});
            try writer.print("{{ \"path\": ", .{});
            try fmt.jsonString(writer, cc.path);
            try writer.print(", \"count\": {d} }}", .{cc.count});
        }
        try writer.print("],\n", .{});
        try writer.print("      \"confidence\": ", .{});
        try fmt.jsonString(writer, row.confidence);
        try writer.print(",\n", .{});
        try writer.print("      \"caveats\": ", .{});
        try fmt.stringArray(writer, row.caveats);
        try writer.print(",\n", .{});
        try writer.print("      \"evidence\": [", .{});
        for (row.evidence, 0..) |ev, j| {
            if (j != 0) try writer.print(", ", .{});
            try writer.print("{{ \"commit\": ", .{});
            try fmt.jsonString(writer, ev.commit);
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

fn renderHistoricalSymbolReportJson(writer: anytype, analysis: model.Analysis) !void {
    const report = analysis.historical_symbol_report.?;
    const display = historical.displaySummary(report, analysis.symbol_display);
    const provider_summary = historical.providerStateSummary(report);

    try writer.print("  \"historical_symbols\": {{\n", .{});
    try writer.print("    \"basis\": {{ \"kind\": ", .{});
    try fmt.jsonString(writer, "historical-hunk-attribution");
    try writer.print(", \"requires_symbols_flag\": true, \"retained_ranked_file_candidates\": true, \"scoring_effect\": ", .{});
    try fmt.jsonString(writer, "none");
    try writer.print(" }},\n", .{});
    try writer.print("    \"provenance\": {{ \"local_only\": true, \"network\": false, \"checkout\": false, \"auto_fetch\": false }},\n", .{});
    try writer.print("    \"human_display\": {{ \"total_count\": {d}, \"shown_count\": {d}, \"omitted_count\": {d}, \"default_limit\": {d}, \"active_limit\": {d}, \"limit_source\": ", .{ display.total, display.shown, display.omitted, model.default_symbol_display_limit, display.limit });
    try fmt.jsonString(writer, display.limitSource());
    try writer.print(", \"sort_basis\": ", .{});
    try fmt.jsonString(writer, historical.sort_basis);
    try writer.print(" }},\n", .{});
    try writer.print("    \"summary\": {{ \"candidate_path_count\": {d}, \"retained_candidate_path_count\": {d}, \"item_count\": {d}, \"aggregate_record_bound\": {d}, \"aggregate_record_bound_exceeded\": {}, \"fallback_record_count\": {d}, \"fallback_count\": {d}, \"provider_states\": {{ \"ok\": {d}, \"unavailable\": {d}, \"unsupported\": {d}, \"failed\": {d}, \"timed_out\": {d}, \"skipped\": {d} }} }},\n", .{ report.candidate_path_count, report.retained_candidate_path_count, report.aggregates.len, report.aggregate_record_bound, report.aggregate_record_bound_exceeded, provider_summary.fallback_record_count, provider_summary.fallback_count, provider_summary.ok, provider_summary.unavailable, provider_summary.unsupported, provider_summary.failed, provider_summary.timed_out, provider_summary.skipped });
    try writer.print("    \"caveats\": ", .{});
    try renderHistoricalCaveatsJson(writer, report.caveats);
    try writer.print(",\n", .{});
    try writer.print("    \"items\": [\n", .{});
    for (report.aggregates, 0..) |record, i| {
        const parent = historical.parentMeta(analysis.results, record.parent_path);
        try writer.print("      {{ \"parent_file_path\": ", .{});
        if (parent) |meta| try fmt.jsonString(writer, meta.path) else try fmt.jsonString(writer, record.parent_path);
        try writer.print(", \"evidence_path\": ", .{});
        try fmt.jsonString(writer, record.parent_path);
        try writer.print(", \"parent_rank\": ", .{});
        if (parent) |meta| try writer.print("{d}", .{meta.rank}) else try writer.print("null", .{});
        try writer.print(", \"parent_score\": ", .{});
        if (parent) |meta| try writer.print("{d:.3}", .{meta.score}) else try writer.print("null", .{});
        try writer.print(", \"name\": ", .{});
        if (record.symbol_name) |name| try fmt.jsonString(writer, name) else try writer.print("null", .{});
        try writer.print(", \"kind\": ", .{});
        if (record.symbol_kind) |kind| try fmt.jsonString(writer, historical.kindName(kind)) else try writer.print("null", .{});
        try writer.print(", \"revision_range\": ", .{});
        if (record.revision_range) |range| try writer.print("{{ \"start\": {d}, \"end\": {d} }}", .{ range.start, range.end }) else try writer.print("null", .{});
        try writer.print(", \"status\": ", .{});
        try fmt.jsonString(writer, historical.statusName(record.status));
        try writer.print(", \"change_count\": {d}, \"added_line_pressure\": {d}, \"deleted_line_pressure\": {d}, \"latest_timestamp\": ", .{ record.change_count, record.added_line_pressure, record.deleted_line_pressure });
        if (record.latest_timestamp) |ts| try writer.print("{d}", .{ts}) else try writer.print("null", .{});
        try writer.print(", \"sample_commit_ids\": ", .{});
        try fmt.stringArray(writer, record.sample_commit_ids);
        try writer.print(", \"provider_state\": ", .{});
        try fmt.jsonString(writer, historical.providerStateName(record.provider_state));
        try writer.print(", \"confidence\": ", .{});
        try fmt.jsonString(writer, historical.confidenceName(record.confidence));
        try writer.print(", \"fallback_count\": {d}, \"caveats\": ", .{record.fallback_count});
        try fmt.stringArray(writer, record.caveats);
        try writer.print(" }}{s}\n", .{if (i + 1 == report.aggregates.len) "" else ","});
    }
    try writer.print("    ]\n  }}", .{});
}

fn renderHistoricalCaveatsJson(writer: anytype, caveats: []const []const u8) !void {
    try writer.print("[", .{});
    var emitted = false;
    for (historical.report_level_caveats) |caveat| {
        if (emitted) try writer.print(", ", .{});
        try fmt.jsonString(writer, caveat);
        emitted = true;
    }
    for (caveats) |caveat| {
        if (emitted) try writer.print(", ", .{});
        try fmt.jsonString(writer, caveat);
        emitted = true;
    }
    try writer.print("]", .{});
}

fn renderProjectSymbolReportJson(allocator: std.mem.Allocator, writer: anytype, project_symbols: model.ProjectSymbolReport, display: model.SymbolDisplay) !void {
    const total = project_symbols.totalSymbols();
    try writer.print("  \"project_symbols\": {{\n", .{});
    try writer.print("    \"current_only\": true,\n", .{});
    try writer.print("    \"human_display\": {{ \"total_count\": {d}, \"shown_count\": {d}, \"omitted_count\": {d}, \"default_limit\": {d}, \"active_limit\": {d}, \"limit_source\": ", .{ total, @min(total, display.limit), total - @min(total, display.limit), model.default_symbol_display_limit, display.limit });
    try fmt.jsonString(writer, if (display.explicit_limit) "explicit" else "default");
    try writer.print(", \"sort_basis\": ", .{});
    try fmt.jsonString(writer, "parent file rank, then current-line Git evidence/provider order");
    try writer.print(" }},\n", .{});
    try writer.print("    \"summary\": {{ \"file_count\": {d}, \"unsupported_count\": {d}, \"unavailable_count\": {d}, \"failed_count\": {d}, \"skipped_count\": {d} }},\n", .{ project_symbols.files.len, project_symbols.unsupported_count, project_symbols.unavailable_count, project_symbols.failed_count, project_symbols.skipped_count });
    try writer.print("    \"files\": [\n", .{});
    for (project_symbols.files, 0..) |file, file_i| {
        try writer.print("      {{ \"path\": ", .{});
        try fmt.jsonString(writer, file.file_path);
        try writer.print(", \"parent_rank\": {d}, \"parent_score\": {d:.3}, \"provider\": {{ \"name\": ", .{ file.parent_rank, file.parent_score });
        try fmt.jsonString(writer, file.provider.name);
        try writer.print(", \"kind\": ", .{});
        try fmt.jsonString(writer, @tagName(file.provider.kind));
        try writer.print(", \"version\": ", .{});
        try fmt.jsonString(writer, file.provider.version);
        try writer.print(", \"contract_version\": ", .{});
        try fmt.jsonString(writer, file.provider.contract_version);
        try writer.print(", \"freshness\": ", .{});
        try fmt.jsonString(writer, @tagName(file.provider.freshness));
        try writer.print(", \"failure\": ", .{});
        try fmt.jsonString(writer, @tagName(file.provider.failure));
        try writer.print(", \"confidence\": ", .{});
        try fmt.jsonString(writer, @tagName(file.provider.confidence));
        try writer.print(", \"caveats\": ", .{});
        try fmt.stringArrayWithLineHistoryContext(writer, file.provider.caveats, report_symbols.haveLineHistory(file.symbols));
        try writer.print(", \"provenance\": {{ \"input\": ", .{});
        try fmt.jsonString(writer, file.provider.input.identity);
        try writer.print(", \"local_only\": true }} }}, \"items\": [", .{});
        const indexes = try report_symbols.orderedHumanIndexes(allocator, file.symbols);
        defer allocator.free(indexes);
        for (indexes, 0..) |symbol_index, symbol_i| {
            const symbol = file.symbols[symbol_index];
            if (symbol_i != 0) try writer.print(", ", .{});
            try writer.print("{{ \"path\": ", .{});
            try fmt.jsonString(writer, symbol.path);
            try writer.print(", \"parent_rank\": {d}, \"parent_score\": {d:.3}, \"name\": ", .{ file.parent_rank, file.parent_score });
            try fmt.jsonString(writer, symbol.name);
            try writer.print(", \"kind\": ", .{});
            try fmt.jsonString(writer, @tagName(symbol.kind));
            try writer.print(", \"range\": ", .{});
            try renderRangeJson(writer, symbol.current_range);
            try writer.print(", \"provider\": ", .{});
            try fmt.jsonString(writer, symbol.provider_name);
            try writer.print(", \"confidence\": ", .{});
            try fmt.jsonString(writer, @tagName(symbol.confidence));
            try writer.print(", \"current_only\": true, \"caveats\": ", .{});
            try fmt.stringArrayWithLineHistoryContext(writer, symbol.caveats, symbol.current_line_history != null);
            if (symbol.current_line_history) |line_history| {
                try writer.print(", \"current_line_history\": ", .{});
                try renderCurrentLineHistoryJson(writer, line_history);
            }
            try writer.print(" }}", .{});
        }
        try writer.print("] }}{s}\n", .{if (file_i + 1 == project_symbols.files.len) "" else ","});
    }
    try writer.print("    ]\n  }}", .{});
}

fn renderSymbolReportJson(writer: anytype, symbols: model.SymbolReport, display: model.SymbolDisplay) !void {
    const summary = report_symbols.displaySummary(symbols, display);
    try writer.print("  \"symbols\": {{\n", .{});
    try writer.print("    \"current_only\": true,\n", .{});
    try writer.print("    \"human_display\": {{ \"total_count\": {d}, \"shown_count\": {d}, \"omitted_count\": {d}, \"default_limit\": {d}, \"active_limit\": {d}, \"limit_source\": ", .{ summary.total, summary.shown, summary.omitted, model.default_symbol_display_limit, summary.limit });
    try fmt.jsonString(writer, summary.limitSource());
    try writer.print(", \"sort_basis\": ", .{});
    try fmt.jsonString(writer, report_symbols.sortBasis(symbols));
    try writer.print(" }},\n", .{});
    try writer.print("    \"provider\": {{ \"name\": ", .{});
    try fmt.jsonString(writer, symbols.provider.name);
    try writer.print(", \"kind\": ", .{});
    try fmt.jsonString(writer, @tagName(symbols.provider.kind));
    try writer.print(", \"version\": ", .{});
    try fmt.jsonString(writer, symbols.provider.version);
    try writer.print(", \"contract_version\": ", .{});
    try fmt.jsonString(writer, symbols.provider.contract_version);
    try writer.print(", \"freshness\": ", .{});
    try fmt.jsonString(writer, @tagName(symbols.provider.freshness));
    try writer.print(", \"failure\": ", .{});
    try fmt.jsonString(writer, @tagName(symbols.provider.failure));
    try writer.print(", \"confidence\": ", .{});
    try fmt.jsonString(writer, @tagName(symbols.provider.confidence));
    try writer.print(", \"caveats\": ", .{});
    const has_line_history = report_symbols.haveLineHistory(symbols.symbols);
    try fmt.stringArrayWithLineHistoryContext(writer, symbols.provider.caveats, has_line_history);
    try writer.print(", \"provenance\": {{ \"input\": ", .{});
    try fmt.jsonString(writer, symbols.provider.input.identity);
    try writer.print(", \"local_only\": true }} }},\n", .{});
    try writer.print("    \"items\": [\n", .{});
    for (symbols.symbols, 0..) |symbol, i| {
        try writer.print("      {{ \"path\": ", .{});
        try fmt.jsonString(writer, symbol.path);
        try writer.print(", \"name\": ", .{});
        try fmt.jsonString(writer, symbol.name);
        try writer.print(", \"kind\": ", .{});
        try fmt.jsonString(writer, @tagName(symbol.kind));
        try writer.print(", \"range\": ", .{});
        try renderRangeJson(writer, symbol.current_range);
        try writer.print(", \"provider\": ", .{});
        try fmt.jsonString(writer, symbol.provider_name);
        try writer.print(", \"confidence\": ", .{});
        try fmt.jsonString(writer, @tagName(symbol.confidence));
        try writer.print(", \"caveats\": ", .{});
        try fmt.stringArrayWithLineHistoryContext(writer, symbol.caveats, symbol.current_line_history != null);
        if (symbol.current_line_history) |line_history| {
            try writer.print(", \"current_line_history\": ", .{});
            try renderCurrentLineHistoryJson(writer, line_history);
        }
        try writer.print(" }}{s}\n", .{if (i + 1 == symbols.symbols.len) "" else ","});
    }
    try writer.print("    ]\n  }}", .{});
}

fn renderRangeJson(writer: anytype, range: provider.CurrentRange) !void {
    switch (range) {
        .lines => |lines| try writer.print("{{ \"type\": \"lines\", \"start\": {d}, \"end\": {d} }}", .{ lines.start, lines.end }),
        .bytes => |bytes| try writer.print("{{ \"type\": \"bytes\", \"start\": {d}, \"end\": {d} }}", .{ bytes.start, bytes.end }),
    }
}

fn renderCurrentLineHistoryJson(writer: anytype, line_history: provider.CurrentLineHistoryEvidence) !void {
    try writer.print("{{ \"basis\": ", .{});
    try fmt.jsonString(writer, line_history.basis);
    try writer.print(", \"current_only\": {}, \"line_count\": {d}, \"distinct_last_touch_commit_count\": {d}, \"most_recent_line_touched_timestamp\": ", .{ line_history.current_only, line_history.line_count, line_history.distinct_last_touch_commit_count });
    if (line_history.most_recent_line_touched_timestamp) |ts| try writer.print("{d}", .{ts}) else try writer.print("null", .{});
    try writer.print(", \"uncommitted_or_unblamable_line_count\": {d}, \"sample_commits\": ", .{line_history.uncommitted_or_unblamable_line_count});
    try fmt.stringArray(writer, line_history.sample_commits);
    try writer.print(", \"freshness\": ", .{});
    try fmt.jsonString(writer, @tagName(line_history.freshness));
    try writer.print(", \"failure\": ", .{});
    try fmt.jsonString(writer, @tagName(line_history.failure));
    try writer.print(", \"confidence\": ", .{});
    try fmt.jsonString(writer, @tagName(line_history.confidence));
    try writer.print(", \"caveats\": ", .{});
    try fmt.stringArray(writer, line_history.caveats);
    try writer.print(" }}", .{});
}

fn renderSymbolRelationshipsJson(writer: anytype, analysis: model.Analysis) !void {
    const relation_report = analysis.relation_report.?;
    try writer.print("  \"symbol_relationships\": {{\n", .{});
    try writer.print("    \"basis\": {{ \"kind\": ", .{});
    try fmt.jsonString(writer, "bounded-local-relation-evidence");
    try writer.print(", \"requires_symbols_flag\": true, \"retained_ranked_file_candidates\": true, \"scoring_effect\": ", .{});
    try fmt.jsonString(writer, "none");
    try writer.print(" }},\n", .{});
    try writer.print("    \"provenance\": {{ \"local_only\": true, \"network\": false, \"checkout\": false, \"auto_fetch\": false }},\n", .{});
    try writer.print("    \"human_display\": {{ \"total_count\": {d}, \"shown_count\": {d}, \"omitted_count\": {d}, \"default_limit\": {d}, \"active_limit\": {d}, \"limit_source\": ", .{ relation_report.records.len, @min(relation_report.records.len, analysis.symbol_display.limit), relation_report.records.len - @min(relation_report.records.len, analysis.symbol_display.limit), model.default_symbol_display_limit, analysis.symbol_display.limit });
    try fmt.jsonString(writer, if (analysis.symbol_display.explicit_limit) "explicit" else "default");
    try writer.print(", \"sort_basis\": ", .{});
    try fmt.jsonString(writer, "source endpoint, target endpoint, kind, direction, provider, evidence basis");
    try writer.print(" }},\n", .{});
    try writer.print("    \"summary\": {{ \"candidate_file_count\": {d}, \"retained_candidate_file_count\": {d}, \"current_symbol_candidate_count\": {d}, \"provider_report_count\": {d}, \"relation_record_count\": {d}, \"relation_record_bound\": {d}, \"relation_record_bound_exceeded\": {}, \"omitted_record_count\": {d} }},\n", .{ relation_report.candidate_file_count, relation_report.retained_candidate_file_count, relation_report.current_symbol_candidate_count, relation_report.providers.len, relation_report.records.len, relation_report.relation_record_bound, relation_report.relation_record_bound_exceeded, relation_report.omitted_record_count });
    try writer.print("    \"caveats\": ", .{});
    try fmt.stringArray(writer, relation_report.caveats);
    try writer.print(",\n", .{});
    try writer.print("    \"providers\": [\n", .{});
    for (relation_report.providers, 0..) |file, file_i| {
        try writer.print("      {{ \"path\": ", .{});
        try fmt.jsonString(writer, file.file_path);
        try writer.print(", \"parent_rank\": {d}, \"provider\": {{ \"name\": ", .{file.parent_rank});
        try fmt.jsonString(writer, file.provider.name);
        try writer.print(", \"kind\": ", .{});
        try fmt.jsonString(writer, @tagName(file.provider.kind));
        try writer.print(", \"version\": ", .{});
        try fmt.jsonString(writer, file.provider.version);
        try writer.print(", \"contract_version\": ", .{});
        try fmt.jsonString(writer, file.provider.contract_version);
        try writer.print(", \"freshness\": ", .{});
        try fmt.jsonString(writer, @tagName(file.provider.freshness));
        try writer.print(", \"failure\": ", .{});
        try fmt.jsonString(writer, @tagName(file.provider.failure));
        try writer.print(", \"confidence\": ", .{});
        try fmt.jsonString(writer, @tagName(file.provider.confidence));
        try writer.print(", \"caveats\": ", .{});
        try fmt.stringArray(writer, file.provider.caveats);
        try writer.print(", \"provenance\": {{ \"input\": ", .{});
        try fmt.jsonString(writer, file.provider.input.identity);
        try writer.print(", \"local_only\": true }} }}, \"candidate_count\": {d}, \"omitted_count\": {d}, \"cap_reached\": {} }}{s}\n", .{ file.candidate_count, file.omitted_count, file.cap_reached, if (file_i + 1 == relation_report.providers.len) "" else "," });
    }
    try writer.print("    ],\n", .{});
    try writer.print("    \"records\": [\n", .{});
    for (relation_report.records, 0..) |record, i| {
        try writer.print("      {{ \"kind\": ", .{});
        try fmt.jsonString(writer, @tagName(record.kind));
        try writer.print(", \"direction\": ", .{});
        try fmt.jsonString(writer, @tagName(record.direction));
        try writer.print(", \"source_endpoint\": ", .{});
        try fmt.jsonString(writer, record.source_key);
        try writer.print(", \"target_endpoint\": ", .{});
        try fmt.jsonString(writer, record.target_key);
        try writer.print(", \"target_unresolved\": {}, \"evidence_basis\": ", .{std.mem.startsWith(u8, record.target_key, "unresolved:")});
        try fmt.jsonString(writer, record.evidence_basis);
        try writer.print(", \"provider\": {{ \"name\": ", .{});
        try fmt.jsonString(writer, record.provider_name);
        try writer.print(", \"input\": ", .{});
        try fmt.jsonString(writer, record.provider_input_identity);
        try writer.print(" }}, \"freshness\": ", .{});
        try fmt.jsonString(writer, @tagName(record.freshness));
        try writer.print(", \"failure\": ", .{});
        try fmt.jsonString(writer, @tagName(record.failure));
        try writer.print(", \"confidence\": ", .{});
        try fmt.jsonString(writer, @tagName(record.confidence));
        try writer.print(", \"caveats\": ", .{});
        try fmt.stringArray(writer, record.caveats);
        try writer.print(" }}{s}\n", .{if (i + 1 == relation_report.records.len) "" else ","});
    }
    try writer.print("    ]\n  }}", .{});
}

test "symbol JSON preserves line and byte ranges" {
    var symbol_items = [_]provider.CurrentSymbolEvidence{
        .{
            .path = "src/raw.bin",
            .name = "raw-symbol",
            .kind = .other,
            .current_range = .{ .bytes = .{ .start = 100, .end = 200 } },
            .provider_name = "synthetic-provider",
            .confidence = .low,
        },
        .{
            .path = "src/main.zig",
            .name = "line-symbol",
            .kind = .function,
            .current_range = .{ .lines = .{ .start = 3, .end = 5 } },
            .provider_name = "synthetic-provider",
            .confidence = .high,
        },
    };
    const report_model = model.SymbolReport{
        .provider = .{
            .name = "synthetic-provider",
            .kind = .symbol,
            .version = "synthetic-1",
            .input = .{ .identity = "working-tree:src/raw.bin" },
            .freshness = .fresh,
            .failure = .ok,
            .confidence = .low,
            .caveats = &.{},
            .provenance = .{ .provider_name = "synthetic-provider", .input_identity = "working-tree:src/raw.bin" },
        },
        .symbols = symbol_items[0..],
    };

    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try renderSymbolReportJson(&aw.writer, report_model, .{ .limit = 10, .explicit_limit = false });
    const out = aw.written();
    try std.testing.expect(std.mem.indexOf(u8, out, "\"range\": { \"type\": \"bytes\", \"start\": 100, \"end\": 200 }") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"range\": { \"type\": \"lines\", \"start\": 3, \"end\": 5 }") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"type\": \"lines\", \"start\": 0, \"end\": 0") == null);
}
