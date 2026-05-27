const std = @import("std");
const git_runner = @import("git_runner.zig");

pub const Bounds = struct {
    max_candidate_files: usize = 32,
    max_commits: usize = 64,
    max_changed_files: usize = 256,
    max_hunks_per_file: usize = 64,
    max_blob_bytes: u64 = 256 * 1024,
};

pub const ChangeStatus = enum {
    added,
    modified,
    deleted,
    renamed,
    copied,
    type_changed,
    unknown,
};

pub const BlobState = enum {
    available,
    absent,
    missing,
    binary,
    too_large,
};

pub const LineInterval = struct {
    start: u32,
    end: u32,

    pub fn lineCount(self: LineInterval) u32 {
        if (self.end < self.start) return 0;
        return self.end - self.start + 1;
    }
};

pub const Hunk = struct {
    old: ?LineInterval,
    new: ?LineInterval,
};

pub const FileHunkRecord = struct {
    commit_id: []u8,
    parent_id: ?[]u8,
    timestamp: ?i64,
    old_path: ?[]u8,
    new_path: ?[]u8,
    old_blob: ?[]u8,
    new_blob: ?[]u8,
    status: ChangeStatus,
    hunks: []Hunk,
    old_blob_state: BlobState,
    new_blob_state: BlobState,
    old_source: ?[]u8,
    new_source: ?[]u8,
    caveats: [][]const u8,

    pub fn deinit(self: FileHunkRecord, allocator: std.mem.Allocator) void {
        allocator.free(self.commit_id);
        if (self.parent_id) |value| allocator.free(value);
        if (self.old_path) |value| allocator.free(value);
        if (self.new_path) |value| allocator.free(value);
        if (self.old_blob) |value| allocator.free(value);
        if (self.new_blob) |value| allocator.free(value);
        allocator.free(self.hunks);
        if (self.old_source) |value| allocator.free(value);
        if (self.new_source) |value| allocator.free(value);
        allocator.free(self.caveats);
    }

    pub fn displayPath(self: FileHunkRecord) []const u8 {
        return self.new_path orelse self.old_path orelse "";
    }
};

const Commit = struct {
    id: []u8,
    parent: ?[]u8,
    parent_count: usize,
    timestamp: ?i64,

    fn deinit(self: Commit, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        if (self.parent) |parent| allocator.free(parent);
    }
};

const CommitBatch = struct {
    commits: []Commit,
    truncated: bool,
};

const RawChange = struct {
    old_blob: ?[]u8,
    new_blob: ?[]u8,
    old_path: ?[]u8,
    new_path: ?[]u8,
    status: ChangeStatus,

    fn deinit(self: RawChange, allocator: std.mem.Allocator) void {
        if (self.old_blob) |value| allocator.free(value);
        if (self.new_blob) |value| allocator.free(value);
        if (self.old_path) |value| allocator.free(value);
        if (self.new_path) |value| allocator.free(value);
    }
};

const RawChangeBatch = struct {
    changes: []RawChange,
    truncated: bool,
};

pub fn deinitRecords(allocator: std.mem.Allocator, records: []FileHunkRecord) void {
    for (records) |record| record.deinit(allocator);
    allocator.free(records);
}

pub fn readHistory(
    allocator: std.mem.Allocator,
    io: std.Io,
    repo: []const u8,
    candidate_paths: []const []const u8,
    bounds: Bounds,
) ![]FileHunkRecord {
    const bounded_paths = candidate_paths[0..@min(candidate_paths.len, bounds.max_candidate_files)];
    var records: std.ArrayList(FileHunkRecord) = .empty;
    errdefer {
        for (records.items) |record| record.deinit(allocator);
        records.deinit(allocator);
    }

    const commit_batch = try readCommits(allocator, io, repo, bounded_paths, bounds.max_commits);
    defer {
        for (commit_batch.commits) |commit| commit.deinit(allocator);
        allocator.free(commit_batch.commits);
    }

    var changed_file_bound_exceeded = false;
    for (commit_batch.commits) |commit| {
        if (records.items.len >= bounds.max_changed_files) {
            changed_file_bound_exceeded = true;
            break;
        }
        const remaining_changed_files = bounds.max_changed_files - records.items.len;
        const change_batch = try readRawChanges(allocator, io, repo, commit.parent, commit.id, remaining_changed_files);
        defer {
            for (change_batch.changes) |change| change.deinit(allocator);
            allocator.free(change_batch.changes);
        }
        if (change_batch.truncated) changed_file_bound_exceeded = true;
        for (change_batch.changes) |change| {
            if (records.items.len >= bounds.max_changed_files) {
                changed_file_bound_exceeded = true;
                break;
            }
            var caveat_list: std.ArrayList([]const u8) = .empty;
            errdefer caveat_list.deinit(allocator);
            if (candidate_paths.len > bounds.max_candidate_files) try caveat_list.append(allocator, "candidate file bound exceeded; trailing paths skipped");
            if (commit_batch.truncated) try caveat_list.append(allocator, "commit bound exceeded; older commits skipped");
            if (change_batch.truncated) try caveat_list.append(allocator, "large commit/change-file policy: changed file bound exceeded; trailing files skipped");
            if (commit.parent_count > 1) try caveat_list.append(allocator, "merge commit simplified to first parent; additional parents not expanded");
            if (commit.parent == null) try caveat_list.append(allocator, "root commit has no parent pre-image");

            const pathspec = change.new_path orelse change.old_path orelse continue;
            if (bounded_paths.len > 0 and !pathMatchesCandidate(change, bounded_paths)) continue;
            var hunks_owned: ?[]Hunk = try readPatchHunks(allocator, io, repo, commit.parent, commit.id, pathspec, bounds.max_hunks_per_file, &caveat_list);
            errdefer if (hunks_owned) |hunks| allocator.free(hunks);

            var old_state: BlobState = .absent;
            var new_state: BlobState = .absent;
            var old_source: ?[]u8 = null;
            var new_source: ?[]u8 = null;
            errdefer if (old_source) |source| allocator.free(source);
            errdefer if (new_source) |source| allocator.free(source);

            if (change.old_blob) |blob| {
                const loaded = try loadBlob(allocator, io, repo, blob, bounds.max_blob_bytes);
                old_state = loaded.state;
                old_source = loaded.source;
                switch (loaded.state) {
                    .binary => try caveat_list.append(allocator, "old blob is binary; symbol parsing skipped"),
                    .too_large => try caveat_list.append(allocator, "old blob byte bound exceeded; symbol parsing skipped"),
                    .missing => try caveat_list.append(allocator, "old blob missing from local object database; no fetch attempted"),
                    else => {},
                }
            }
            if (change.new_blob) |blob| {
                const loaded = try loadBlob(allocator, io, repo, blob, bounds.max_blob_bytes);
                new_state = loaded.state;
                new_source = loaded.source;
                switch (loaded.state) {
                    .binary => try caveat_list.append(allocator, "new blob is binary; symbol parsing skipped"),
                    .too_large => try caveat_list.append(allocator, "new blob byte bound exceeded; symbol parsing skipped"),
                    .missing => try caveat_list.append(allocator, "new blob missing from local object database; no fetch attempted"),
                    else => {},
                }
            }

            try records.append(allocator, .{
                .commit_id = try allocator.dupe(u8, commit.id),
                .parent_id = if (commit.parent) |parent| try allocator.dupe(u8, parent) else null,
                .timestamp = commit.timestamp,
                .old_path = if (change.old_path) |path| try allocator.dupe(u8, path) else null,
                .new_path = if (change.new_path) |path| try allocator.dupe(u8, path) else null,
                .old_blob = if (change.old_blob) |blob| try allocator.dupe(u8, blob) else null,
                .new_blob = if (change.new_blob) |blob| try allocator.dupe(u8, blob) else null,
                .status = change.status,
                .hunks = hunks_owned.?,
                .old_blob_state = old_state,
                .new_blob_state = new_state,
                .old_source = old_source,
                .new_source = new_source,
                .caveats = try caveat_list.toOwnedSlice(allocator),
            });
            old_source = null;
            new_source = null;
            hunks_owned = null;
        }
    }

    if (changed_file_bound_exceeded) try appendCaveatToLastRecord(allocator, &records, "history changed-file bound exceeded; trailing commits or files skipped");

    std.mem.sort(FileHunkRecord, records.items, {}, lessRecord);
    return records.toOwnedSlice(allocator);
}

fn readCommits(allocator: std.mem.Allocator, io: std.Io, repo: []const u8, candidate_paths: []const []const u8, max_commits: usize) !CommitBatch {
    var args: std.ArrayList([]const u8) = .empty;
    defer args.deinit(allocator);
    try args.appendSlice(allocator, &.{ "log", "--first-parent", "--format=%H%x09%P%x09%ct", "--" });
    try args.appendSlice(allocator, candidate_paths);

    const stdout = try git_runner.runGitOk(allocator, io, repo, args.items);
    defer allocator.free(stdout);

    var commits: std.ArrayList(Commit) = .empty;
    errdefer {
        for (commits.items) |commit| commit.deinit(allocator);
        commits.deinit(allocator);
    }

    var truncated = false;
    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |raw_line| {
        if (raw_line.len == 0) continue;
        if (commits.items.len >= max_commits) {
            truncated = true;
            continue;
        }
        var fields = std.mem.splitScalar(u8, raw_line, '\t');
        const id = fields.next() orelse continue;
        const parents = fields.next() orelse "";
        const ts_raw = fields.next() orelse "";
        const first_parent = firstParent(parents);
        try commits.append(allocator, .{
            .id = try allocator.dupe(u8, id),
            .parent = if (first_parent.len > 0) try allocator.dupe(u8, first_parent) else null,
            .parent_count = countParents(parents),
            .timestamp = std.fmt.parseInt(i64, ts_raw, 10) catch null,
        });
    }
    return .{ .commits = try commits.toOwnedSlice(allocator), .truncated = truncated };
}

fn readRawChanges(allocator: std.mem.Allocator, io: std.Io, repo: []const u8, parent_id: ?[]const u8, commit_id: []const u8, max_changes: usize) !RawChangeBatch {
    var args: std.ArrayList([]const u8) = .empty;
    defer args.deinit(allocator);
    if (parent_id) |parent| {
        try args.appendSlice(allocator, &.{ "diff", "--raw", "-r", "-M", parent, commit_id, "--" });
    } else {
        try args.appendSlice(allocator, &.{ "diff-tree", "--root", "-r", "-M", "--no-commit-id", "--raw", commit_id, "--" });
    }

    const stdout = try git_runner.runGitOk(allocator, io, repo, args.items);
    defer allocator.free(stdout);

    var changes: std.ArrayList(RawChange) = .empty;
    errdefer {
        for (changes.items) |change| change.deinit(allocator);
        changes.deinit(allocator);
    }

    var truncated = false;
    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (changes.items.len >= max_changes) {
            truncated = true;
            continue;
        }
        if (try parseRawChange(allocator, line)) |change| try changes.append(allocator, change);
    }
    std.mem.sort(RawChange, changes.items, {}, lessRawChange);
    return .{ .changes = try changes.toOwnedSlice(allocator), .truncated = truncated };
}

fn parseRawChange(allocator: std.mem.Allocator, line: []const u8) !?RawChange {
    if (line.len == 0 or line[0] != ':') return null;
    const tab = std.mem.indexOfScalar(u8, line, '\t') orelse return null;
    const meta = line[1..tab];
    const paths = line[tab + 1 ..];
    var meta_parts = std.mem.splitScalar(u8, meta, ' ');
    _ = meta_parts.next() orelse return null;
    _ = meta_parts.next() orelse return null;
    const old_blob_raw = meta_parts.next() orelse return null;
    const new_blob_raw = meta_parts.next() orelse return null;
    const status_raw = meta_parts.next() orelse return null;
    const status = parseStatus(status_raw);

    var old_path: ?[]u8 = null;
    var new_path: ?[]u8 = null;
    errdefer {
        if (old_path) |path| allocator.free(path);
        if (new_path) |path| allocator.free(path);
    }

    if (status == .renamed or status == .copied) {
        var path_parts = std.mem.splitScalar(u8, paths, '\t');
        const lhs = path_parts.next() orelse return null;
        const rhs = path_parts.next() orelse return null;
        old_path = try allocator.dupe(u8, lhs);
        new_path = try allocator.dupe(u8, rhs);
    } else if (status == .deleted) {
        old_path = try allocator.dupe(u8, paths);
    } else {
        new_path = try allocator.dupe(u8, paths);
    }

    return .{
        .old_blob = if (isZeroObject(old_blob_raw)) null else try allocator.dupe(u8, old_blob_raw),
        .new_blob = if (isZeroObject(new_blob_raw)) null else try allocator.dupe(u8, new_blob_raw),
        .old_path = old_path,
        .new_path = new_path,
        .status = status,
    };
}

fn readPatchHunks(
    allocator: std.mem.Allocator,
    io: std.Io,
    repo: []const u8,
    parent_id: ?[]const u8,
    commit_id: []const u8,
    pathspec: []const u8,
    max_hunks: usize,
    caveats: *std.ArrayList([]const u8),
) ![]Hunk {
    var args: std.ArrayList([]const u8) = .empty;
    defer args.deinit(allocator);
    if (parent_id) |parent| {
        try args.appendSlice(allocator, &.{ "diff", "--no-color", "--unified=0", "--find-renames", parent, commit_id, "--", pathspec });
    } else {
        try args.appendSlice(allocator, &.{ "show", "--format=", "--no-color", "--unified=0", "--find-renames", commit_id, "--", pathspec });
    }
    const stdout = try git_runner.runGitOk(allocator, io, repo, args.items);
    defer allocator.free(stdout);

    var hunks: std.ArrayList(Hunk) = .empty;
    errdefer hunks.deinit(allocator);
    var lines = std.mem.splitScalar(u8, stdout, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "@@ ")) continue;
        if (hunks.items.len >= max_hunks) {
            try caveats.append(allocator, "hunk bound exceeded; trailing hunks skipped");
            break;
        }
        if (parseHunkHeader(line)) |hunk| try hunks.append(allocator, hunk);
    }
    if (hunks.items.len == 0 and std.mem.indexOf(u8, stdout, "Binary files") != null) {
        try caveats.append(allocator, "binary patch skipped; no text hunks available");
    }
    return hunks.toOwnedSlice(allocator);
}

const LoadedBlob = struct {
    state: BlobState,
    source: ?[]u8,
};

fn loadBlob(allocator: std.mem.Allocator, io: std.Io, repo: []const u8, blob_id: []const u8, max_blob_bytes: u64) !LoadedBlob {
    const size_stdout = git_runner.runGitOk(allocator, io, repo, &.{ "cat-file", "-s", blob_id }) catch return .{ .state = .missing, .source = null };
    defer allocator.free(size_stdout);
    const size = std.fmt.parseInt(u64, std.mem.trim(u8, size_stdout, "\r\n "), 10) catch return .{ .state = .missing, .source = null };
    if (size > max_blob_bytes) return .{ .state = .too_large, .source = null };

    const source = git_runner.runGitOk(allocator, io, repo, &.{ "cat-file", "-p", blob_id }) catch return .{ .state = .missing, .source = null };
    errdefer allocator.free(source);
    if (std.mem.indexOfScalar(u8, source, 0) != null) {
        allocator.free(source);
        return .{ .state = .binary, .source = null };
    }
    return .{ .state = .available, .source = source };
}

fn parseHunkHeader(line: []const u8) ?Hunk {
    const old_marker = std.mem.indexOfScalar(u8, line, '-') orelse return null;
    const plus_marker_rel = std.mem.indexOfScalar(u8, line[old_marker..], '+') orelse return null;
    const plus_marker = old_marker + plus_marker_rel;
    const old_token = trimHunkToken(line[old_marker + 1 .. plus_marker]);
    const after_plus = line[plus_marker + 1 ..];
    const new_end_rel = std.mem.indexOfScalar(u8, after_plus, ' ') orelse return null;
    const new_token = trimHunkToken(after_plus[0..new_end_rel]);
    return .{ .old = parseInterval(old_token), .new = parseInterval(new_token) };
}

fn trimHunkToken(token: []const u8) []const u8 {
    return std.mem.trim(u8, token, " ");
}

fn parseInterval(token: []const u8) ?LineInterval {
    if (token.len == 0) return null;
    var parts = std.mem.splitScalar(u8, token, ',');
    const start_raw = parts.next() orelse return null;
    const count_raw = parts.next();
    const start = std.fmt.parseInt(u32, start_raw, 10) catch return null;
    const count: u32 = if (count_raw) |raw| std.fmt.parseInt(u32, raw, 10) catch return null else 1;
    if (count == 0) return null;
    return .{ .start = start, .end = start + count - 1 };
}

fn parseStatus(raw: []const u8) ChangeStatus {
    if (raw.len == 0) return .unknown;
    return switch (raw[0]) {
        'A' => .added,
        'M' => .modified,
        'D' => .deleted,
        'R' => .renamed,
        'C' => .copied,
        'T' => .type_changed,
        else => .unknown,
    };
}

fn isZeroObject(value: []const u8) bool {
    for (value) |c| if (c != '0') return false;
    return true;
}

fn firstParent(parents: []const u8) []const u8 {
    const trimmed = std.mem.trim(u8, parents, " ");
    if (std.mem.indexOfScalar(u8, trimmed, ' ')) |space| return trimmed[0..space];
    return trimmed;
}

fn countParents(parents: []const u8) usize {
    const trimmed = std.mem.trim(u8, parents, " ");
    if (trimmed.len == 0) return 0;
    var count: usize = 1;
    for (trimmed) |c| {
        if (c == ' ') count += 1;
    }
    return count;
}

fn appendCaveatToLastRecord(allocator: std.mem.Allocator, records: *std.ArrayList(FileHunkRecord), caveat: []const u8) !void {
    if (records.items.len == 0) return;
    try appendRecordCaveat(allocator, &records.items[records.items.len - 1], caveat);
}

fn appendRecordCaveat(allocator: std.mem.Allocator, record: *FileHunkRecord, caveat: []const u8) !void {
    for (record.caveats) |existing| if (std.mem.eql(u8, existing, caveat)) return;
    const updated = try allocator.alloc([]const u8, record.caveats.len + 1);
    @memcpy(updated[0..record.caveats.len], record.caveats);
    updated[record.caveats.len] = caveat;
    allocator.free(record.caveats);
    record.caveats = updated;
}

fn lessRawChange(_: void, lhs: RawChange, rhs: RawChange) bool {
    return std.mem.order(u8, lhs.new_path orelse lhs.old_path orelse "", rhs.new_path orelse rhs.old_path orelse "") == .lt;
}

fn pathMatchesCandidate(change: RawChange, candidate_paths: []const []const u8) bool {
    for (candidate_paths) |candidate| {
        if (change.old_path) |path| if (std.mem.eql(u8, path, candidate)) return true;
        if (change.new_path) |path| if (std.mem.eql(u8, path, candidate)) return true;
    }
    return false;
}

fn lessRecord(_: void, lhs: FileHunkRecord, rhs: FileHunkRecord) bool {
    const commit_order = std.mem.order(u8, lhs.commit_id, rhs.commit_id);
    if (commit_order == .lt) return true;
    if (commit_order == .gt) return false;
    const path_order = std.mem.order(u8, lhs.displayPath(), rhs.displayPath());
    if (path_order == .lt) return true;
    if (path_order == .gt) return false;
    const status_order = std.mem.order(u8, @tagName(lhs.status), @tagName(rhs.status));
    if (status_order == .lt) return true;
    if (status_order == .gt) return false;
    return false;
}

test "hunk parser keeps delete and add intervals separate" {
    const hunk = parseHunkHeader("@@ -2,3 +4,5 @@").?;
    try std.testing.expectEqual(@as(u32, 2), hunk.old.?.start);
    try std.testing.expectEqual(@as(u32, 4), hunk.old.?.end);
    try std.testing.expectEqual(@as(u32, 4), hunk.new.?.start);
    try std.testing.expectEqual(@as(u32, 8), hunk.new.?.end);
    const added = parseHunkHeader("@@ -0,0 +1,2 @@").?;
    try std.testing.expect(added.old == null);
    try std.testing.expectEqual(@as(u32, 2), added.new.?.end);
}
