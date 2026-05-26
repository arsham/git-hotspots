const std = @import("std");
const model = @import("model.zig");
const provider = @import("provider.zig");
const fmt = @import("report_format.zig");

pub const LineDisplayRange = struct { start: u32, end: u32 };

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

pub fn displaySummary(symbols: model.SymbolReport, display: model.SymbolDisplay) DisplaySummary {
    const shown = @min(symbols.symbols.len, display.limit);
    return .{
        .total = symbols.symbols.len,
        .shown = shown,
        .omitted = symbols.symbols.len - shown,
        .limit = display.limit,
        .explicit_limit = display.explicit_limit,
    };
}

pub fn sortBasis(symbols: model.SymbolReport) []const u8 {
    return if (haveLineHistory(symbols.symbols)) "current-line Git evidence summary" else "provider order";
}

pub fn displayLineRange(range: provider.CurrentRange) LineDisplayRange {
    return switch (range) {
        .lines => |lines| .{ .start = lines.start, .end = lines.end },
        .bytes => .{ .start = 0, .end = 0 },
    };
}

pub fn haveLineHistory(symbols: []const provider.CurrentSymbolEvidence) bool {
    for (symbols) |symbol| if (symbol.current_line_history != null) return true;
    return false;
}

pub fn orderedHumanIndexes(allocator: std.mem.Allocator, symbols: []const provider.CurrentSymbolEvidence) ![]usize {
    const indexes = try allocator.alloc(usize, symbols.len);
    for (indexes, 0..) |*index, i| index.* = i;
    if (haveLineHistory(symbols)) {
        std.mem.sort(usize, indexes, symbols, lessHumanSymbolIndex);
    }
    return indexes;
}

pub fn lineageIndicator(row: model.Result) []const u8 {
    if (row.lineage_partial) return "partial";
    if (row.lineage_aliases.len > 0) return "yes";
    return "no";
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

test "human symbol display limit keeps json-complete metadata separate" {
    var symbols = [_]provider.CurrentSymbolEvidence{
        .{ .path = "src/a.zig", .name = "alpha", .kind = .function, .current_range = .{ .lines = .{ .start = 10, .end = 12 } }, .provider_name = "tree-sitter-zig", .confidence = .high },
        .{ .path = "src/a.zig", .name = "beta", .kind = .function, .current_range = .{ .lines = .{ .start = 20, .end = 25 } }, .provider_name = "tree-sitter-zig", .confidence = .high },
        .{ .path = "src/a.zig", .name = "gamma", .kind = .function, .current_range = .{ .lines = .{ .start = 30, .end = 30 } }, .provider_name = "tree-sitter-zig", .confidence = .high },
    };
    const report_model = model.SymbolReport{ .provider = undefined, .symbols = symbols[0..] };
    const summary = displaySummary(report_model, .{ .limit = 2, .explicit_limit = true });
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
    const indexes = try orderedHumanIndexes(std.testing.allocator, symbols[0..]);
    defer std.testing.allocator.free(indexes);
    try std.testing.expectEqual(@as(usize, 1), indexes[0]);
    try std.testing.expectEqual(@as(usize, 2), indexes[1]);
    try std.testing.expectEqual(@as(usize, 0), indexes[2]);
}
