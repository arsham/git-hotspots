const std = @import("std");
const provider = @import("provider.zig");
const model = @import("model.zig");
const git_runner = @import("git_runner.zig");

const BlameRange = struct {
    commit: []const u8,
    result_start: u32,
    span: u32,
    timestamp: ?i64 = null,
};

const LineTouch = struct { commit: []const u8, timestamp: ?i64 };

const CommitTouch = struct { commit: []const u8, timestamp: ?i64 };

pub fn attachCurrentLineHistory(allocator: std.mem.Allocator, io: std.Io, analysis: *model.Analysis) !void {
    if (analysis.inspect) |inspect| {
        if (analysis.symbol_report == null) return;
        try attachCurrentLineHistoryForPath(allocator, io, analysis, inspect.matched_path, analysis.symbol_report.?.symbols, "inspected file");
    } else if (analysis.project_symbol_report) |project_symbols| {
        for (project_symbols.files) |file| {
            try attachCurrentLineHistoryForPath(allocator, io, analysis, file.file_path, file.symbols, "ranked file");
        }
    }
}

fn attachCurrentLineHistoryForPath(allocator: std.mem.Allocator, io: std.Io, analysis: *model.Analysis, path: []const u8, symbols: []provider.CurrentSymbolEvidence, file_label: []const u8) !void {
    if (symbols.len == 0) return;
    if (!symbolsHaveValidLineRanges(symbols)) {
        try attachFailureLineHistory(allocator, symbols, .unknown, .skipped, .low, &.{"current-line Git evidence skipped: no valid current symbol line ranges"});
        return;
    }

    const dirty_out = git_runner.runGitOk(allocator, io, analysis.repo_root, &.{ "status", "--porcelain", "--", path }) catch {
        try attachFailureLineHistoryFmt(allocator, symbols, .unknown, .failed, .low, "current-line Git evidence unavailable: could not check {s} status", .{file_label});
        return;
    };
    const inspected_dirty = std.mem.trim(u8, dirty_out, "\r\n ").len != 0;
    allocator.free(dirty_out);
    if (inspected_dirty) {
        try attachFailureLineHistoryFmt(allocator, symbols, .unknown, .skipped, .low, "current-line Git evidence skipped: {s} has staged or unstaged content changes", .{file_label});
        return;
    }

    const rr = git_runner.runGit(allocator, io, analysis.repo_root, &.{ "blame", "--incremental", "--", path }) catch {
        try attachFailureLineHistory(allocator, symbols, .unknown, .failed, .low, &.{"current-line Git evidence unavailable: local evidence command failed"});
        return;
    };
    defer allocator.free(rr.stdout);
    defer allocator.free(rr.stderr);
    switch (rr.term) {
        .exited => |code| if (code != 0) {
            try attachFailureLineHistory(allocator, symbols, .unknown, .failed, .low, &.{"current-line Git evidence unavailable: local evidence command failed"});
            return;
        },
        else => {
            try attachFailureLineHistory(allocator, symbols, .unknown, .failed, .low, &.{"current-line Git evidence unavailable: local evidence command failed"});
            return;
        },
    }

    var ranges = parseIncrementalBlame(allocator, rr.stdout) catch {
        try attachFailureLineHistory(allocator, symbols, .unknown, .failed, .low, &.{"current-line Git evidence unavailable: local evidence output could not be parsed safely"});
        return;
    };
    defer ranges.deinit();
    try attachAggregatedLineHistory(allocator, symbols, ranges.items, analysis.history.is_shallow, analysis.history.is_partial);
}

fn attachFailureLineHistory(allocator: std.mem.Allocator, symbols: []provider.CurrentSymbolEvidence, freshness: provider.Freshness, failure: provider.Failure, confidence: provider.Confidence, caveats: []const []const u8) !void {
    for (symbols) |*symbol| {
        const range = symbolLineRange(symbol.*);
        const line_count = rangeLineCount(range);
        symbol.current_line_history = .{
            .line_count = line_count,
            .distinct_last_touch_commit_count = 0,
            .most_recent_line_touched_timestamp = null,
            .uncommitted_or_unblamable_line_count = line_count,
            .sample_commits = try allocator.alloc([]const u8, 0),
            .freshness = freshness,
            .failure = failure,
            .confidence = confidence,
            .caveats = try dupeStringList(allocator, caveats),
        };
    }
}

fn attachFailureLineHistoryFmt(allocator: std.mem.Allocator, symbols: []provider.CurrentSymbolEvidence, freshness: provider.Freshness, failure: provider.Failure, confidence: provider.Confidence, comptime template: []const u8, args: anytype) !void {
    const caveat = try std.fmt.allocPrint(allocator, template, args);
    defer allocator.free(caveat);
    try attachFailureLineHistory(allocator, symbols, freshness, failure, confidence, &.{caveat});
}

fn addCaveat(allocator: std.mem.Allocator, list: *std.array_list.Managed([]const u8), text: []const u8) !void {
    try list.append(try allocator.dupe(u8, text));
}

fn dupeStringList(allocator: std.mem.Allocator, values: []const []const u8) ![][]const u8 {
    const out = try allocator.alloc([]const u8, values.len);
    var initialized: usize = 0;
    errdefer {
        for (out[0..initialized]) |duped| allocator.free(duped);
        allocator.free(out);
    }
    for (values) |value| {
        out[initialized] = try allocator.dupe(u8, value);
        initialized += 1;
    }
    return out;
}

fn symbolsHaveValidLineRanges(symbols: []const provider.CurrentSymbolEvidence) bool {
    for (symbols) |symbol| {
        switch (symbol.current_range) {
            .lines => |range| if (range.start == 0 or range.end < range.start) return false,
            .bytes => return false,
        }
    }
    return true;
}

pub fn parseIncrementalBlame(allocator: std.mem.Allocator, stdout: []const u8) !std.array_list.Managed(BlameRange) {
    var ranges = std.array_list.Managed(BlameRange).init(allocator);
    errdefer ranges.deinit();
    var current_index: ?usize = null;
    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, "\r");
        if (parseBlameHeader(line)) |header| {
            try ranges.append(header);
            current_index = ranges.items.len - 1;
            if (findKnownTimestamp(ranges.items[0 .. ranges.items.len - 1], header.commit)) |ts| ranges.items[current_index.?].timestamp = ts;
            continue;
        }
        if (std.mem.startsWith(u8, line, "author-time ")) {
            if (current_index) |idx| {
                const value = line["author-time ".len..];
                ranges.items[idx].timestamp = std.fmt.parseInt(i64, value, 10) catch ranges.items[idx].timestamp;
                if (ranges.items[idx].timestamp) |ts| updateKnownTimestamp(ranges.items, ranges.items[idx].commit, ts);
            }
        }
    }
    if (ranges.items.len == 0 and std.mem.trim(u8, stdout, "\r\n ").len != 0) return error.InvalidBlame;
    return ranges;
}

fn findKnownTimestamp(ranges: []const BlameRange, commit: []const u8) ?i64 {
    for (ranges) |range| {
        if (std.mem.eql(u8, range.commit, commit)) return range.timestamp;
    }
    return null;
}

fn updateKnownTimestamp(ranges: []BlameRange, commit: []const u8, timestamp: i64) void {
    for (ranges) |*range| {
        if (std.mem.eql(u8, range.commit, commit) and range.timestamp == null) range.timestamp = timestamp;
    }
}

fn parseBlameHeader(line: []const u8) ?BlameRange {
    var fields = std.mem.splitScalar(u8, line, ' ');
    const commit = fields.next() orelse return null;
    if (!isCommitObjectId(commit)) return null;
    _ = fields.next() orelse return null;
    const result_start_text = fields.next() orelse return null;
    const span_text = fields.next() orelse return null;
    const result_start = std.fmt.parseInt(u32, result_start_text, 10) catch return null;
    const span = std.fmt.parseInt(u32, span_text, 10) catch return null;
    if (result_start == 0) return null;
    return .{ .commit = commit, .result_start = result_start, .span = span };
}

fn isCommitObjectId(value: []const u8) bool {
    if (value.len < 12 or value.len > 64) return false;
    for (value) |c| if (!std.ascii.isHex(c)) return false;
    return true;
}

pub fn attachAggregatedLineHistory(allocator: std.mem.Allocator, symbols: []provider.CurrentSymbolEvidence, ranges: []const BlameRange, is_shallow: bool, is_partial: bool) !void {
    for (symbols) |*symbol| {
        const range = symbolLineRange(symbol.*);
        symbol.current_line_history = try aggregateSymbolLineHistory(allocator, range, ranges, is_shallow, is_partial);
    }
}

fn aggregateSymbolLineHistory(allocator: std.mem.Allocator, range: provider.LineRange, ranges: []const BlameRange, is_shallow: bool, is_partial: bool) !provider.CurrentLineHistoryEvidence {
    const line_count = rangeLineCount(range);
    var caveats = std.array_list.Managed([]const u8).init(allocator);
    errdefer {
        for (caveats.items) |c| allocator.free(c);
        caveats.deinit();
    }
    if (line_count == 0) try addCaveat(allocator, &caveats, "current-line Git evidence unavailable: symbol range has zero lines");
    if (is_shallow) try addCaveat(allocator, &caveats, "current-line Git evidence may be incomplete: repository history is shallow; auto_fetch is false");
    if (is_partial) try addCaveat(allocator, &caveats, "current-line Git evidence may be incomplete: repository history may be partial/promisor; auto_fetch is false");

    var commits = std.array_list.Managed(CommitTouch).init(allocator);
    defer commits.deinit();
    var unblamable: u32 = 0;
    var most_recent: ?i64 = null;
    var missing_timestamp = false;

    var line = range.start;
    while (line_count > 0 and line <= range.end) : (line += 1) {
        const touch = touchForLine(ranges, line) orelse {
            unblamable += 1;
            continue;
        };
        if (isZeroObjectId(touch.commit)) {
            unblamable += 1;
            continue;
        }
        if (touch.timestamp) |ts| {
            if (most_recent == null or ts > most_recent.?) most_recent = ts;
        } else missing_timestamp = true;
        try noteCommitTouch(&commits, touch);
        if (line == std.math.maxInt(u32)) break;
    }
    if (unblamable > 0) try addCaveat(allocator, &caveats, "current-line Git evidence has unblamable lines in this symbol range");
    if (missing_timestamp) try addCaveat(allocator, &caveats, "current-line Git evidence has commit ids without approved timestamp fields");

    std.mem.sort(CommitTouch, commits.items, {}, commitTouchLessThan);
    const sample_len = @min(commits.items.len, 3);
    const sample = try allocator.alloc([]const u8, sample_len);
    errdefer allocator.free(sample);
    var sample_i: usize = 0;
    errdefer for (sample[0..sample_i]) |commit| allocator.free(commit);
    for (commits.items[0..sample_len]) |commit| {
        sample[sample_i] = try allocator.dupe(u8, commit.commit[0..@min(commit.commit.len, 12)]);
        sample_i += 1;
    }

    return .{
        .line_count = line_count,
        .distinct_last_touch_commit_count = commits.items.len,
        .most_recent_line_touched_timestamp = most_recent,
        .uncommitted_or_unblamable_line_count = unblamable,
        .sample_commits = sample,
        .freshness = if (is_shallow or is_partial or unblamable > 0 or missing_timestamp) .partial else .fresh,
        .failure = if (line_count == 0) .skipped else .ok,
        .confidence = if (line_count == 0 or unblamable == line_count) .low else if (caveats.items.len > 0) .medium else .high,
        .caveats = try caveats.toOwnedSlice(),
    };
}

fn symbolLineRange(symbol: provider.CurrentSymbolEvidence) provider.LineRange {
    return switch (symbol.current_range) {
        .lines => |lines| lines,
        .bytes => .{ .start = 1, .end = 0 },
    };
}

fn rangeLineCount(range: provider.LineRange) u32 {
    if (range.end < range.start) return 0;
    return range.end - range.start + 1;
}

fn touchForLine(ranges: []const BlameRange, line: u32) ?LineTouch {
    for (ranges) |range| {
        if (range.span == 0) continue;
        const end = range.result_start +| (range.span - 1);
        if (line >= range.result_start and line <= end) return .{ .commit = range.commit, .timestamp = range.timestamp };
    }
    return null;
}

fn isZeroObjectId(commit: []const u8) bool {
    for (commit) |c| if (c != '0') return false;
    return true;
}

fn noteCommitTouch(commits: *std.array_list.Managed(CommitTouch), touch: LineTouch) !void {
    for (commits.items) |*existing| {
        if (std.mem.eql(u8, existing.commit, touch.commit)) {
            if (touch.timestamp) |ts| {
                if (existing.timestamp == null or ts > existing.timestamp.?) existing.timestamp = ts;
            }
            return;
        }
    }
    try commits.append(.{ .commit = touch.commit, .timestamp = touch.timestamp });
}

fn commitTouchLessThan(_: void, lhs: CommitTouch, rhs: CommitTouch) bool {
    const lhs_ts = lhs.timestamp orelse std.math.minInt(i64);
    const rhs_ts = rhs.timestamp orelse std.math.minInt(i64);
    if (lhs_ts != rhs_ts) return lhs_ts > rhs_ts;
    return std.mem.lessThan(u8, lhs.commit, rhs.commit);
}

fn freeCurrentLineHistory(allocator: std.mem.Allocator, line_history: provider.CurrentLineHistoryEvidence) void {
    for (line_history.sample_commits) |commit| allocator.free(commit);
    allocator.free(line_history.sample_commits);
    for (line_history.caveats) |caveat| allocator.free(caveat);
    allocator.free(line_history.caveats);
}

test "incremental blame parser ignores private and unapproved fields" {
    const text =
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa 1 1 2\n" ++
        "author redacted\n" ++
        "author-mail <>\n" ++
        "summary redacted\n" ++
        "filename redacted\n" ++
        "author-time 1770000000\n" ++
        "\t\n";
    var ranges = try parseIncrementalBlame(std.testing.allocator, text);
    defer ranges.deinit();
    try std.testing.expectEqual(@as(usize, 1), ranges.items.len);
    try std.testing.expectEqualStrings("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", ranges.items[0].commit);
    try std.testing.expectEqual(@as(u32, 1), ranges.items[0].result_start);
    try std.testing.expectEqual(@as(u32, 2), ranges.items[0].span);
    try std.testing.expectEqual(@as(i64, 1770000000), ranges.items[0].timestamp.?);
}

test "current-line aggregation handles ranges, unblamable lines, missing timestamps, and ordering" {
    const ranges = [_]BlameRange{
        .{ .commit = "bbbbbbbbbbbb", .result_start = 1, .span = 1, .timestamp = 20 },
        .{ .commit = "aaaaaaaaaaaa", .result_start = 2, .span = 1, .timestamp = 20 },
        .{ .commit = "cccccccccccc", .result_start = 3, .span = 1, .timestamp = null },
    };
    const line_history = try aggregateSymbolLineHistory(std.testing.allocator, .{ .start = 1, .end = 4 }, &ranges, false, true);
    defer freeCurrentLineHistory(std.testing.allocator, line_history);
    try std.testing.expectEqual(@as(u32, 4), line_history.line_count);
    try std.testing.expectEqual(@as(usize, 3), line_history.distinct_last_touch_commit_count);
    try std.testing.expectEqual(@as(i64, 20), line_history.most_recent_line_touched_timestamp.?);
    try std.testing.expectEqual(@as(u32, 1), line_history.uncommitted_or_unblamable_line_count);
    try std.testing.expectEqual(provider.Freshness.partial, line_history.freshness);
    try std.testing.expectEqual(provider.Failure.ok, line_history.failure);
    try std.testing.expectEqual(provider.Confidence.medium, line_history.confidence);
    try std.testing.expectEqual(@as(usize, 3), line_history.sample_commits.len);
    try std.testing.expectEqualStrings("aaaaaaaaaaaa", line_history.sample_commits[0]);
    try std.testing.expectEqualStrings("bbbbbbbbbbbb", line_history.sample_commits[1]);
    try std.testing.expectEqualStrings("cccccccccccc", line_history.sample_commits[2]);
    try std.testing.expect(line_history.caveats.len >= 3);
}

test "current-line aggregation degrades zero-line ranges" {
    const line_history = try aggregateSymbolLineHistory(std.testing.allocator, .{ .start = 4, .end = 3 }, &.{}, false, false);
    defer freeCurrentLineHistory(std.testing.allocator, line_history);
    try std.testing.expectEqual(@as(u32, 0), line_history.line_count);
    try std.testing.expectEqual(provider.Freshness.fresh, line_history.freshness);
    try std.testing.expectEqual(provider.Failure.skipped, line_history.failure);
    try std.testing.expectEqual(provider.Confidence.low, line_history.confidence);
    try std.testing.expectEqual(@as(usize, 1), line_history.caveats.len);
}
