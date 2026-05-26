const std = @import("std");
const git_history = @import("git_history.zig");
const git_path = @import("git_path.zig");

pub const LogParser = struct {
    allocator: std.mem.Allocator,
    map: *std.StringHashMap(git_history.FileAgg),
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

    pub fn init(
        allocator: std.mem.Allocator,
        map: *std.StringHashMap(git_history.FileAgg),
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

    pub fn deinit(self: *LogParser) void {
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
        try git_history.finishCommit(self.allocator, self.map, self.commit_paths.items);
    }

    fn processLine(self: *LogParser, raw_line: []const u8) !void {
        const line = std.mem.trim(u8, raw_line, "\r");
        if (line.len == 0) return;
        if (std.mem.indexOfScalar(u8, line, '\t')) |tab| {
            const first = line[0..tab];
            if (isCommitObjectId(first) and std.mem.indexOfScalar(u8, line[tab + 1 ..], '\t') == null) {
                try git_history.finishCommit(self.allocator, self.map, self.commit_paths.items);
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

fn isCommitObjectId(value: []const u8) bool {
    if (value.len != 40 and value.len != 64) return false;
    for (value) |c| {
        if (!std.ascii.isHex(c)) return false;
    }
    return true;
}

pub fn streamGitLog(
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

fn applyNumstat(
    allocator: std.mem.Allocator,
    map: *std.StringHashMap(git_history.FileAgg),
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
    var path = try git_path.normalizePath(allocator, raw_path);
    defer allocator.free(path);
    var row_lineage_partial = false;
    if (try git_path.parseRenamePath(allocator, raw_path)) |rename| {
        defer {
            allocator.free(rename.old_path);
            allocator.free(rename.new_path);
        }
        rename_detected.* = true;
        const old_ok = git_path.pathPassesFilters(rename.old_path, include_prefixes, exclude_prefixes);
        const new_ok = git_path.pathPassesFilters(rename.new_path, include_prefixes, exclude_prefixes);
        if (old_ok and new_ok) {
            const canonical_new = try git_history.resolveAliasOwned(allocator, aliases, rename.new_path);
            defer allocator.free(canonical_new);
            try git_history.putAlias(allocator, aliases, rename.old_path, canonical_new);
            try git_history.addAliasToAgg(allocator, map, canonical_new, rename.old_path);
            allocator.free(path);
            path = try allocator.dupe(u8, canonical_new);
        } else {
            partial_lineage.* = true;
            row_lineage_partial = true;
            if (!old_ok) try git_path.noteFilteredPath(allocator, rename.old_path, outside_include_paths, outside_include_change_count, excluded_paths, excluded_change_count, include_prefixes, exclude_prefixes);
        }
    } else {
        const canonical = try git_history.resolveAliasOwned(allocator, aliases, path);
        if (!std.mem.eql(u8, canonical, path)) {
            allocator.free(path);
            path = canonical;
        } else {
            allocator.free(canonical);
        }
    }
    if (git_path.isExcludedPath(path, exclude_prefixes)) {
        excluded_change_count.* += 1;
        if (excluded_paths.get(path) == null) {
            const owned = try allocator.dupe(u8, path);
            errdefer allocator.free(owned);
            try excluded_paths.put(owned, {});
        }
        return;
    }
    if (!git_path.isIncludedPath(path, include_prefixes)) {
        outside_include_change_count.* += 1;
        if (outside_include_paths.get(path) == null) {
            const owned = try allocator.dupe(u8, path);
            errdefer allocator.free(owned);
            try outside_include_paths.put(owned, {});
        }
        return;
    }
    const agg = map.getPtr(path) orelse blk: {
        try map.ensureUnusedCapacity(1);
        const owned_key = try allocator.dupe(u8, path);
        errdefer allocator.free(owned_key);
        const agg_init = try git_history.newAgg(allocator, path);
        map.putAssumeCapacityNoClobber(owned_key, agg_init);
        break :blk map.getPtr(path).?;
    };
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

test "lineage aliases canonicalize older history" {
    const allocator = std.testing.allocator;
    var map = std.StringHashMap(git_history.FileAgg).init(allocator);
    defer {
        var it = map.iterator();
        while (it.next()) |entry| git_history.deinitAgg(entry.key_ptr.*, entry.value_ptr.*, allocator);
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

test "streaming log parser handles chunk boundaries and numstat edge cases" {
    const allocator = std.testing.allocator;
    var map = std.StringHashMap(git_history.FileAgg).init(allocator);
    defer {
        var it = map.iterator();
        while (it.next()) |entry| git_history.deinitAgg(entry.key_ptr.*, entry.value_ptr.*, allocator);
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
    try parser.feed("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\t200\n5\t6\tunicod");
    try parser.feed("e/雪.zig");
    try parser.finish();

    try std.testing.expectEqual(@as(usize, 2), parser.commit_count);
    try std.testing.expectEqualStrings("bbbbbbbbbbbb", map.get("unicode/雪.zig").?.last_commit);
    try std.testing.expectEqual(@as(u32, 1), map.get("src/new.zig").?.change_count);
    try std.testing.expectEqual(@as(u32, 1), map.get("bin/blob.dat").?.binary_count);
    try std.testing.expectEqual(@as(u64, 3), map.get("weird/tab\tname.txt").?.additions);
    try std.testing.expectEqual(@as(u64, 6), map.get("unicode/雪.zig").?.deletions);
    try std.testing.expect(map.get("malformed") == null);
}
