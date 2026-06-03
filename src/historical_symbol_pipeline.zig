const std = @import("std");
const git_hunks = @import("git_hunks.zig");
const model = @import("model.zig");
const historical_symbol_attribution = @import("historical_symbol_attribution.zig");

pub const Options = struct {
    attribution: historical_symbol_attribution.Options = .{},
    max_aggregate_records: usize = 128,
};

pub fn attach(
    allocator: std.mem.Allocator,
    io: std.Io,
    analysis: *model.Analysis,
    options: Options,
) !void {
    if (analysis.historical_symbol_report) |report| {
        report.deinit(allocator);
        analysis.historical_symbol_report = null;
    }
    analysis.historical_symbol_report = try build(allocator, io, analysis.*, options);
}

pub fn build(
    allocator: std.mem.Allocator,
    io: std.Io,
    analysis: model.Analysis,
    options: Options,
) !model.HistoricalSymbolReport {
    const candidates = try candidatePaths(allocator, analysis.results);
    defer freeStringList(allocator, candidates);

    var caveats: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (caveats.items) |caveat| allocator.free(caveat);
        caveats.deinit(allocator);
    }

    try addAnalysisCaveats(allocator, &caveats, analysis);
    if (candidates.len > options.attribution.bounds.max_candidate_files) {
        try appendOwnedCaveat(allocator, &caveats, "candidate file bound exceeded; trailing retained ranked-file candidates skipped");
    }

    var aggregates = try historical_symbol_attribution.analyze(allocator, io, analysis.repo_root, candidates, options.attribution);
    errdefer historical_symbol_attribution.deinitAggregateRecords(allocator, aggregates);

    const aggregate_bound_exceeded = try applyAggregateRecordBound(allocator, &caveats, &aggregates, options.max_aggregate_records);

    return .{
        .candidate_path_count = candidates.len,
        .retained_candidate_path_count = @min(candidates.len, options.attribution.bounds.max_candidate_files),
        .aggregate_record_bound = options.max_aggregate_records,
        .aggregate_record_bound_exceeded = aggregate_bound_exceeded,
        .aggregates = aggregates,
        .caveats = try caveats.toOwnedSlice(allocator),
    };
}

fn candidatePaths(allocator: std.mem.Allocator, results: []const model.Result) ![][]const u8 {
    var seen = std.StringHashMap(void).init(allocator);
    defer {
        var it = seen.keyIterator();
        while (it.next()) |key| allocator.free(key.*);
        seen.deinit();
    }

    var paths: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (paths.items) |path| allocator.free(path);
        paths.deinit(allocator);
    }

    for (results) |result| {
        try appendCandidate(allocator, &seen, &paths, result.path);
        for (result.lineage_aliases) |alias| try appendCandidate(allocator, &seen, &paths, alias);
    }

    return paths.toOwnedSlice(allocator);
}

fn appendCandidate(
    allocator: std.mem.Allocator,
    seen: *std.StringHashMap(void),
    paths: *std.ArrayList([]const u8),
    path: []const u8,
) !void {
    if (seen.contains(path)) return;
    var owned_seen: ?[]u8 = try allocator.dupe(u8, path);
    errdefer if (owned_seen) |value| allocator.free(value);
    var owned_path: ?[]u8 = try allocator.dupe(u8, path);
    errdefer if (owned_path) |value| allocator.free(value);

    try seen.put(owned_seen.?, {});
    errdefer if (owned_seen) |value| {
        _ = seen.remove(value);
        allocator.free(value);
    };
    try paths.append(allocator, owned_path.?);
    owned_seen = null;
    owned_path = null;
}

fn addAnalysisCaveats(allocator: std.mem.Allocator, caveats: *std.ArrayList([]const u8), analysis: model.Analysis) !void {
    if (analysis.history.is_shallow) try appendOwnedCaveat(allocator, caveats, "historical symbol integration may be incomplete: repository history is shallow; auto_fetch is false");
    if (analysis.history.is_partial) try appendOwnedCaveat(allocator, caveats, "historical symbol integration may be incomplete: repository history may be partial/promisor; auto_fetch is false");
    if (analysis.history.dirty_worktree) try appendOwnedCaveat(allocator, caveats, "dirty worktree detected; historical symbol integration uses committed local history only");
}

fn appendOwnedCaveat(allocator: std.mem.Allocator, caveats: *std.ArrayList([]const u8), caveat: []const u8) !void {
    for (caveats.items) |existing| if (std.mem.eql(u8, existing, caveat)) return;
    try caveats.append(allocator, try allocator.dupe(u8, caveat));
}

fn applyAggregateRecordBound(
    allocator: std.mem.Allocator,
    caveats: *std.ArrayList([]const u8),
    aggregates: *[]historical_symbol_attribution.AggregateRecord,
    limit: usize,
) !bool {
    if (aggregates.*.len <= limit) return false;
    try appendOwnedCaveat(allocator, caveats, "aggregate record bound exceeded; trailing historical symbol aggregates omitted");
    aggregates.* = try truncateAggregates(allocator, aggregates.*, limit);
    return true;
}

fn truncateAggregates(allocator: std.mem.Allocator, aggregates: []historical_symbol_attribution.AggregateRecord, limit: usize) ![]historical_symbol_attribution.AggregateRecord {
    const kept_len = @min(aggregates.len, limit);
    const kept = try allocator.alloc(historical_symbol_attribution.AggregateRecord, kept_len);
    @memcpy(kept, aggregates[0..kept_len]);
    for (aggregates[kept_len..]) |record| record.deinit(allocator);
    allocator.free(aggregates);
    return kept;
}

fn freeStringList(allocator: std.mem.Allocator, values: []const []const u8) void {
    for (values) |value| allocator.free(value);
    allocator.free(values);
}

fn reportContainsCaveat(report: model.HistoricalSymbolReport, needle: []const u8) bool {
    for (report.caveats) |caveat| if (std.mem.indexOf(u8, caveat, needle) != null) return true;
    return false;
}

fn recordContainsCaveat(record: historical_symbol_attribution.AggregateRecord, needle: []const u8) bool {
    for (record.caveats) |caveat| if (std.mem.indexOf(u8, caveat, needle) != null) return true;
    return false;
}

fn caveatsContain(caveats: []const []const u8, needle: []const u8) bool {
    for (caveats) |caveat| if (std.mem.indexOf(u8, caveat, needle) != null) return true;
    return false;
}

fn findRecord(records: []const historical_symbol_attribution.AggregateRecord, path: []const u8, name: ?[]const u8) ?historical_symbol_attribution.AggregateRecord {
    for (records) |record| {
        if (!std.mem.eql(u8, record.parent_path, path)) continue;
        if (name) |wanted| {
            if (record.symbol_name == null or !std.mem.eql(u8, record.symbol_name.?, wanted)) continue;
        }
        return record;
    }
    return null;
}

test "integrated historical symbol pipeline uses retained ranked-file candidates" {
    const allocator = std.testing.allocator;
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const repo = try historical_symbol_attribution.makeHistoricalFixtureRepoForTests(allocator, io, ".zig-cache/historical-pipeline-fixture");
    defer {
        std.Io.Dir.cwd().deleteTree(io, repo) catch {};
        allocator.free(repo);
    }

    const git = @import("git.zig");
    var analysis = try git.analyze(allocator, io, .{ .repo_path = repo, .limit = 10, .scope = .all }, null);
    defer analysis.deinit();

    try attach(allocator, io, &analysis, .{ .attribution = .{ .bounds = .{ .max_blob_bytes = 180 }, .max_sample_commits = 2 } });
    const report = analysis.historical_symbol_report.?;
    try std.testing.expectEqual(report.candidate_path_count, report.retained_candidate_path_count);
    try std.testing.expect(report.aggregates.len > 0);

    const alpha = findRecord(report.aggregates, "src/app.zig", "alpha") orelse return error.MissingAlphaAttribution;
    try std.testing.expect(alpha.added_line_pressure > 0 or alpha.deleted_line_pressure > 0);
    try std.testing.expect(alpha.sample_commit_ids.len <= 2);

    const renamed = findRecord(report.aggregates, "src/renamed.zig", "alpha") orelse return error.MissingRenameEditAttribution;
    try std.testing.expect(renamed.change_count > 0);

    const unsupported = findRecord(report.aggregates, "notes.txt", null) orelse return error.MissingUnsupportedFallback;
    try std.testing.expect(unsupported.fallback_count > 0);
    try std.testing.expect(recordContainsCaveat(unsupported, "provider could not parse"));

    const binary = findRecord(report.aggregates, "bin/blob.bin", null) orelse return error.MissingBinaryFallback;
    try std.testing.expect(recordContainsCaveat(binary, "binary"));

    const large = findRecord(report.aggregates, "src/large.zig", null) orelse return error.MissingLargeFallback;
    try std.testing.expect(recordContainsCaveat(large, "byte bound"));

    const unattributed = findRecord(report.aggregates, "src/comments.zig", null) orelse return error.MissingUnattributedFallback;
    try std.testing.expect(recordContainsCaveat(unattributed, "unattributed hunk fallback"));

    const first_sort_key = report.aggregates[0].sort_key;
    var second = try build(allocator, io, analysis, .{ .attribution = .{ .bounds = .{ .max_blob_bytes = 180 }, .max_sample_commits = 2 } });
    defer second.deinit(allocator);
    try std.testing.expectEqual(report.aggregates.len, second.aggregates.len);
    try std.testing.expectEqualStrings(first_sort_key, second.aggregates[0].sort_key);
}

test "integrated historical symbol pipeline applies internal bounds" {
    const allocator = std.testing.allocator;
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const repo = try historical_symbol_attribution.makeHistoricalFixtureRepoForTests(allocator, io, ".zig-cache/historical-pipeline-bounds-fixture");
    defer {
        std.Io.Dir.cwd().deleteTree(io, repo) catch {};
        allocator.free(repo);
    }

    const git = @import("git.zig");
    var analysis = try git.analyze(allocator, io, .{ .repo_path = repo, .limit = 10, .scope = .all }, null);
    defer analysis.deinit();

    try attach(allocator, io, &analysis, .{
        .attribution = .{
            .bounds = .{ .max_candidate_files = 1, .max_commits = 1, .max_changed_files = 1, .max_hunks_per_file = 1, .max_blob_bytes = 64 },
            .max_sample_commits = 1,
            .max_provider_failures = 1,
        },
        .max_aggregate_records = 1,
    });
    const report = analysis.historical_symbol_report.?;
    try std.testing.expect(report.candidate_path_count > report.retained_candidate_path_count);
    try std.testing.expect(report.aggregate_record_bound_exceeded or report.aggregates.len <= 1);
    try std.testing.expect(reportContainsCaveat(report, "candidate file bound exceeded"));
    try std.testing.expect(report.aggregates.len <= 1);
    for (report.aggregates) |record| try std.testing.expect(record.sample_commit_ids.len <= 1);
}

test "aggregate record bound truncates synthetic production aggregates" {
    const allocator = std.testing.allocator;
    const bound: usize = 3;
    const records = try makeSyntheticHunkRecordsForBoundTest(allocator, bound + 2);
    defer deinitSyntheticHunkRecordsForBoundTest(allocator, records);

    var aggregates = try historical_symbol_attribution.aggregateRecords(allocator, records, .{});
    var caveats: std.ArrayList([]const u8) = .empty;
    defer {
        for (caveats.items) |caveat| allocator.free(caveat);
        caveats.deinit(allocator);
        historical_symbol_attribution.deinitAggregateRecords(allocator, aggregates);
    }

    try std.testing.expect(aggregates.len > bound);
    const exceeded = try applyAggregateRecordBound(allocator, &caveats, &aggregates, bound);
    try std.testing.expect(exceeded);
    try std.testing.expectEqual(bound, aggregates.len);
    try std.testing.expect(caveatsContain(caveats.items, "aggregate record bound exceeded"));
}

test "aggregate record bound keeps exactly bound aggregate count unflagged" {
    const allocator = std.testing.allocator;
    const bound: usize = 3;
    const records = try makeSyntheticHunkRecordsForBoundTest(allocator, bound);
    defer deinitSyntheticHunkRecordsForBoundTest(allocator, records);

    var aggregates = try historical_symbol_attribution.aggregateRecords(allocator, records, .{});
    var caveats: std.ArrayList([]const u8) = .empty;
    defer {
        for (caveats.items) |caveat| allocator.free(caveat);
        caveats.deinit(allocator);
        historical_symbol_attribution.deinitAggregateRecords(allocator, aggregates);
    }

    try std.testing.expectEqual(bound, aggregates.len);
    const exceeded = try applyAggregateRecordBound(allocator, &caveats, &aggregates, bound);
    try std.testing.expect(!exceeded);
    try std.testing.expectEqual(bound, aggregates.len);
}

test "inspect analysis does not reintroduce other ranked file candidates" {
    const allocator = std.testing.allocator;
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const repo = try historical_symbol_attribution.makeHistoricalFixtureRepoForTests(allocator, io, ".zig-cache/historical-pipeline-inspect-fixture");
    defer {
        std.Io.Dir.cwd().deleteTree(io, repo) catch {};
        allocator.free(repo);
    }

    const git = @import("git.zig");
    var analysis = try git.analyze(allocator, io, .{ .repo_path = repo, .inspect_path = "src/renamed.zig", .scope = .all }, null);
    defer analysis.deinit();
    try std.testing.expectEqual(@as(usize, 1), analysis.results.len);

    try attach(allocator, io, &analysis, .{ .attribution = .{ .bounds = .{ .max_blob_bytes = 180 } } });
    const report = analysis.historical_symbol_report.?;
    try std.testing.expect(findRecord(report.aggregates, "notes.txt", null) == null);
    try std.testing.expect(findRecord(report.aggregates, "bin/blob.bin", null) == null);
}

test "this repository smoke exercises internal historical symbol integration" {
    const allocator = std.testing.allocator;
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const git = @import("git.zig");
    const include_prefixes = [_][]const u8{"src/"};
    var analysis = try git.analyze(allocator, io, .{ .repo_path = ".", .limit = 3, .include_prefixes = &include_prefixes }, null);
    defer analysis.deinit();

    try attach(allocator, io, &analysis, .{
        .attribution = .{ .bounds = .{ .max_candidate_files = 2, .max_commits = 4, .max_changed_files = 16, .max_hunks_per_file = 8, .max_blob_bytes = 8192 }, .max_sample_commits = 2 },
        .max_aggregate_records = 8,
    });
    const report = analysis.historical_symbol_report.?;
    try std.testing.expect(report.candidate_path_count > 0);
    try std.testing.expect(report.retained_candidate_path_count <= 2);
    try std.testing.expect(report.aggregates.len <= 8);
    for (report.aggregates) |record| {
        try std.testing.expect(record.parent_path.len > 0);
        try std.testing.expect(record.sample_commit_ids.len <= 2);
    }
}

fn makeSyntheticHunkRecordsForBoundTest(allocator: std.mem.Allocator, count: usize) ![]git_hunks.FileHunkRecord {
    const records = try allocator.alloc(git_hunks.FileHunkRecord, count);
    var initialized: usize = 0;
    errdefer {
        for (records[0..initialized]) |record| record.deinit(allocator);
        allocator.free(records);
    }

    for (records, 0..) |*record, index| {
        const hunks = try allocator.alloc(git_hunks.Hunk, 1);
        errdefer allocator.free(hunks);
        const commit_id = try std.fmt.allocPrint(allocator, "synthetic-{d}", .{index});
        errdefer allocator.free(commit_id);
        const new_path = try std.fmt.allocPrint(allocator, "src/synthetic_{d}.zig", .{index});
        errdefer allocator.free(new_path);
        const new_blob = try std.fmt.allocPrint(allocator, "blob-{d}", .{index});
        errdefer allocator.free(new_blob);
        const new_source = try std.fmt.allocPrint(allocator, "pub fn symbol_{d}() void {{}}\n", .{index});
        errdefer allocator.free(new_source);
        const caveats = try allocator.alloc([]const u8, 0);
        hunks[0] = .{ .old = null, .new = .{ .start = 1, .end = 1 } };
        record.* = .{
            .commit_id = commit_id,
            .parent_id = null,
            .timestamp = @as(i64, @intCast(index)),
            .old_path = null,
            .new_path = new_path,
            .old_blob = null,
            .new_blob = new_blob,
            .status = .added,
            .hunks = hunks,
            .old_blob_state = .absent,
            .new_blob_state = .available,
            .old_source = null,
            .new_source = new_source,
            .caveats = caveats,
        };
        initialized += 1;
    }
    return records;
}

fn deinitSyntheticHunkRecordsForBoundTest(allocator: std.mem.Allocator, records: []git_hunks.FileHunkRecord) void {
    for (records) |record| record.deinit(allocator);
    allocator.free(records);
}
