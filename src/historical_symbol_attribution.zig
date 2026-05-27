const std = @import("std");
const git_hunks = @import("git_hunks.zig");
const git_runner = @import("git_runner.zig");
const provider = @import("provider.zig");
const provider_selection = @import("provider_selection.zig");

pub const Options = struct {
    bounds: git_hunks.Bounds = .{},
    max_sample_commits: usize = 3,
    max_provider_failures: usize = 32,
};

const AggregationContext = struct {
    provider_failures: usize = 0,
};

pub const AggregateRecord = struct {
    parent_path: []u8,
    symbol_kind: ?provider.SymbolKind,
    symbol_name: ?[]u8,
    revision_range: ?provider.LineRange,
    status: provider.RevisionSymbolStatus,
    change_count: u32,
    added_line_pressure: u64,
    deleted_line_pressure: u64,
    latest_timestamp: ?i64,
    sample_commit_ids: [][]u8,
    provider_state: provider.Failure,
    confidence: provider.Confidence,
    caveats: [][]const u8,
    fallback_count: u32,
    sort_key: []u8,

    pub fn deinit(self: AggregateRecord, allocator: std.mem.Allocator) void {
        allocator.free(self.parent_path);
        if (self.symbol_name) |name| allocator.free(name);
        for (self.sample_commit_ids) |commit| allocator.free(commit);
        allocator.free(self.sample_commit_ids);
        allocator.free(self.caveats);
        allocator.free(self.sort_key);
    }
};

const AggregateBuilder = struct {
    parent_path: []u8,
    symbol_kind: ?provider.SymbolKind,
    symbol_name: ?[]u8,
    revision_range: ?provider.LineRange,
    status: provider.RevisionSymbolStatus,
    change_count: u32 = 0,
    added_line_pressure: u64 = 0,
    deleted_line_pressure: u64 = 0,
    latest_timestamp: ?i64 = null,
    sample_commit_ids: std.ArrayList([]u8) = .empty,
    provider_state: provider.Failure = .ok,
    confidence: provider.Confidence = .high,
    caveats: std.ArrayList([]const u8) = .empty,
    fallback_count: u32 = 0,

    fn deinit(self: *AggregateBuilder, allocator: std.mem.Allocator) void {
        allocator.free(self.parent_path);
        if (self.symbol_name) |name| allocator.free(name);
        for (self.sample_commit_ids.items) |commit| allocator.free(commit);
        self.sample_commit_ids.deinit(allocator);
        self.caveats.deinit(allocator);
    }

    fn toRecord(self: *AggregateBuilder, allocator: std.mem.Allocator, sort_key: []const u8) !AggregateRecord {
        return .{
            .parent_path = try allocator.dupe(u8, self.parent_path),
            .symbol_kind = self.symbol_kind,
            .symbol_name = if (self.symbol_name) |name| try allocator.dupe(u8, name) else null,
            .revision_range = self.revision_range,
            .status = self.status,
            .change_count = self.change_count,
            .added_line_pressure = self.added_line_pressure,
            .deleted_line_pressure = self.deleted_line_pressure,
            .latest_timestamp = self.latest_timestamp,
            .sample_commit_ids = try dupeStringSlice(allocator, self.sample_commit_ids.items),
            .provider_state = self.provider_state,
            .confidence = self.confidence,
            .caveats = try self.caveats.toOwnedSlice(allocator),
            .fallback_count = self.fallback_count,
            .sort_key = try allocator.dupe(u8, sort_key),
        };
    }
};

pub fn deinitAggregateRecords(allocator: std.mem.Allocator, records: []AggregateRecord) void {
    for (records) |record| record.deinit(allocator);
    allocator.free(records);
}

pub fn analyze(
    allocator: std.mem.Allocator,
    io: std.Io,
    repo: []const u8,
    candidate_paths: []const []const u8,
    options: Options,
) ![]AggregateRecord {
    const hunk_records = try git_hunks.readHistory(allocator, io, repo, candidate_paths, options.bounds);
    defer git_hunks.deinitRecords(allocator, hunk_records);
    return aggregateRecords(allocator, hunk_records, options);
}

pub fn aggregateRecords(allocator: std.mem.Allocator, hunk_records: []const git_hunks.FileHunkRecord, options: Options) ![]AggregateRecord {
    var map = std.StringHashMap(AggregateBuilder).init(allocator);
    defer {
        var it = map.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(allocator);
        }
        map.deinit();
    }

    var context: AggregationContext = .{};
    for (hunk_records) |record| try aggregateOne(allocator, &map, &context, record, options);

    var out: std.ArrayList(AggregateRecord) = .empty;
    errdefer {
        for (out.items) |record| record.deinit(allocator);
        out.deinit(allocator);
    }
    var it = map.iterator();
    while (it.next()) |entry| try out.append(allocator, try entry.value_ptr.toRecord(allocator, entry.key_ptr.*));
    std.mem.sort(AggregateRecord, out.items, {}, lessAggregateRecord);
    return out.toOwnedSlice(allocator);
}

fn aggregateOne(allocator: std.mem.Allocator, map: *std.StringHashMap(AggregateBuilder), context: *AggregationContext, record: git_hunks.FileHunkRecord, options: Options) !void {
    var used_any = false;
    if (record.old_source) |source| {
        used_any = true;
        try aggregateSide(allocator, map, context, record, .old, source, options);
    } else if (record.old_blob_state != .absent and hasOldPressure(record)) {
        try addFallback(allocator, map, record, true, provider.Failure.skipped, .low, "old side unavailable; file-level fallback retained", options);
    }

    if (record.new_source) |source| {
        used_any = true;
        try aggregateSide(allocator, map, context, record, .new, source, options);
    } else if (record.new_blob_state != .absent and hasNewPressure(record)) {
        try addFallback(allocator, map, record, false, provider.Failure.skipped, .low, "new side unavailable; file-level fallback retained", options);
    }

    if (!used_any and record.hunks.len == 0) {
        try addFallback(allocator, map, record, false, provider.Failure.skipped, .low, "no text hunks available; file-level fallback retained", options);
    }
}

const Side = enum { old, new };

fn aggregateSide(
    allocator: std.mem.Allocator,
    map: *std.StringHashMap(AggregateBuilder),
    context: *AggregationContext,
    record: git_hunks.FileHunkRecord,
    side: Side,
    source: []const u8,
    options: Options,
) !void {
    const path = switch (side) {
        .old => record.old_path orelse record.new_path orelse return,
        .new => record.new_path orelse record.old_path orelse return,
    };
    const blob = switch (side) {
        .old => record.old_blob orelse return,
        .new => record.new_blob orelse return,
    };
    if (context.provider_failures >= options.max_provider_failures) {
        try addFallback(allocator, map, record, side == .old, provider.Failure.skipped, .low, "provider failure bound exceeded; provider parsing skipped", options);
        return;
    }
    var extraction = try provider_selection.extractHistoricalSource(allocator, path, record.commit_id, blob, source);
    defer extraction.deinit(allocator);

    if (extraction.provider.failure != .ok) {
        context.provider_failures += 1;
        try addFallback(allocator, map, record, side == .old, extraction.provider.failure, extraction.provider.confidence, "provider could not parse revision-local source; fallback retained", options);
        return;
    }

    for (record.hunks) |hunk| {
        const interval = if (side == .old) hunk.old else hunk.new;
        if (interval == null) continue;
        var matched = false;
        for (extraction.symbols) |symbol| {
            const range = switch (symbol.current_range) {
                .lines => |lines| lines,
                .bytes => continue,
            };
            if (!intersects(interval.?, range)) continue;
            matched = true;
            const pressure = @as(u64, interval.?.lineCount());
            const status: provider.RevisionSymbolStatus = switch (side) {
                .old => if (record.status == .deleted or hunk.new == null) .deleted else .historical,
                .new => .historical,
            };
            const builder = try ensureAggregate(allocator, map, path, symbol.kind, symbol.name, range, status);
            try addEvidence(allocator, builder, record, if (side == .new) pressure else 0, if (side == .old) pressure else 0, extraction.provider.failure, symbol.confidence, options.max_sample_commits);
            try addCaveats(allocator, builder, symbol.caveats);
        }
        if (!matched) {
            try addFallback(allocator, map, record, side == .old, provider.Failure.skipped, .low, "unattributed hunk fallback; no nearest-symbol guessing", options);
        }
    }
}

fn addFallback(
    allocator: std.mem.Allocator,
    map: *std.StringHashMap(AggregateBuilder),
    record: git_hunks.FileHunkRecord,
    old_side: bool,
    failure: provider.Failure,
    confidence: provider.Confidence,
    caveat: []const u8,
    options: Options,
) !void {
    const path = if (old_side) record.old_path orelse record.new_path orelse return else record.new_path orelse record.old_path orelse return;
    const status: provider.RevisionSymbolStatus = if (record.status == .deleted and old_side) .deleted else .unknown;
    var builder = try ensureAggregate(allocator, map, path, null, null, null, status);
    builder.fallback_count += 1;
    var added: u64 = 0;
    var deleted: u64 = 0;
    for (record.hunks) |hunk| {
        if (old_side) {
            if (hunk.old) |interval| deleted += interval.lineCount();
        } else {
            if (hunk.new) |interval| added += interval.lineCount();
        }
    }
    try addEvidence(allocator, builder, record, added, deleted, failure, confidence, options.max_sample_commits);
    try appendUniqueCaveat(allocator, &builder.caveats, caveat);
    try addCaveats(allocator, builder, record.caveats);
}

fn ensureAggregate(
    allocator: std.mem.Allocator,
    map: *std.StringHashMap(AggregateBuilder),
    path: []const u8,
    kind: ?provider.SymbolKind,
    name: ?[]const u8,
    range: ?provider.LineRange,
    status: provider.RevisionSymbolStatus,
) !*AggregateBuilder {
    const key = try aggregateKey(allocator, path, kind, name, range, status);
    errdefer allocator.free(key);
    const found = try map.getOrPut(key);
    if (found.found_existing) {
        allocator.free(key);
        return found.value_ptr;
    }
    found.key_ptr.* = key;
    found.value_ptr.* = .{
        .parent_path = try allocator.dupe(u8, path),
        .symbol_kind = kind,
        .symbol_name = if (name) |symbol_name| try allocator.dupe(u8, symbol_name) else null,
        .revision_range = range,
        .status = status,
        .confidence = if (name == null) .low else .high,
    };
    return found.value_ptr;
}

fn addEvidence(
    allocator: std.mem.Allocator,
    builder: *AggregateBuilder,
    record: git_hunks.FileHunkRecord,
    added: u64,
    deleted: u64,
    failure: provider.Failure,
    confidence: provider.Confidence,
    max_sample_commits: usize,
) !void {
    builder.change_count += 1;
    builder.added_line_pressure += added;
    builder.deleted_line_pressure += deleted;
    if (record.timestamp) |ts| {
        if (builder.latest_timestamp == null or ts > builder.latest_timestamp.?) builder.latest_timestamp = ts;
    }
    if (builder.provider_state == .ok and failure != .ok) builder.provider_state = failure;
    builder.confidence = weakerConfidence(builder.confidence, confidence);
    try appendSampleCommit(allocator, builder, record.commit_id, max_sample_commits);
}

fn appendSampleCommit(allocator: std.mem.Allocator, builder: *AggregateBuilder, commit_id: []const u8, max_sample_commits: usize) !void {
    for (builder.sample_commit_ids.items) |existing| {
        if (std.mem.eql(u8, existing, commit_id)) return;
    }
    if (builder.sample_commit_ids.items.len >= max_sample_commits) {
        try appendUniqueCaveat(allocator, &builder.caveats, "sample commit bound reached; additional commit ids omitted");
        return;
    }
    try builder.sample_commit_ids.append(allocator, try allocator.dupe(u8, commit_id));
}

fn addCaveats(allocator: std.mem.Allocator, builder: *AggregateBuilder, caveats: []const []const u8) !void {
    for (caveats) |caveat| try appendUniqueCaveat(allocator, &builder.caveats, caveat);
}

fn appendUniqueCaveat(allocator: std.mem.Allocator, caveats: *std.ArrayList([]const u8), caveat: []const u8) !void {
    for (caveats.items) |existing| if (std.mem.eql(u8, existing, caveat)) return;
    try caveats.append(allocator, caveat);
}

fn aggregateKey(
    allocator: std.mem.Allocator,
    path: []const u8,
    kind: ?provider.SymbolKind,
    name: ?[]const u8,
    range: ?provider.LineRange,
    status: provider.RevisionSymbolStatus,
) ![]u8 {
    const range_start = if (range) |value| value.start else 0;
    const range_end = if (range) |value| value.end else 0;
    return std.fmt.allocPrint(allocator, "{s}\x1f{s}\x1f{s}\x1f{s}\x1f{d}\x1f{d}", .{
        path,
        if (kind) |value| @tagName(value) else "file",
        name orelse "",
        @tagName(status),
        range_start,
        range_end,
    });
}

fn dupeStringSlice(allocator: std.mem.Allocator, input: []const []u8) ![][]u8 {
    const out = try allocator.alloc([]u8, input.len);
    for (out) |*item| item.* = &.{};
    errdefer {
        for (out) |item| if (item.len > 0) allocator.free(item);
        allocator.free(out);
    }
    for (input, 0..) |item, index| out[index] = try allocator.dupe(u8, item);
    return out;
}

fn weakerConfidence(lhs: provider.Confidence, rhs: provider.Confidence) provider.Confidence {
    return if (confidenceRank(rhs) > confidenceRank(lhs)) rhs else lhs;
}

fn confidenceRank(confidence: provider.Confidence) u8 {
    return switch (confidence) {
        .high => 0,
        .medium => 1,
        .low => 2,
        .unknown => 3,
    };
}

fn intersects(lhs: git_hunks.LineInterval, rhs: provider.LineRange) bool {
    return lhs.start <= rhs.end and rhs.start <= lhs.end;
}

fn hasOldPressure(record: git_hunks.FileHunkRecord) bool {
    for (record.hunks) |hunk| if (hunk.old != null) return true;
    return false;
}

fn hasNewPressure(record: git_hunks.FileHunkRecord) bool {
    for (record.hunks) |hunk| if (hunk.new != null) return true;
    return false;
}

fn lessAggregateRecord(_: void, lhs: AggregateRecord, rhs: AggregateRecord) bool {
    return std.mem.order(u8, lhs.sort_key, rhs.sort_key) == .lt;
}

fn findRecord(records: []const AggregateRecord, path: []const u8, name: ?[]const u8, status: ?provider.RevisionSymbolStatus) ?AggregateRecord {
    for (records) |record| {
        if (!std.mem.eql(u8, record.parent_path, path)) continue;
        if (name) |needle| {
            if (record.symbol_name == null or !std.mem.eql(u8, record.symbol_name.?, needle)) continue;
        }
        if (status) |wanted| if (record.status != wanted) continue;
        return record;
    }
    return null;
}

fn containsCaveat(record: AggregateRecord, needle: []const u8) bool {
    for (record.caveats) |caveat| if (std.mem.indexOf(u8, caveat, needle) != null) return true;
    return false;
}

fn recordContainsCaveat(record: git_hunks.FileHunkRecord, needle: []const u8) bool {
    for (record.caveats) |caveat| if (std.mem.indexOf(u8, caveat, needle) != null) return true;
    return false;
}

fn recordsContainCaveat(records: []const git_hunks.FileHunkRecord, needle: []const u8) bool {
    for (records) |record| if (recordContainsCaveat(record, needle)) return true;
    return false;
}

test "generated local repository proves historical hunk attribution cases" {
    const allocator = std.testing.allocator;
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const repo = try makeHistoricalFixtureRepo(allocator, io);
    defer {
        std.Io.Dir.cwd().deleteTree(io, repo) catch {};
        allocator.free(repo);
    }

    const paths = [_][]const u8{ "src/app.zig", "src/renamed.zig", "notes.txt", "bin/blob.bin", "src/large.zig", "src/comments.zig", "src/merge_side.zig" };
    const options: Options = .{ .bounds = .{ .max_blob_bytes = 180 }, .max_sample_commits = 2 };
    const records = try git_hunks.readHistory(allocator, io, repo, &paths, options.bounds);
    defer git_hunks.deinitRecords(allocator, records);

    try std.testing.expect(records.len >= 6);
    var saw_rename = false;
    var saw_single_commit_rename_edit = false;
    var saw_binary = false;
    var saw_large = false;
    var saw_merge_policy = false;
    for (records) |record| {
        if (record.status == .renamed and std.mem.eql(u8, record.displayPath(), "src/renamed.zig")) {
            saw_rename = true;
            if (record.hunks.len > 0 and record.old_blob != null and record.new_blob != null) saw_single_commit_rename_edit = true;
        }
        if (record.new_blob_state == .binary or record.old_blob_state == .binary) saw_binary = true;
        if (record.new_blob_state == .too_large or record.old_blob_state == .too_large) saw_large = true;
        if (recordContainsCaveat(record, "merge commit simplified")) saw_merge_policy = true;
    }
    try std.testing.expect(saw_rename);
    try std.testing.expect(saw_single_commit_rename_edit);
    try std.testing.expect(saw_binary);
    try std.testing.expect(saw_large);
    try std.testing.expect(saw_merge_policy);

    const aggregates = try aggregateRecords(allocator, records, options);
    defer deinitAggregateRecords(allocator, aggregates);
    const alpha = findRecord(aggregates, "src/app.zig", "alpha", .historical) orelse return error.MissingAlphaAttribution;
    try std.testing.expect(alpha.added_line_pressure > 0 or alpha.deleted_line_pressure > 0);
    try std.testing.expect(alpha.sample_commit_ids.len <= options.max_sample_commits);

    const beta = findRecord(aggregates, "src/app.zig", "beta", .deleted) orelse return error.MissingDeletedSymbolAttribution;
    try std.testing.expect(beta.deleted_line_pressure > 0);

    const renamed = findRecord(aggregates, "src/renamed.zig", "alpha", .historical) orelse return error.MissingRenameEditAttribution;
    try std.testing.expect(renamed.change_count > 0);

    const unsupported = findRecord(aggregates, "notes.txt", null, .unknown) orelse return error.MissingUnsupportedFallback;
    try std.testing.expect(unsupported.fallback_count > 0);
    try std.testing.expect(containsCaveat(unsupported, "provider could not parse"));

    const binary = findRecord(aggregates, "bin/blob.bin", null, .unknown) orelse return error.MissingBinaryFallback;
    try std.testing.expect(containsCaveat(binary, "binary"));

    const large = findRecord(aggregates, "src/large.zig", null, .unknown) orelse return error.MissingLargeFallback;
    try std.testing.expect(containsCaveat(large, "byte bound"));

    const unattributed = findRecord(aggregates, "src/comments.zig", null, .unknown) orelse return error.MissingUnattributedFallback;
    try std.testing.expect(containsCaveat(unattributed, "unattributed hunk fallback"));

    const provider_budget_options: Options = .{ .bounds = .{ .max_blob_bytes = 180 }, .max_provider_failures = 1 };
    const provider_budget = try aggregateRecords(allocator, records, provider_budget_options);
    defer deinitAggregateRecords(allocator, provider_budget);
    const budget_fallback = findRecord(provider_budget, "notes.txt", null, .unknown) orelse return error.MissingProviderBudgetFallback;
    try std.testing.expect(containsCaveat(budget_fallback, "provider failure bound exceeded"));

    const commit_bound_records = try git_hunks.readHistory(allocator, io, repo, &paths, .{ .max_commits = 1 });
    defer git_hunks.deinitRecords(allocator, commit_bound_records);
    try std.testing.expect(recordsContainCaveat(commit_bound_records, "commit bound exceeded"));

    const changed_file_bound_records = try git_hunks.readHistory(allocator, io, repo, &paths, .{ .max_changed_files = 1 });
    defer git_hunks.deinitRecords(allocator, changed_file_bound_records);
    try std.testing.expect(recordsContainCaveat(changed_file_bound_records, "changed-file bound"));

    const second = try aggregateRecords(allocator, records, options);
    defer deinitAggregateRecords(allocator, second);
    try std.testing.expectEqual(aggregates.len, second.len);
    for (aggregates, second) |lhs, rhs| try std.testing.expectEqualStrings(lhs.sort_key, rhs.sort_key);
}

fn makeHistoricalFixtureRepo(allocator: std.mem.Allocator, io: std.Io) ![]u8 {
    const repo = try allocator.dupe(u8, ".zig-cache/historical-attribution-fixture");
    errdefer allocator.free(repo);
    std.Io.Dir.cwd().deleteTree(io, repo) catch {};
    try std.Io.Dir.cwd().createDirPath(io, repo);
    errdefer std.Io.Dir.cwd().deleteTree(io, repo) catch {};

    try run(allocator, io, &.{ "git", "init", "-q", "-b", "main", repo });
    try runGit(allocator, io, repo, &.{ "config", "user.name", "Fixture Author" });
    try runGit(allocator, io, repo, &.{ "config", "user.email", "fixture@example.invalid" });
    try runGit(allocator, io, repo, &.{ "config", "commit.gpgsign", "false" });

    try writeFixtureFile(io, repo, "src/app.zig",
        \\// module comment v1
        \\pub fn alpha() void {
        \\    const value = 1;
        \\}
        \\
        \\pub fn beta() void {
        \\    const value = 2;
        \\}
        \\
    );
    try writeFixtureFile(io, repo, "notes.txt", "note one\n");
    try writeFixtureFile(io, repo, "src/comments.zig", "// comment one\n");
    try writeFixtureFile(io, repo, "bin/blob.bin", "\x00\x01\x02\x03");
    try writeFixtureFile(io, repo, "src/large.zig",
        \\pub fn large() void {
        \\    const value = 0;
        \\    const a = 1;
        \\    const b = 2;
        \\    const c = 3;
        \\    const d = 4;
        \\    const e = 5;
        \\    const f = 6;
        \\}
        \\
    );
    try commitAll(allocator, io, repo, "fixture 1", "2026-05-01T00:00:00+0000");

    try writeFixtureFile(io, repo, "src/app.zig",
        \\// module comment v2
        \\pub fn alpha() void {
        \\    const value = 10;
        \\}
        \\
        \\pub fn beta() void {
        \\    const value = 2;
        \\}
        \\
    );
    try writeFixtureFile(io, repo, "src/comments.zig", "// comment two\n");
    try commitAll(allocator, io, repo, "fixture 2", "2026-05-02T00:00:00+0000");

    try writeFixtureFile(io, repo, "src/app.zig",
        \\// module comment v2
        \\pub fn alpha() void {
        \\    const value = 10;
        \\}
        \\
    );
    try commitAll(allocator, io, repo, "fixture 3", "2026-05-03T00:00:00+0000");

    try runGit(allocator, io, repo, &.{ "mv", "src/app.zig", "src/renamed.zig" });
    try writeFixtureFile(io, repo, "src/renamed.zig",
        \\// module comment v2
        \\pub fn alpha() void {
        \\    const value = 11;
        \\}
        \\
    );
    try commitAll(allocator, io, repo, "fixture 4 rename edit", "2026-05-04T00:00:00+0000");

    try writeFixtureFile(io, repo, "notes.txt", "note one\nnote two\n");
    try commitAll(allocator, io, repo, "fixture 5", "2026-05-05T00:00:00+0000");

    try writeFixtureFile(io, repo, "bin/blob.bin", "\x00\x01\x02\x03\x04");
    try commitAll(allocator, io, repo, "fixture 6", "2026-05-06T00:00:00+0000");

    try writeFixtureFile(io, repo, "src/large.zig",
        \\pub fn large() void {
        \\    const value = 100;
        \\    const a = 1;
        \\    const b = 2;
        \\    const c = 3;
        \\    const d = 4;
        \\    const e = 5;
        \\    const f = 6;
        \\    const g = 7;
        \\    const h = 8;
        \\    const i = 9;
        \\    const j = 10;
        \\    const k = 11;
        \\    const l = 12;
        \\}
        \\
    );
    try commitAll(allocator, io, repo, "fixture 7", "2026-05-07T00:00:00+0000");

    try runGit(allocator, io, repo, &.{ "checkout", "-q", "-b", "side" });
    try writeFixtureFile(io, repo, "src/merge_side.zig",
        \\pub fn sideOnly() void {}
        \\
    );
    try commitAll(allocator, io, repo, "fixture 8 side branch", "2026-05-08T00:00:00+0000");
    try runGit(allocator, io, repo, &.{ "checkout", "-q", "main" });
    try runGit(allocator, io, repo, &.{ "merge", "-q", "--no-ff", "--no-commit", "side" });
    try commitAll(allocator, io, repo, "fixture 8 merge side", "2026-05-08T00:30:00+0000");

    try writeFixtureFile(io, repo, "notes.txt", "note one\nnote two\nnote three\n");
    try writeFixtureFile(io, repo, "src/comments.zig", "// comment three\n");
    try commitAll(allocator, io, repo, "fixture 9 multi file policy", "2026-05-09T00:00:00+0000");

    return repo;
}

fn writeFixtureFile(io: std.Io, repo: []const u8, path: []const u8, data: []const u8) !void {
    const full = try std.fs.path.join(std.testing.allocator, &.{ repo, path });
    defer std.testing.allocator.free(full);
    if (std.fs.path.dirname(full)) |dir| try std.Io.Dir.cwd().createDirPath(io, dir);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = full, .data = data });
}

fn commitAll(allocator: std.mem.Allocator, io: std.Io, repo: []const u8, message: []const u8, date: []const u8) !void {
    try runGit(allocator, io, repo, &.{ "add", "-A" });
    try run(allocator, io, &.{ "sh", "-c", "GIT_AUTHOR_DATE=\"$2\" GIT_COMMITTER_DATE=\"$2\" git -C \"$1\" commit -q -m \"$3\"", "fixture-commit", repo, date, message });
}

fn runGit(allocator: std.mem.Allocator, io: std.Io, repo: []const u8, args: []const []const u8) !void {
    const stdout = try git_runner.runGitOk(allocator, io, repo, args);
    allocator.free(stdout);
}

fn run(allocator: std.mem.Allocator, io: std.Io, argv: []const []const u8) !void {
    const result = try std.process.run(allocator, io, .{ .argv = argv, .stdout_limit = .limited(1024 * 1024), .stderr_limit = .limited(1024 * 1024) });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    switch (result.term) {
        .exited => |code| if (code == 0) return,
        else => {},
    }
    return error.CommandFailed;
}
