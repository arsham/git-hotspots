const std = @import("std");
const model = @import("model.zig");
const provider = @import("provider.zig");

pub const sort_basis = "historical aggregate sort key: evidence path, symbol kind/name/status/range; attached parent rank is reported but does not change file ranking";

pub const report_level_caveats = [_][]const u8{
    "historical symbols are opt-in true historical hunk attribution over retained ranked-file candidates only",
    "provider-supported languages only; unsupported, binary, large, missing, provider-failed, merge, and unattributed evidence may fall back to file-level records",
    "no semantic symbol lineage, rename/move/split/merge proof, reference/use analysis, maintainer attribution, bug prediction, scoring replacement, or developer metrics",
    "local Git history only; no checkout, network access, auto-fetch, telemetry, remote enrichment, cache truth, or runtime LLM judgement",
};

pub const DisplaySummary = struct {
    total: usize,
    shown: usize,
    omitted: usize,
    limit: usize,
    explicit_limit: bool,

    pub fn limitSource(self: DisplaySummary) []const u8 {
        return if (self.explicit_limit) "explicit" else "default";
    }
};

pub const ProviderStateSummary = struct {
    ok: usize = 0,
    unavailable: usize = 0,
    unsupported: usize = 0,
    failed: usize = 0,
    timed_out: usize = 0,
    skipped: usize = 0,
    fallback_record_count: usize = 0,
    fallback_count: usize = 0,
};

pub const ParentMeta = struct {
    path: []const u8,
    rank: usize,
    score: f64,
};

pub fn displaySummary(report: model.HistoricalSymbolReport, display: model.SymbolDisplay) DisplaySummary {
    const shown = @min(report.aggregates.len, display.limit);
    return .{
        .total = report.aggregates.len,
        .shown = shown,
        .omitted = report.aggregates.len - shown,
        .limit = display.limit,
        .explicit_limit = display.explicit_limit,
    };
}

pub fn providerStateSummary(report: model.HistoricalSymbolReport) ProviderStateSummary {
    var summary: ProviderStateSummary = .{};
    for (report.aggregates) |record| {
        switch (record.provider_state) {
            .ok => summary.ok += 1,
            .unavailable => summary.unavailable += 1,
            .unsupported => summary.unsupported += 1,
            .failed => summary.failed += 1,
            .timed_out => summary.timed_out += 1,
            .skipped => summary.skipped += 1,
        }
        if (record.fallback_count > 0) summary.fallback_record_count += 1;
        summary.fallback_count += record.fallback_count;
    }
    return summary;
}

pub fn parentMeta(results: []const model.Result, evidence_path: []const u8) ?ParentMeta {
    for (results, 0..) |row, index| {
        if (std.mem.eql(u8, row.path, evidence_path) or hasAlias(row, evidence_path)) {
            return .{ .path = row.path, .rank = index + 1, .score = row.score.total };
        }
    }
    return null;
}

fn hasAlias(row: model.Result, path: []const u8) bool {
    for (row.lineage_aliases) |alias| {
        if (std.mem.eql(u8, alias, path)) return true;
    }
    return false;
}

pub fn statusName(status: provider.RevisionSymbolStatus) []const u8 {
    return @tagName(status);
}

pub fn kindName(kind: provider.SymbolKind) []const u8 {
    return @tagName(kind);
}

pub fn providerStateName(state: provider.Failure) []const u8 {
    return @tagName(state);
}

pub fn confidenceName(confidence: provider.Confidence) []const u8 {
    return @tagName(confidence);
}

test "historical symbol display summary uses human symbol limit" {
    var aggregates = [_]@import("historical_symbol_attribution.zig").AggregateRecord{
        .{ .parent_path = undefined, .symbol_kind = null, .symbol_name = null, .revision_range = null, .status = .unknown, .change_count = 1, .added_line_pressure = 0, .deleted_line_pressure = 0, .latest_timestamp = null, .sample_commit_ids = &.{}, .provider_state = .ok, .confidence = .low, .caveats = &.{}, .fallback_count = 0, .sort_key = undefined },
        .{ .parent_path = undefined, .symbol_kind = null, .symbol_name = null, .revision_range = null, .status = .unknown, .change_count = 1, .added_line_pressure = 0, .deleted_line_pressure = 0, .latest_timestamp = null, .sample_commit_ids = &.{}, .provider_state = .skipped, .confidence = .low, .caveats = &.{}, .fallback_count = 2, .sort_key = undefined },
    };
    const report = model.HistoricalSymbolReport{ .candidate_path_count = 2, .retained_candidate_path_count = 2, .aggregate_record_bound = 128, .aggregate_record_bound_exceeded = false, .aggregates = aggregates[0..], .caveats = &.{} };
    const summary = displaySummary(report, .{ .limit = 1, .explicit_limit = true });
    try std.testing.expectEqual(@as(usize, 2), summary.total);
    try std.testing.expectEqual(@as(usize, 1), summary.shown);
    try std.testing.expectEqual(@as(usize, 1), summary.omitted);
    try std.testing.expectEqualStrings("explicit", summary.limitSource());
    const states = providerStateSummary(report);
    try std.testing.expectEqual(@as(usize, 1), states.ok);
    try std.testing.expectEqual(@as(usize, 1), states.skipped);
    try std.testing.expectEqual(@as(usize, 1), states.fallback_record_count);
    try std.testing.expectEqual(@as(usize, 2), states.fallback_count);
}
