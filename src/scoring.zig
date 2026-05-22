const std = @import("std");
const model = @import("model.zig");

pub fn score(change_count: u32, churn: u64, last_ts: i64, head_ts: i64, cochange_total: u32) model.ScoreBreakdown {
    const frequency = @as(f64, @floatFromInt(change_count)) * 10.0;
    const churn_score = @min(@as(f64, @floatFromInt(churn)) / 25.0, 40.0);
    const age = @max(head_ts - last_ts, 0);
    const recency = if (age == 0) 20.0 else @max(0.0, 20.0 - (@as(f64, @floatFromInt(age)) / 86400.0));
    const cochange = @min(@as(f64, @floatFromInt(cochange_total)) * 2.0, 20.0);
    return .{
        .frequency = frequency,
        .churn = churn_score,
        .recency = recency,
        .cochange = cochange,
        .total = frequency + churn_score + recency + cochange,
    };
}

pub fn confidence(change_count: u32, caveat_count: usize) []const u8 {
    if (change_count >= 3 and caveat_count == 0) return "high";
    if (change_count >= 2) return "medium";
    return "low";
}

pub fn lessThan(_: void, lhs: model.Result, rhs: model.Result) bool {
    if (lhs.score.total != rhs.score.total) return lhs.score.total > rhs.score.total;
    if (lhs.change_count != rhs.change_count) return lhs.change_count > rhs.change_count;
    if (lhs.churn != rhs.churn) return lhs.churn > rhs.churn;
    if (lhs.last_changed_timestamp != rhs.last_changed_timestamp) return lhs.last_changed_timestamp > rhs.last_changed_timestamp;
    return std.mem.lessThan(u8, lhs.path, rhs.path);
}

test "tie breaks by path after equal evidence" {
    const a = model.Result{ .path = "a", .lineage_aliases = &.{}, .score = score(1, 1, 1, 1, 0), .change_count = 1, .additions = 1, .deletions = 0, .churn = 1, .last_changed_timestamp = 1, .last_changed_commit = "abc", .current_size = null, .cochanges = &.{}, .confidence = "low", .caveats = &.{}, .evidence = &.{} };
    const b = model.Result{ .path = "b", .lineage_aliases = &.{}, .score = score(1, 1, 1, 1, 0), .change_count = 1, .additions = 1, .deletions = 0, .churn = 1, .last_changed_timestamp = 1, .last_changed_commit = "abc", .current_size = null, .cochanges = &.{}, .confidence = "low", .caveats = &.{}, .evidence = &.{} };
    try std.testing.expect(lessThan({}, a, b));
}
