const std = @import("std");
const model = @import("model.zig");
const provider = @import("provider.zig");
const scoring = @import("scoring.zig");
const git_runner = @import("git_runner.zig");

pub const AnalyzeError = anyerror;

fn freeResult(allocator: std.mem.Allocator, r: *model.Result) void {
    allocator.free(r.path);
    for (r.lineage_aliases) |alias| allocator.free(alias);
    allocator.free(r.lineage_aliases);
    allocator.free(r.last_changed_commit);
    for (r.cochanges) |cc| allocator.free(cc.path);
    allocator.free(r.cochanges);
    for (r.caveats) |c| allocator.free(c);
    allocator.free(r.caveats);
    for (r.evidence) |ev| allocator.free(ev.commit);
    allocator.free(r.evidence);
}

const BlameRange = struct {
    commit: []const u8,
    result_start: u32,
    span: u32,
    timestamp: ?i64 = null,
};

const LineTouch = struct { commit: []const u8, timestamp: ?i64 };

const CommitTouch = struct { commit: []const u8, timestamp: ?i64 };

pub fn attachCurrentLineHistory(allocator: std.mem.Allocator, io: std.Io, analysis: *model.Analysis) !void {
    const inspect = analysis.inspect orelse return;
    if (analysis.symbol_report == null) return;
    if (analysis.symbol_report.?.symbols.len == 0) return;
    if (!symbolsHaveValidLineRanges(analysis.symbol_report.?.symbols)) {
        try attachFailureLineHistory(allocator, analysis.symbol_report.?.symbols, .unknown, .skipped, .low, &.{"current-line Git evidence skipped: no valid current symbol line ranges"});
        return;
    }

    const dirty_out = git_runner.runGitOk(allocator, io, analysis.repo_root, &.{ "status", "--porcelain", "--", inspect.matched_path }) catch {
        try attachFailureLineHistory(allocator, analysis.symbol_report.?.symbols, .unknown, .failed, .low, &.{"current-line Git evidence unavailable: could not check inspected file status"});
        return;
    };
    const inspected_dirty = std.mem.trim(u8, dirty_out, "\r\n ").len != 0;
    allocator.free(dirty_out);
    if (inspected_dirty) {
        try attachFailureLineHistory(allocator, analysis.symbol_report.?.symbols, .unknown, .skipped, .low, &.{"current-line Git evidence skipped: inspected file has staged or unstaged content changes"});
        return;
    }

    const rr = git_runner.runGit(allocator, io, analysis.repo_root, &.{ "blame", "--incremental", "--", inspect.matched_path }) catch {
        try attachFailureLineHistory(allocator, analysis.symbol_report.?.symbols, .unknown, .failed, .low, &.{"current-line Git evidence unavailable: local evidence command failed"});
        return;
    };
    defer allocator.free(rr.stdout);
    defer allocator.free(rr.stderr);
    switch (rr.term) {
        .exited => |code| if (code != 0) {
            try attachFailureLineHistory(allocator, analysis.symbol_report.?.symbols, .unknown, .failed, .low, &.{"current-line Git evidence unavailable: local evidence command failed"});
            return;
        },
        else => {
            try attachFailureLineHistory(allocator, analysis.symbol_report.?.symbols, .unknown, .failed, .low, &.{"current-line Git evidence unavailable: local evidence command failed"});
            return;
        },
    }

    var ranges = parseIncrementalBlame(allocator, rr.stdout) catch {
        try attachFailureLineHistory(allocator, analysis.symbol_report.?.symbols, .unknown, .failed, .low, &.{"current-line Git evidence unavailable: local evidence output could not be parsed safely"});
        return;
    };
    defer ranges.deinit();
    try attachAggregatedLineHistory(allocator, analysis.symbol_report.?.symbols, ranges.items, analysis.history.is_shallow, analysis.history.is_partial);
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

fn symbolsHaveValidLineRanges(symbols: []const provider.CurrentSymbolEvidence) bool {
    for (symbols) |symbol| {
        switch (symbol.current_range) {
            .lines => |range| if (range.start == 0 or range.end < range.start) return false,
            .bytes => return false,
        }
    }
    return true;
}

fn parseIncrementalBlame(allocator: std.mem.Allocator, stdout: []const u8) !std.array_list.Managed(BlameRange) {
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

fn attachAggregatedLineHistory(allocator: std.mem.Allocator, symbols: []provider.CurrentSymbolEvidence, ranges: []const BlameRange, is_shallow: bool, is_partial: bool) !void {
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

fn trimNewline(s: []u8) []const u8 {
    return std.mem.trim(u8, s, "\r\n ");
}

fn dupTrim(allocator: std.mem.Allocator, s: []u8) ![]u8 {
    return allocator.dupe(u8, std.mem.trim(u8, s, "\r\n "));
}

const EvidenceBuilder = struct { commit: []u8, timestamp: i64, additions: ?u64, deletions: ?u64 };
const FileAgg = struct {
    path: []u8,
    lineage_aliases: std.array_list.Managed([]u8),
    lineage_partial: bool = false,
    change_count: u32 = 0,
    additions: u64 = 0,
    deletions: u64 = 0,
    binary_count: u32 = 0,
    last_ts: i64 = 0,
    last_commit: []u8,
    large_commit: bool = false,
    evidence: std.array_list.Managed(EvidenceBuilder),
    cochanges: std.StringHashMap(u32),
};

fn deinitAgg(key: []const u8, agg: FileAgg, allocator: std.mem.Allocator) void {
    allocator.free(key);
    allocator.free(agg.path);
    for (agg.lineage_aliases.items) |alias| allocator.free(alias);
    agg.lineage_aliases.deinit();
    allocator.free(agg.last_commit);
    for (agg.evidence.items) |ev| allocator.free(ev.commit);
    agg.evidence.deinit();
    var it = agg.cochanges.keyIterator();
    while (it.next()) |k| allocator.free(k.*);
    var c = agg.cochanges;
    c.deinit();
}

fn addCaveat(allocator: std.mem.Allocator, list: *std.array_list.Managed([]const u8), text: []const u8) !void {
    try list.append(try allocator.dupe(u8, text));
}

fn newAgg(allocator: std.mem.Allocator, path: []const u8) !FileAgg {
    return .{
        .path = try allocator.dupe(u8, path),
        .lineage_aliases = std.array_list.Managed([]u8).init(allocator),
        .last_commit = try allocator.dupe(u8, ""),
        .evidence = std.array_list.Managed(EvidenceBuilder).init(allocator),
        .cochanges = std.StringHashMap(u32).init(allocator),
    };
}

fn pathPassesFilters(path: []const u8, include_prefixes: []const []const u8, exclude_prefixes: []const []const u8) bool {
    return !isExcludedPath(path, exclude_prefixes) and isIncludedPath(path, include_prefixes);
}

fn noteFilteredPath(
    allocator: std.mem.Allocator,
    path: []const u8,
    outside_include_paths: *std.StringHashMap(void),
    outside_include_change_count: *usize,
    excluded_paths: *std.StringHashMap(void),
    excluded_change_count: *usize,
    include_prefixes: []const []const u8,
    exclude_prefixes: []const []const u8,
) !void {
    if (isExcludedPath(path, exclude_prefixes)) {
        excluded_change_count.* += 1;
        if (excluded_paths.get(path) == null) {
            const owned = try allocator.dupe(u8, path);
            errdefer allocator.free(owned);
            try excluded_paths.put(owned, {});
        }
        return;
    }
    if (!isIncludedPath(path, include_prefixes)) {
        outside_include_change_count.* += 1;
        if (outside_include_paths.get(path) == null) {
            const owned = try allocator.dupe(u8, path);
            errdefer allocator.free(owned);
            try outside_include_paths.put(owned, {});
        }
    }
}

fn resolveAliasOwned(allocator: std.mem.Allocator, aliases: *std.StringHashMap([]u8), path: []const u8) ![]u8 {
    var current = path;
    var depth: usize = 0;
    while (aliases.get(current)) |next| {
        current = next;
        depth += 1;
        if (depth > 64) break;
    }
    return allocator.dupe(u8, current);
}

fn putAlias(allocator: std.mem.Allocator, aliases: *std.StringHashMap([]u8), old_path: []const u8, canonical: []const u8) !void {
    if (std.mem.eql(u8, old_path, canonical)) return;
    const gop = try aliases.getOrPut(old_path);
    if (gop.found_existing) {
        allocator.free(gop.value_ptr.*);
        gop.value_ptr.* = try allocator.dupe(u8, canonical);
    } else {
        gop.key_ptr.* = try allocator.dupe(u8, old_path);
        gop.value_ptr.* = try allocator.dupe(u8, canonical);
    }
}

fn addAliasToAgg(allocator: std.mem.Allocator, map: *std.StringHashMap(FileAgg), canonical: []const u8, alias: []const u8) !void {
    if (std.mem.eql(u8, canonical, alias)) return;
    const gop = try map.getOrPut(canonical);
    if (!gop.found_existing) {
        gop.key_ptr.* = try allocator.dupe(u8, canonical);
        gop.value_ptr.* = try newAgg(allocator, canonical);
    }
    for (gop.value_ptr.lineage_aliases.items) |existing| {
        if (std.mem.eql(u8, existing, alias)) return;
    }
    try gop.value_ptr.lineage_aliases.append(try allocator.dupe(u8, alias));
    std.mem.sort([]u8, gop.value_ptr.lineage_aliases.items, {}, stringSliceLessThan);
}

fn hasLineageAlias(row: model.Result, requested: []const u8) bool {
    for (row.lineage_aliases) |alias| {
        if (std.mem.eql(u8, alias, requested)) return true;
    }
    return false;
}

fn stringSliceLessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn freeStringList(allocator: std.mem.Allocator, values: []const []const u8) void {
    for (values) |value| allocator.free(value);
    allocator.free(values);
}

fn dupeStringList(allocator: std.mem.Allocator, values: []const []const u8) ![][]const u8 {
    const out = try allocator.alloc([]const u8, values.len);
    var initialized: usize = 0;
    errdefer {
        for (out[0..initialized]) |owned| allocator.free(owned);
        allocator.free(out);
    }
    for (values, 0..) |value, i| {
        out[i] = try allocator.dupe(u8, value);
        initialized += 1;
    }
    return out;
}

fn isTrueText(text: []u8) bool {
    return std.mem.eql(u8, std.mem.trim(u8, text, "\r\n "), "true");
}

fn writeProgress(progress: ?*std.Io.Writer, message: []const u8) !void {
    if (progress) |writer| {
        try writer.print("progress: {s}\n", .{message});
        try writer.flush();
    }
}

fn writeTimedProgress(progress: ?*std.Io.Writer, phase: []const u8, started: std.Io.Clock.Timestamp, io: std.Io) !void {
    if (progress) |writer| {
        const elapsed = started.durationTo(std.Io.Clock.Timestamp.now(io, .awake));
        try writer.print("progress: phase {s} {d}ms\n", .{ phase, elapsed.raw.toMilliseconds() });
        try writer.flush();
    }
}

const LogParser = struct {
    allocator: std.mem.Allocator,
    map: *std.StringHashMap(FileAgg),
    commit_paths: *std.array_list.Managed([]const u8),
    outside_include_paths: *std.StringHashMap(void),
    outside_include_change_count: *usize,
    excluded_paths: *std.StringHashMap(void),
    excluded_change_count: *usize,
    include_prefixes: []const []const u8,
    exclude_prefixes: []const []const u8,
    aliases: *std.StringHashMap([]u8),
    pending: std.array_list.Managed(u8),
    cur_hash: ?[]u8 = null,
    cur_ts: i64 = 0,
    commit_count: usize = 0,
    rename_detected: bool = false,
    partial_lineage: bool = false,

    fn init(
        allocator: std.mem.Allocator,
        map: *std.StringHashMap(FileAgg),
        commit_paths: *std.array_list.Managed([]const u8),
        outside_include_paths: *std.StringHashMap(void),
        outside_include_change_count: *usize,
        excluded_paths: *std.StringHashMap(void),
        excluded_change_count: *usize,
        include_prefixes: []const []const u8,
        exclude_prefixes: []const []const u8,
        aliases: *std.StringHashMap([]u8),
    ) LogParser {
        return .{
            .allocator = allocator,
            .map = map,
            .commit_paths = commit_paths,
            .outside_include_paths = outside_include_paths,
            .outside_include_change_count = outside_include_change_count,
            .excluded_paths = excluded_paths,
            .excluded_change_count = excluded_change_count,
            .include_prefixes = include_prefixes,
            .exclude_prefixes = exclude_prefixes,
            .aliases = aliases,
            .pending = std.array_list.Managed(u8).init(allocator),
        };
    }

    fn deinit(self: *LogParser) void {
        if (self.cur_hash) |hash| self.allocator.free(hash);
        self.pending.deinit();
    }

    fn feed(self: *LogParser, data: []const u8) !void {
        var rest = data;
        while (std.mem.indexOfScalar(u8, rest, '\n')) |newline| {
            const segment = rest[0..newline];
            if (self.pending.items.len == 0) {
                try self.processLine(segment);
            } else {
                try self.pending.appendSlice(segment);
                try self.processLine(self.pending.items);
                self.pending.clearRetainingCapacity();
            }
            rest = rest[newline + 1 ..];
        }
        if (rest.len > 0) try self.pending.appendSlice(rest);
    }

    fn finish(self: *LogParser) !void {
        if (self.pending.items.len > 0) {
            try self.processLine(self.pending.items);
            self.pending.clearRetainingCapacity();
        }
        try finishCommit(self.allocator, self.map, self.commit_paths.items);
    }

    fn processLine(self: *LogParser, raw_line: []const u8) !void {
        const line = std.mem.trim(u8, raw_line, "\r");
        if (line.len == 0) return;
        if (std.mem.indexOfScalar(u8, line, '\t')) |tab| {
            const first = line[0..tab];
            if (first.len == 40 and std.mem.indexOfScalar(u8, line[tab + 1 ..], '\t') == null) {
                try finishCommit(self.allocator, self.map, self.commit_paths.items);
                self.commit_paths.clearRetainingCapacity();
                if (self.cur_hash) |hash| self.allocator.free(hash);
                self.cur_hash = try self.allocator.dupe(u8, first);
                self.cur_ts = std.fmt.parseInt(i64, line[tab + 1 ..], 10) catch 0;
                self.commit_count += 1;
                return;
            }
        }
        const cur_hash = self.cur_hash orelse return;
        var parts = std.mem.splitScalar(u8, line, '\t');
        const add_s = parts.next() orelse return;
        const del_s = parts.next() orelse return;
        const path = parts.rest();
        if (path.len == 0) return;
        try applyNumstat(self.allocator, self.map, self.commit_paths, self.outside_include_paths, self.outside_include_change_count, self.excluded_paths, self.excluded_change_count, self.include_prefixes, self.exclude_prefixes, self.aliases, &self.rename_detected, &self.partial_lineage, cur_hash, self.cur_ts, add_s, del_s, path);
    }
};

const git_stderr_limit = 1024 * 1024;

fn streamGitLog(
    allocator: std.mem.Allocator,
    io: std.Io,
    repo: []const u8,
    args: []const []const u8,
    parser: *LogParser,
) !void {
    var argv = std.array_list.Managed([]const u8).init(allocator);
    defer argv.deinit();
    try argv.append("git");
    try argv.append("-c");
    try argv.append("core.quotePath=false");
    try argv.append("-C");
    try argv.append(repo);
    for (args) |arg| try argv.append(arg);

    var child = try std.process.spawn(io, .{ .argv = argv.items, .stdin = .ignore, .stdout = .pipe, .stderr = .pipe });
    defer child.kill(io);

    var multi_reader_buffer: std.Io.File.MultiReader.Buffer(2) = undefined;
    var multi_reader: std.Io.File.MultiReader = undefined;
    multi_reader.init(allocator, io, multi_reader_buffer.toStreams(), &.{ child.stdout.?, child.stderr.? });
    defer multi_reader.deinit();

    const stdout_reader = multi_reader.reader(0);
    const stderr_reader = multi_reader.reader(1);

    while (multi_reader.fill(1, .none)) |_| {
        const available = stdout_reader.buffered();
        if (available.len > 0) {
            try parser.feed(available);
            stdout_reader.toss(available.len);
        }
        if (stderr_reader.bufferedLen() > git_stderr_limit) return error.StreamTooLong;
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => |e| return e,
    }

    const remaining = stdout_reader.buffered();
    if (remaining.len > 0) {
        try parser.feed(remaining);
        stdout_reader.toss(remaining.len);
    }
    try parser.finish();
    try multi_reader.checkAnyError();

    const term = try child.wait(io);
    switch (term) {
        .exited => |code| if (code == 0) return,
        else => {},
    }
    return error.GitFailed;
}

pub fn analyze(allocator: std.mem.Allocator, io: std.Io, cfg: model.Config, progress: ?*std.Io.Writer) AnalyzeError!model.Analysis {
    var phase_started = std.Io.Clock.Timestamp.now(io, .awake);
    try writeProgress(progress, "checking repository");

    const bare_out = git_runner.runGitOk(allocator, io, cfg.repo_path, &.{ "rev-parse", "--is-bare-repository" }) catch return error.NotGitRepository;
    defer allocator.free(bare_out);
    if (isTrueText(bare_out)) return error.BareRepository;

    const inside_out = git_runner.runGitOk(allocator, io, cfg.repo_path, &.{ "rev-parse", "--is-inside-work-tree" }) catch return error.NotGitRepository;
    defer allocator.free(inside_out);
    if (!isTrueText(inside_out)) return error.NotGitRepository;

    const root_out = try git_runner.runGitOk(allocator, io, cfg.repo_path, &.{ "rev-parse", "--show-toplevel" });
    const repo_root = try dupTrim(allocator, root_out);
    allocator.free(root_out);
    errdefer allocator.free(repo_root);

    const head_out = git_runner.runGitOk(allocator, io, cfg.repo_path, &.{ "rev-parse", "HEAD" }) catch return error.EmptyRepository;
    const head = try dupTrim(allocator, head_out);
    allocator.free(head_out);
    errdefer allocator.free(head);

    const head_ts_out = try git_runner.runGitOk(allocator, io, cfg.repo_path, &.{ "show", "-s", "--format=%ct", "HEAD" });
    const head_ts = try std.fmt.parseInt(i64, trimNewline(head_ts_out), 10);
    allocator.free(head_ts_out);

    const shallow_out = git_runner.runGitOk(allocator, io, cfg.repo_path, &.{ "rev-parse", "--is-shallow-repository" }) catch try allocator.dupe(u8, "false");
    const is_shallow = isTrueText(shallow_out);
    allocator.free(shallow_out);

    const promisor = git_runner.runGit(allocator, io, cfg.repo_path, &.{ "config", "--get", "remote.origin.promisor" }) catch null;
    var is_partial = false;
    if (promisor) |p| {
        is_partial = switch (p.term) {
            .exited => |code| code == 0 and isTrueText(p.stdout),
            else => false,
        };
        allocator.free(p.stdout);
        allocator.free(p.stderr);
    }

    const dirty_out = try git_runner.runGitOk(allocator, io, cfg.repo_path, &.{ "status", "--porcelain" });
    const dirty = std.mem.trim(u8, dirty_out, "\r\n ").len != 0;
    allocator.free(dirty_out);

    var range_owned: ?[]u8 = null;
    var log_args = std.array_list.Managed([]const u8).init(allocator);
    defer log_args.deinit();
    try log_args.appendSlice(&.{ "log", "--format=%H%x09%ct", "--numstat", "--find-renames=40%" });
    if (cfg.since) |since| {
        const check = git_runner.runGit(allocator, io, cfg.repo_path, &.{ "rev-parse", "--verify", since }) catch return error.InvalidSince;
        defer allocator.free(check.stdout);
        defer allocator.free(check.stderr);
        switch (check.term) {
            .exited => |code| if (code != 0) return error.InvalidSince,
            else => return error.InvalidSince,
        }
        range_owned = try std.fmt.allocPrint(allocator, "{s}..HEAD", .{since});
        try log_args.append(range_owned.?);
    }
    errdefer if (range_owned) |r| allocator.free(r);

    try writeTimedProgress(progress, "repository-check", phase_started, io);

    phase_started = std.Io.Clock.Timestamp.now(io, .awake);
    try writeProgress(progress, "reading Git history");

    var map = std.StringHashMap(FileAgg).init(allocator);
    defer {
        var it = map.iterator();
        while (it.next()) |entry| deinitAgg(entry.key_ptr.*, entry.value_ptr.*, allocator);
        map.deinit();
    }

    var excluded_paths = std.StringHashMap(void).init(allocator);
    defer {
        var it = excluded_paths.keyIterator();
        while (it.next()) |key| allocator.free(key.*);
        excluded_paths.deinit();
    }
    var outside_include_paths = std.StringHashMap(void).init(allocator);
    defer {
        var it = outside_include_paths.keyIterator();
        while (it.next()) |key| allocator.free(key.*);
        outside_include_paths.deinit();
    }
    var outside_include_change_count: usize = 0;
    var excluded_change_count: usize = 0;

    var aliases = std.StringHashMap([]u8).init(allocator);
    defer {
        var alias_it = aliases.iterator();
        while (alias_it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        aliases.deinit();
    }

    var commit_count: usize = 0;
    var commit_paths = std.array_list.Managed([]const u8).init(allocator);
    defer commit_paths.deinit();

    var parser = LogParser.init(allocator, &map, &commit_paths, &outside_include_paths, &outside_include_change_count, &excluded_paths, &excluded_change_count, cfg.include_prefixes, cfg.exclude_prefixes, &aliases);
    defer parser.deinit();
    try streamGitLog(allocator, io, cfg.repo_path, log_args.items, &parser);
    commit_count = parser.commit_count;

    if (commit_count == 0) return error.EmptyRepository;

    try writeTimedProgress(progress, "git-read-parse", phase_started, io);

    var caveats = std.array_list.Managed([]const u8).init(allocator);
    errdefer {
        for (caveats.items) |c| allocator.free(c);
        caveats.deinit();
    }
    if (is_shallow) try addCaveat(allocator, &caveats, "history is shallow; auto_fetch is false");
    if (is_partial) try addCaveat(allocator, &caveats, "history may be partial/promisor; auto_fetch is false");
    if (dirty) try addCaveat(allocator, &caveats, "dirty worktree detected; ranking uses committed history only");
    if (parser.rename_detected) try addCaveat(allocator, &caveats, "Git rename lineage is conservative: local --find-renames=40% file edges only; copies, splits, merges, and symbol moves are not tracked");
    if (parser.partial_lineage) try addCaveat(allocator, &caveats, "some observed rename edges were outside active scope filters; lineage may be partial");

    phase_started = std.Io.Clock.Timestamp.now(io, .awake);
    try writeProgress(progress, "scoring files");

    var results = std.array_list.Managed(model.Result).init(allocator);
    errdefer {
        for (results.items) |*r| freeResult(allocator, r);
        results.deinit();
    }

    var it2 = map.iterator();
    while (it2.next()) |entry| try appendResult(allocator, io, &results, repo_root, entry.value_ptr.*, head_ts);
    std.mem.sort(model.Result, results.items, {}, scoring.lessThan);

    var inspect: ?model.Inspect = null;
    errdefer if (inspect) |meta| {
        allocator.free(meta.requested_path);
        allocator.free(meta.matched_path);
    };
    if (cfg.inspect_path) |requested| {
        var found_index: ?usize = null;
        for (results.items, 0..) |row, i| {
            if (std.mem.eql(u8, row.path, requested) or hasLineageAlias(row, requested)) {
                found_index = i;
                break;
            }
        }
        const keep_index = found_index orelse return error.InspectTargetNotFound;
        const rank = keep_index + 1;
        if (keep_index != 0) std.mem.swap(model.Result, &results.items[0], &results.items[keep_index]);
        for (results.items[1..]) |*r| freeResult(allocator, r);
        results.shrinkRetainingCapacity(1);
        const requested_path = try allocator.dupe(u8, requested);
        errdefer allocator.free(requested_path);
        const matched_path = try allocator.dupe(u8, results.items[0].path);
        inspect = .{
            .requested_path = requested_path,
            .matched_path = matched_path,
            .rank = rank,
        };
    } else if (results.items.len > cfg.limit) {
        for (results.items[cfg.limit..]) |*r| {
            freeResult(allocator, r);
        }
        results.shrinkRetainingCapacity(cfg.limit);
    }

    try writeTimedProgress(progress, "score-results", phase_started, io);

    const scope_include_prefixes = try dupeStringList(allocator, cfg.include_prefixes);
    errdefer freeStringList(allocator, scope_include_prefixes);
    const scope_exclude_prefixes = try dupeStringList(allocator, cfg.exclude_prefixes);
    errdefer freeStringList(allocator, scope_exclude_prefixes);

    return .{
        .allocator = allocator,
        .repo_root = repo_root,
        .history = .{ .head = head, .head_timestamp = head_ts, .range = range_owned, .is_shallow = is_shallow, .is_partial = is_partial, .dirty_worktree = dirty, .commit_count = commit_count },
        .scope = .{ .selected_scope = cfg.scope, .filters_active = cfg.scope != .all or cfg.include_prefixes.len > 0 or cfg.exclude_prefixes.len > 0, .include_prefixes = scope_include_prefixes, .exclude_prefixes = scope_exclude_prefixes, .outside_include_path_count = outside_include_paths.count(), .outside_include_change_count = outside_include_change_count, .excluded_path_count = excluded_paths.count(), .excluded_change_count = excluded_change_count },
        .inspect = inspect,
        .results = try results.toOwnedSlice(),
        .caveats = try caveats.toOwnedSlice(),
    };
}

fn applyNumstat(
    allocator: std.mem.Allocator,
    map: *std.StringHashMap(FileAgg),
    commit_paths: *std.array_list.Managed([]const u8),
    outside_include_paths: *std.StringHashMap(void),
    outside_include_change_count: *usize,
    excluded_paths: *std.StringHashMap(void),
    excluded_change_count: *usize,
    include_prefixes: []const []const u8,
    exclude_prefixes: []const []const u8,
    aliases: *std.StringHashMap([]u8),
    rename_detected: *bool,
    partial_lineage: *bool,
    commit: []const u8,
    ts: i64,
    add_s: []const u8,
    del_s: []const u8,
    raw_path: []const u8,
) !void {
    var path = try normalizePath(allocator, raw_path);
    defer allocator.free(path);
    var row_lineage_partial = false;
    if (try parseRenamePath(allocator, raw_path)) |rename| {
        defer {
            allocator.free(rename.old_path);
            allocator.free(rename.new_path);
        }
        rename_detected.* = true;
        const old_ok = pathPassesFilters(rename.old_path, include_prefixes, exclude_prefixes);
        const new_ok = pathPassesFilters(rename.new_path, include_prefixes, exclude_prefixes);
        if (old_ok and new_ok) {
            const canonical_new = try resolveAliasOwned(allocator, aliases, rename.new_path);
            defer allocator.free(canonical_new);
            try putAlias(allocator, aliases, rename.old_path, canonical_new);
            try addAliasToAgg(allocator, map, canonical_new, rename.old_path);
            allocator.free(path);
            path = try allocator.dupe(u8, canonical_new);
        } else {
            partial_lineage.* = true;
            row_lineage_partial = true;
            if (!old_ok) try noteFilteredPath(allocator, rename.old_path, outside_include_paths, outside_include_change_count, excluded_paths, excluded_change_count, include_prefixes, exclude_prefixes);
        }
    } else {
        const canonical = try resolveAliasOwned(allocator, aliases, path);
        if (!std.mem.eql(u8, canonical, path)) {
            allocator.free(path);
            path = canonical;
        } else {
            allocator.free(canonical);
        }
    }
    if (isExcludedPath(path, exclude_prefixes)) {
        excluded_change_count.* += 1;
        if (excluded_paths.get(path) == null) {
            const owned = try allocator.dupe(u8, path);
            errdefer allocator.free(owned);
            try excluded_paths.put(owned, {});
        }
        return;
    }
    if (!isIncludedPath(path, include_prefixes)) {
        outside_include_change_count.* += 1;
        if (outside_include_paths.get(path) == null) {
            const owned = try allocator.dupe(u8, path);
            errdefer allocator.free(owned);
            try outside_include_paths.put(owned, {});
        }
        return;
    }
    const gop = try map.getOrPut(path);
    if (!gop.found_existing) {
        gop.key_ptr.* = try allocator.dupe(u8, path);
        gop.value_ptr.* = newAgg(allocator, path) catch |err| {
            allocator.free(gop.key_ptr.*);
            return err;
        };
    }
    var agg = gop.value_ptr;
    if (row_lineage_partial) agg.lineage_partial = true;
    agg.change_count += 1;
    if (ts >= agg.last_ts) {
        agg.last_ts = ts;
        allocator.free(agg.last_commit);
        agg.last_commit = try allocator.dupe(u8, commit[0..@min(commit.len, 12)]);
    }
    var add: ?u64 = null;
    var del: ?u64 = null;
    if (!std.mem.eql(u8, add_s, "-") and !std.mem.eql(u8, del_s, "-")) {
        add = try std.fmt.parseInt(u64, add_s, 10);
        del = try std.fmt.parseInt(u64, del_s, 10);
        agg.additions += add.?;
        agg.deletions += del.?;
    } else {
        agg.binary_count += 1;
    }
    if (agg.evidence.items.len < 3) {
        const evidence_commit = try allocator.dupe(u8, commit[0..@min(commit.len, 12)]);
        errdefer allocator.free(evidence_commit);
        try agg.evidence.append(.{ .commit = evidence_commit, .timestamp = ts, .additions = add, .deletions = del });
    }
    try commit_paths.append(agg.path);
}

fn isIncludedPath(path: []const u8, include_prefixes: []const []const u8) bool {
    if (include_prefixes.len == 0) return true;
    for (include_prefixes) |prefix| {
        if (std.mem.startsWith(u8, path, prefix)) return true;
    }
    return false;
}

fn isExcludedPath(path: []const u8, exclude_prefixes: []const []const u8) bool {
    for (exclude_prefixes) |prefix| {
        if (std.mem.startsWith(u8, path, prefix)) return true;
    }
    return false;
}

fn normalizePath(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
    const unquoted = try unquoteGitPath(allocator, raw);
    errdefer allocator.free(unquoted);

    if (std.mem.indexOf(u8, unquoted, " => ") == null) return unquoted;

    if (std.mem.indexOfScalar(u8, unquoted, '{')) |open| {
        if (std.mem.lastIndexOfScalar(u8, unquoted, '}')) |close| {
            if (open < close) {
                const inner = unquoted[open + 1 .. close];
                if (std.mem.indexOf(u8, inner, " => ")) |_| {
                    var split = std.mem.splitSequence(u8, inner, " => ");
                    _ = split.next();
                    const renamed = split.next() orelse inner;
                    const normalized = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ unquoted[0..open], renamed, unquoted[close + 1 ..] });
                    allocator.free(unquoted);
                    return normalized;
                }
            }
        }
    }

    var split = std.mem.splitSequence(u8, unquoted, " => ");
    _ = split.next();
    const renamed = split.next() orelse return unquoted;
    const normalized = try allocator.dupe(u8, renamed);
    allocator.free(unquoted);
    return normalized;
}

const RenamePath = struct { old_path: []u8, new_path: []u8 };

fn parseRenamePath(allocator: std.mem.Allocator, raw: []const u8) !?RenamePath {
    const unquoted = try unquoteGitPath(allocator, raw);
    defer allocator.free(unquoted);

    if (std.mem.indexOf(u8, unquoted, " => ") == null) return null;

    if (std.mem.indexOfScalar(u8, unquoted, '{')) |open| {
        if (std.mem.lastIndexOfScalar(u8, unquoted, '}')) |close| {
            if (open < close) {
                const inner = unquoted[open + 1 .. close];
                if (std.mem.indexOf(u8, inner, " => ")) |_| {
                    var split = std.mem.splitSequence(u8, inner, " => ");
                    const old_part = split.next() orelse return null;
                    const new_part = split.next() orelse return null;
                    return .{
                        .old_path = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ unquoted[0..open], old_part, unquoted[close + 1 ..] }),
                        .new_path = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ unquoted[0..open], new_part, unquoted[close + 1 ..] }),
                    };
                }
            }
        }
    }

    var split = std.mem.splitSequence(u8, unquoted, " => ");
    const old_path = split.next() orelse return null;
    const new_path = split.next() orelse return null;
    return .{ .old_path = try allocator.dupe(u8, old_path), .new_path = try allocator.dupe(u8, new_path) };
}

fn unquoteGitPath(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
    if (raw.len < 2 or raw[0] != '"' or raw[raw.len - 1] != '"') return allocator.dupe(u8, raw);

    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();

    var i: usize = 1;
    while (i + 1 < raw.len) {
        const c = raw[i];
        i += 1;
        if (c != '\\') {
            try out.append(c);
            continue;
        }
        if (i + 1 >= raw.len) {
            try out.append('\\');
            continue;
        }
        const escaped = raw[i];
        i += 1;
        switch (escaped) {
            't' => try out.append('\t'),
            'n' => try out.append('\n'),
            'r' => try out.append('\r'),
            'b' => try out.append(0x08),
            'f' => try out.append(0x0c),
            '\\' => try out.append('\\'),
            '"' => try out.append('"'),
            '0'...'7' => {
                var value: u8 = escaped - '0';
                var digits: usize = 1;
                while (digits < 3 and i + 1 < raw.len and raw[i] >= '0' and raw[i] <= '7') : (digits += 1) {
                    value = value * 8 + (raw[i] - '0');
                    i += 1;
                }
                try out.append(value);
            },
            else => try out.append(escaped),
        }
    }
    return out.toOwnedSlice();
}

fn finishCommit(allocator: std.mem.Allocator, map: *std.StringHashMap(FileAgg), paths: []const []const u8) !void {
    if (paths.len == 0) return;
    for (paths) |p| {
        if (map.getPtr(p)) |agg| {
            if (paths.len > 50) agg.large_commit = true;
            for (paths) |other| {
                if (std.mem.eql(u8, p, other)) continue;
                const gop = try agg.cochanges.getOrPut(other);
                if (!gop.found_existing) {
                    gop.key_ptr.* = try allocator.dupe(u8, other);
                    gop.value_ptr.* = 1;
                } else gop.value_ptr.* += 1;
            }
        }
    }
}

fn appendResult(allocator: std.mem.Allocator, io: std.Io, out: *std.array_list.Managed(model.Result), repo_root: []const u8, agg: FileAgg, head_ts: i64) !void {
    var row_caveats = std.array_list.Managed([]const u8).init(allocator);
    errdefer {
        for (row_caveats.items) |c| allocator.free(c);
        row_caveats.deinit();
    }
    if (agg.binary_count > 0) try addCaveat(allocator, &row_caveats, "binary or non-text churn unavailable for some changes");
    if (agg.large_commit) try addCaveat(allocator, &row_caveats, "changed in a large commit; evidence may include generated or vendor-like churn");

    const full = try std.fs.path.join(allocator, &.{ repo_root, agg.path });
    defer allocator.free(full);
    var size: ?u64 = null;
    if (std.Io.Dir.openFileAbsolute(io, full, .{})) |f| {
        var file = f;
        defer file.close(io);
        size = (try file.stat(io)).size;
    } else |_| {
        try addCaveat(allocator, &row_caveats, "path is deleted or not present at HEAD");
    }

    var cc_list = std.array_list.Managed(model.CoChange).init(allocator);
    errdefer {
        for (cc_list.items) |cc| allocator.free(cc.path);
        cc_list.deinit();
    }
    var cc_it = agg.cochanges.iterator();
    while (cc_it.next()) |e| try cc_list.append(.{ .path = try allocator.dupe(u8, e.key_ptr.*), .count = e.value_ptr.* });
    std.mem.sort(model.CoChange, cc_list.items, {}, cochangeLessThan);
    if (cc_list.items.len > 5) {
        for (cc_list.items[5..]) |cc| allocator.free(cc.path);
        cc_list.shrinkRetainingCapacity(5);
    }
    var cc_total: u32 = 0;
    for (cc_list.items) |cc| cc_total += cc.count;

    var evs = std.array_list.Managed(model.Evidence).init(allocator);
    errdefer {
        for (evs.items) |ev| allocator.free(ev.commit);
        evs.deinit();
    }
    for (agg.evidence.items) |ev| try evs.append(.{ .commit = try allocator.dupe(u8, ev.commit), .timestamp = ev.timestamp, .additions = ev.additions, .deletions = ev.deletions });

    const lineage_aliases = try dupeStringList(allocator, agg.lineage_aliases.items);
    errdefer freeStringList(allocator, lineage_aliases);

    const churn = agg.additions + agg.deletions;
    const breakdown = scoring.score(agg.change_count, churn, agg.last_ts, head_ts, cc_total);
    try out.append(.{
        .path = try allocator.dupe(u8, agg.path),
        .lineage_aliases = lineage_aliases,
        .lineage_partial = agg.lineage_partial,
        .score = breakdown,
        .change_count = agg.change_count,
        .additions = agg.additions,
        .deletions = agg.deletions,
        .churn = churn,
        .last_changed_timestamp = agg.last_ts,
        .last_changed_commit = try allocator.dupe(u8, agg.last_commit),
        .current_size = size,
        .cochanges = try cc_list.toOwnedSlice(),
        .confidence = scoring.confidence(agg.change_count, row_caveats.items.len),
        .caveats = try row_caveats.toOwnedSlice(),
        .evidence = try evs.toOwnedSlice(),
    });
}

fn cochangeLessThan(_: void, a: model.CoChange, b: model.CoChange) bool {
    if (a.count != b.count) return a.count > b.count;
    return std.mem.lessThan(u8, a.path, b.path);
}

test "normalizes simple rename syntax" {
    const normalized = try normalizePath(std.testing.allocator, "old.zig => new.zig");
    defer std.testing.allocator.free(normalized);
    try std.testing.expectEqualStrings("new.zig", normalized);
}

test "matches literal exclude prefixes" {
    try std.testing.expect(isExcludedPath(".flow/state.yaml", &.{".flow/"}));
    try std.testing.expect(!isExcludedPath(".flowish/state.yaml", &.{".flow/"}));
    try std.testing.expect(!isExcludedPath("src/.flow_adapter.zig", &.{".flow/"}));
    try std.testing.expect(isExcludedPath("vendor/lib.zig", &.{"vendor/"}));
    try std.testing.expect(!isExcludedPath("src/vendor_adapter.zig", &.{"vendor/"}));
    try std.testing.expect(!isExcludedPath("glob/[literal]*.zig", &.{"glob/*"}));
}

test "matches literal include prefixes" {
    try std.testing.expect(isIncludedPath("src/app.zig", &.{}));
    try std.testing.expect(isIncludedPath("src/app.zig", &.{"src/"}));
    try std.testing.expect(isIncludedPath("vendor/lib.zig", &.{ "src/", "vendor/" }));
    try std.testing.expect(!isIncludedPath("docs/readme.md", &.{ "src/", "vendor/" }));
    try std.testing.expect(!isIncludedPath("glob/[literal]*.zig", &.{"glob/*"}));
}

test "normalizes braced rename before prefix matching" {
    const normalized = try normalizePath(std.testing.allocator, "src/{old.zig => new.zig}");
    defer std.testing.allocator.free(normalized);
    try std.testing.expectEqualStrings("src/new.zig", normalized);
    try std.testing.expect(isExcludedPath(normalized, &.{"src/"}));
}

test "parses simple and braced rename aliases" {
    const simple = (try parseRenamePath(std.testing.allocator, "old.zig => new.zig")).?;
    defer std.testing.allocator.free(simple.old_path);
    defer std.testing.allocator.free(simple.new_path);
    try std.testing.expectEqualStrings("old.zig", simple.old_path);
    try std.testing.expectEqualStrings("new.zig", simple.new_path);

    const braced = (try parseRenamePath(std.testing.allocator, "src/{old.zig => new.zig}")).?;
    defer std.testing.allocator.free(braced.old_path);
    defer std.testing.allocator.free(braced.new_path);
    try std.testing.expectEqualStrings("src/old.zig", braced.old_path);
    try std.testing.expectEqualStrings("src/new.zig", braced.new_path);
}

test "lineage aliases canonicalize older history" {
    const allocator = std.testing.allocator;
    var map = std.StringHashMap(FileAgg).init(allocator);
    defer {
        var it = map.iterator();
        while (it.next()) |entry| deinitAgg(entry.key_ptr.*, entry.value_ptr.*, allocator);
        map.deinit();
    }
    var commit_paths = std.array_list.Managed([]const u8).init(allocator);
    defer commit_paths.deinit();
    var outside_include_paths = std.StringHashMap(void).init(allocator);
    defer outside_include_paths.deinit();
    var excluded_paths = std.StringHashMap(void).init(allocator);
    defer excluded_paths.deinit();
    var aliases = std.StringHashMap([]u8).init(allocator);
    defer {
        var it = aliases.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        aliases.deinit();
    }
    var outside_include_change_count: usize = 0;
    var excluded_change_count: usize = 0;
    var rename_detected = false;
    var partial_lineage = false;

    try applyNumstat(allocator, &map, &commit_paths, &outside_include_paths, &outside_include_change_count, &excluded_paths, &excluded_change_count, &.{}, &.{}, &aliases, &rename_detected, &partial_lineage, "aaaaaaaaaaaa", 2, "1", "1", "old.zig => new.zig");
    try applyNumstat(allocator, &map, &commit_paths, &outside_include_paths, &outside_include_change_count, &excluded_paths, &excluded_change_count, &.{}, &.{}, &aliases, &rename_detected, &partial_lineage, "bbbbbbbbbbbb", 1, "2", "0", "old.zig");

    try std.testing.expect(rename_detected);
    try std.testing.expect(!partial_lineage);
    try std.testing.expect(map.get("old.zig") == null);
    const agg = map.get("new.zig").?;
    try std.testing.expectEqual(@as(u32, 2), agg.change_count);
    try std.testing.expectEqual(@as(u64, 3), agg.additions);
    try std.testing.expectEqual(@as(usize, 1), agg.lineage_aliases.items.len);
    try std.testing.expectEqualStrings("old.zig", agg.lineage_aliases.items[0]);
}

test "unquotes git quoted tab path before prefix matching" {
    const normalized = try normalizePath(std.testing.allocator, "\"weird/tab\\tname.txt\"");
    defer std.testing.allocator.free(normalized);
    try std.testing.expectEqualStrings("weird/tab\tname.txt", normalized);
    try std.testing.expect(isExcludedPath(normalized, &.{"weird/"}));
}

test "streaming log parser handles chunk boundaries and numstat edge cases" {
    const allocator = std.testing.allocator;
    var map = std.StringHashMap(FileAgg).init(allocator);
    defer {
        var it = map.iterator();
        while (it.next()) |entry| deinitAgg(entry.key_ptr.*, entry.value_ptr.*, allocator);
        map.deinit();
    }
    var commit_paths = std.array_list.Managed([]const u8).init(allocator);
    defer commit_paths.deinit();
    var outside_include_paths = std.StringHashMap(void).init(allocator);
    defer outside_include_paths.deinit();
    var excluded_paths = std.StringHashMap(void).init(allocator);
    defer excluded_paths.deinit();
    var aliases = std.StringHashMap([]u8).init(allocator);
    defer {
        var it = aliases.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        aliases.deinit();
    }
    var outside_include_change_count: usize = 0;
    var excluded_change_count: usize = 0;

    var parser = LogParser.init(allocator, &map, &commit_paths, &outside_include_paths, &outside_include_change_count, &excluded_paths, &excluded_change_count, &.{}, &.{}, &aliases);
    defer parser.deinit();

    try parser.feed("aaaaaaaaaaaaaaaaaaaa");
    try parser.feed("aaaaaaaaaaaaaaaaaaaa\t100\r\n");
    try parser.feed("1\t2\tsrc/{old.zig => new.zig}\r\n\r\nmalformed\r\n");
    try parser.feed("-\t-\tbin/blob.dat\n3\t4\t\"weird/tab\\tname.txt\"\n");
    try parser.feed("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\t200\n5\t6\tunicod");
    try parser.feed("e/雪.zig");
    try parser.finish();

    try std.testing.expectEqual(@as(usize, 2), parser.commit_count);
    try std.testing.expectEqual(@as(u32, 1), map.get("src/new.zig").?.change_count);
    try std.testing.expectEqual(@as(u32, 1), map.get("bin/blob.dat").?.binary_count);
    try std.testing.expectEqual(@as(u64, 3), map.get("weird/tab\tname.txt").?.additions);
    try std.testing.expectEqual(@as(u64, 6), map.get("unicode/雪.zig").?.deletions);
    try std.testing.expect(map.get("malformed") == null);
}
