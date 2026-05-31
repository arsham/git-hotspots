const std = @import("std");
const model = @import("model.zig");
const provider = @import("provider.zig");

const RelationKindCount = struct {
    kind: provider.RelationKind,
    count: usize,
};

const Summary = struct {
    emitted: usize,
    counts: [@typeInfo(provider.RelationKind).@"enum".fields.len]RelationKindCount,
    count_len: usize,
    unknown: usize,
    unresolved: usize,
    unresolved_targets: usize,
    display_limit_omitted: usize,
    provider_cap_omitted: usize,
    provider_caps_reached: usize,
    record_bound_omitted: usize,
    record_bound_exceeded: bool,
};

const kind_order = [_]provider.RelationKind{
    .contains,
    .reference,
    .call,
    .import_include,
    .unknown,
    .unresolved,
};

pub fn renderTable(writer: anytype, report: model.RelationAggregationReport, shown: usize) !void {
    if (report.records.len == 0) return;
    const summary = summarize(report, shown);
    try writer.writeAll("  evidence summary: ");
    try renderCompact(writer, summary);
    try writer.writeByte('\n');
}

pub fn renderMarkdown(writer: anytype, report: model.RelationAggregationReport, shown: usize) !void {
    if (report.records.len == 0) return;
    const summary = summarize(report, shown);
    try writer.writeAll("- Relationship evidence summary: ");
    try renderCompact(writer, summary);
    try writer.writeByte('\n');
}

fn summarize(report: model.RelationAggregationReport, shown: usize) Summary {
    var summary = Summary{
        .emitted = report.records.len,
        .counts = undefined,
        .count_len = 0,
        .unknown = 0,
        .unresolved = 0,
        .unresolved_targets = 0,
        .display_limit_omitted = report.records.len - shown,
        .provider_cap_omitted = 0,
        .provider_caps_reached = 0,
        .record_bound_omitted = report.omitted_record_count,
        .record_bound_exceeded = report.relation_record_bound_exceeded,
    };

    for (kind_order) |kind| {
        const count = countKind(report.records, kind);
        if (count == 0) continue;
        summary.counts[summary.count_len] = .{ .kind = kind, .count = count };
        summary.count_len += 1;
        switch (kind) {
            .unknown => summary.unknown = count,
            .unresolved => summary.unresolved = count,
            else => {},
        }
    }

    for (report.records) |record| {
        if (std.mem.startsWith(u8, record.target_key, "unresolved:")) {
            summary.unresolved_targets += 1;
        }
    }
    for (report.providers) |provider_report| {
        summary.provider_cap_omitted += provider_report.omitted_count;
        if (provider_report.cap_reached) summary.provider_caps_reached += 1;
    }
    return summary;
}

fn countKind(records: []const model.RelationRecord, kind: provider.RelationKind) usize {
    var count: usize = 0;
    for (records) |record| {
        if (record.kind == kind) count += 1;
    }
    return count;
}

fn renderCompact(writer: anytype, summary: Summary) !void {
    try writer.print("emitted={d} kinds=", .{summary.emitted});
    for (summary.counts[0..summary.count_len], 0..) |entry, index| {
        if (index != 0) try writer.writeByte(',');
        try writer.print("{s}:{d}", .{ @tagName(entry.kind), entry.count });
    }
    if (summary.unknown > 0) try writer.print(" unknown={d}", .{summary.unknown});
    if (summary.unresolved > 0) try writer.print(" unresolved={d}", .{summary.unresolved});
    if (summary.unresolved_targets > 0) try writer.print(" unresolved_targets={d}", .{summary.unresolved_targets});

    if (summary.display_limit_omitted == 0 and summary.provider_cap_omitted == 0 and summary.record_bound_omitted == 0 and !summary.record_bound_exceeded) {
        try writer.writeAll(" omissions=none");
        return;
    }

    if (summary.display_limit_omitted > 0) try writer.print(" display_limit_omitted={d}", .{summary.display_limit_omitted});
    if (summary.provider_cap_omitted > 0 or summary.provider_caps_reached > 0) {
        try writer.print(" provider_cap_omitted={d} provider_caps_reached={d}", .{ summary.provider_cap_omitted, summary.provider_caps_reached });
    }
    if (summary.record_bound_omitted > 0 or summary.record_bound_exceeded) {
        try writer.print(" record_bound_omitted={d} record_bound_exceeded={}", .{ summary.record_bound_omitted, summary.record_bound_exceeded });
    }
}

fn testRecord(kind: provider.RelationKind, target_key: []const u8) model.RelationRecord {
    return .{
        .kind = kind,
        .direction = .source_to_target,
        .source_key = "source",
        .target_key = target_key,
        .evidence_basis = "basis",
        .provider_name = "provider",
        .provider_input_identity = "input",
        .freshness = .fresh,
        .failure = .ok,
        .confidence = .high,
        .caveats = &.{},
        .sort_key = "sort",
    };
}

fn testProvider(omitted_count: usize, cap_reached: bool) model.RelationProviderReport {
    return .{
        .file_path = "src/example.zig",
        .parent_rank = 1,
        .provider = .{
            .name = "provider",
            .kind = .relation,
            .version = "test",
            .input = .{ .identity = "working-tree:src/example.zig" },
            .freshness = .fresh,
            .failure = .ok,
            .confidence = .high,
            .caveats = &.{},
            .provenance = .{ .provider_name = "provider", .input_identity = "working-tree:src/example.zig" },
        },
        .candidate_count = 3,
        .omitted_count = omitted_count,
        .cap_reached = cap_reached,
    };
}

test "relationship summary counts present kinds and uncertainty only when present" {
    var records = [_]model.RelationRecord{
        testRecord(.contains, "target"),
        testRecord(.call, "unresolved:missing"),
        testRecord(.unknown, "other"),
    };
    var providers = [_]model.RelationProviderReport{testProvider(0, false)};
    const report: model.RelationAggregationReport = .{
        .candidate_file_count = 1,
        .retained_candidate_file_count = 1,
        .current_symbol_candidate_count = 3,
        .relation_record_bound = 8,
        .relation_record_bound_exceeded = false,
        .omitted_record_count = 0,
        .providers = providers[0..],
        .records = records[0..],
        .caveats = &.{},
    };

    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    try renderTable(&out.writer, report, records.len);
    try std.testing.expectEqualStrings("  evidence summary: emitted=3 kinds=contains:1,call:1,unknown:1 unknown=1 unresolved_targets=1 omissions=none\n", out.written());
}

test "relationship summary distinguishes display limit from provider and record caps" {
    var records = [_]model.RelationRecord{
        testRecord(.contains, "target"),
        testRecord(.reference, "target"),
        testRecord(.unresolved, "unresolved:missing"),
    };
    var providers = [_]model.RelationProviderReport{testProvider(2, true)};
    const report: model.RelationAggregationReport = .{
        .candidate_file_count = 1,
        .retained_candidate_file_count = 1,
        .current_symbol_candidate_count = 3,
        .relation_record_bound = 3,
        .relation_record_bound_exceeded = true,
        .omitted_record_count = 1,
        .providers = providers[0..],
        .records = records[0..],
        .caveats = &.{},
    };

    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    try renderMarkdown(&out.writer, report, 1);
    try std.testing.expectEqualStrings("- Relationship evidence summary: emitted=3 kinds=contains:1,reference:1,unresolved:1 unresolved=1 unresolved_targets=1 display_limit_omitted=2 provider_cap_omitted=2 provider_caps_reached=1 record_bound_omitted=1 record_bound_exceeded=true\n", out.written());
}
