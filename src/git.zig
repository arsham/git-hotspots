const std = @import("std");
const model = @import("model.zig");
const scoring = @import("scoring.zig");

pub const AnalyzeError = anyerror;

fn freeResult(allocator: std.mem.Allocator, r: *model.Result) void {
    allocator.free(r.path);
    allocator.free(r.last_changed_commit);
    for (r.cochanges) |cc| allocator.free(cc.path);
    allocator.free(r.cochanges);
    for (r.caveats) |c| allocator.free(c);
    allocator.free(r.caveats);
    for (r.evidence) |ev| allocator.free(ev.commit);
    allocator.free(r.evidence);
}

fn runGit(allocator: std.mem.Allocator, io: std.Io, repo: []const u8, args: []const []const u8) !std.process.RunResult {
    var argv = std.array_list.Managed([]const u8).init(allocator);
    defer argv.deinit();
    try argv.append("git");
    try argv.append("-c");
    try argv.append("core.quotePath=false");
    try argv.append("-C");
    try argv.append(repo);
    for (args) |arg| try argv.append(arg);
    return std.process.run(allocator, io, .{ .argv = argv.items, .stdout_limit = .limited(50 * 1024 * 1024), .stderr_limit = .limited(1024 * 1024) });
}

fn runGitOk(allocator: std.mem.Allocator, io: std.Io, repo: []const u8, args: []const []const u8) ![]u8 {
    const rr = try runGit(allocator, io, repo, args);
    allocator.free(rr.stderr);
    switch (rr.term) {
        .exited => |code| if (code == 0) return rr.stdout,
        else => {},
    }
    allocator.free(rr.stdout);
    return error.GitFailed;
}

fn trimNewline(s: []u8) []const u8 {
    return std.mem.trim(u8, s, "\r\n ");
}

fn dupTrim(allocator: std.mem.Allocator, s: []u8) ![]u8 {
    return allocator.dupe(u8, std.mem.trim(u8, s, "\r\n "));
}

const EvidenceBuilder = struct { commit: []const u8, timestamp: i64, additions: ?u64, deletions: ?u64 };
const FileAgg = struct {
    path: []u8,
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
    allocator.free(agg.last_commit);
    agg.evidence.deinit();
    var it = agg.cochanges.keyIterator();
    while (it.next()) |k| allocator.free(k.*);
    var c = agg.cochanges;
    c.deinit();
}

fn addCaveat(allocator: std.mem.Allocator, list: *std.array_list.Managed([]const u8), text: []const u8) !void {
    try list.append(try allocator.dupe(u8, text));
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

pub fn analyze(allocator: std.mem.Allocator, io: std.Io, cfg: model.Config) AnalyzeError!model.Analysis {
    const bare_out = runGitOk(allocator, io, cfg.repo_path, &.{ "rev-parse", "--is-bare-repository" }) catch return error.NotGitRepository;
    defer allocator.free(bare_out);
    if (isTrueText(bare_out)) return error.BareRepository;

    const inside_out = runGitOk(allocator, io, cfg.repo_path, &.{ "rev-parse", "--is-inside-work-tree" }) catch return error.NotGitRepository;
    defer allocator.free(inside_out);
    if (!isTrueText(inside_out)) return error.NotGitRepository;

    const root_out = try runGitOk(allocator, io, cfg.repo_path, &.{ "rev-parse", "--show-toplevel" });
    const repo_root = try dupTrim(allocator, root_out);
    allocator.free(root_out);
    errdefer allocator.free(repo_root);

    const head_out = runGitOk(allocator, io, cfg.repo_path, &.{ "rev-parse", "HEAD" }) catch return error.EmptyRepository;
    const head = try dupTrim(allocator, head_out);
    allocator.free(head_out);
    errdefer allocator.free(head);

    const head_ts_out = try runGitOk(allocator, io, cfg.repo_path, &.{ "show", "-s", "--format=%ct", "HEAD" });
    const head_ts = try std.fmt.parseInt(i64, trimNewline(head_ts_out), 10);
    allocator.free(head_ts_out);

    const shallow_out = runGitOk(allocator, io, cfg.repo_path, &.{ "rev-parse", "--is-shallow-repository" }) catch try allocator.dupe(u8, "false");
    const is_shallow = isTrueText(shallow_out);
    allocator.free(shallow_out);

    const promisor = runGit(allocator, io, cfg.repo_path, &.{ "config", "--get", "remote.origin.promisor" }) catch null;
    var is_partial = false;
    if (promisor) |p| {
        is_partial = switch (p.term) {
            .exited => |code| code == 0 and isTrueText(p.stdout),
            else => false,
        };
        allocator.free(p.stdout);
        allocator.free(p.stderr);
    }

    const dirty_out = try runGitOk(allocator, io, cfg.repo_path, &.{ "status", "--porcelain" });
    const dirty = std.mem.trim(u8, dirty_out, "\r\n ").len != 0;
    allocator.free(dirty_out);

    var range_owned: ?[]u8 = null;
    var log_args = std.array_list.Managed([]const u8).init(allocator);
    defer log_args.deinit();
    try log_args.appendSlice(&.{ "log", "--format=%H%x09%ct", "--numstat", "--find-renames=40%" });
    if (cfg.since) |since| {
        const check = runGit(allocator, io, cfg.repo_path, &.{ "rev-parse", "--verify", since }) catch return error.InvalidSince;
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

    const log_out = try runGitOk(allocator, io, cfg.repo_path, log_args.items);
    defer allocator.free(log_out);

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

    var commit_count: usize = 0;
    var cur_hash: []const u8 = "";
    var cur_ts: i64 = 0;
    var commit_paths = std.array_list.Managed([]const u8).init(allocator);
    defer commit_paths.deinit();

    var lines = std.mem.splitScalar(u8, log_out, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, "\r");
        if (line.len == 0) continue;
        if (std.mem.indexOfScalar(u8, line, '\t')) |tab| {
            const first = line[0..tab];
            if (first.len == 40 and std.mem.indexOfScalar(u8, line[tab + 1 ..], '\t') == null) {
                try finishCommit(allocator, &map, commit_paths.items);
                commit_paths.clearRetainingCapacity();
                cur_hash = first;
                cur_ts = std.fmt.parseInt(i64, line[tab + 1 ..], 10) catch 0;
                commit_count += 1;
                continue;
            }
        }
        if (cur_hash.len == 0) continue;
        var parts = std.mem.splitScalar(u8, line, '\t');
        const add_s = parts.next() orelse continue;
        const del_s = parts.next() orelse continue;
        const path = parts.rest();
        if (path.len == 0) continue;
        try applyNumstat(allocator, &map, &commit_paths, &outside_include_paths, &outside_include_change_count, &excluded_paths, &excluded_change_count, cfg.include_prefixes, cfg.exclude_prefixes, cur_hash, cur_ts, add_s, del_s, path);
    }
    try finishCommit(allocator, &map, commit_paths.items);

    if (commit_count == 0) return error.EmptyRepository;

    var caveats = std.array_list.Managed([]const u8).init(allocator);
    errdefer {
        for (caveats.items) |c| allocator.free(c);
        caveats.deinit();
    }
    if (is_shallow) try addCaveat(allocator, &caveats, "history is shallow; auto_fetch is false");
    if (is_partial) try addCaveat(allocator, &caveats, "history may be partial/promisor; auto_fetch is false");
    if (dirty) try addCaveat(allocator, &caveats, "dirty worktree detected; ranking uses committed history only");

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
            if (std.mem.eql(u8, row.path, requested)) {
                found_index = i;
                break;
            }
        }
        const keep_index = found_index orelse return error.InspectTargetNotFound;
        const kept = results.items[keep_index];
        for (results.items, 0..) |*r, i| {
            if (i != keep_index) freeResult(allocator, r);
        }
        results.items[0] = kept;
        results.shrinkRetainingCapacity(1);
        inspect = .{
            .requested_path = try allocator.dupe(u8, requested),
            .matched_path = try allocator.dupe(u8, kept.path),
            .rank = keep_index + 1,
        };
    } else if (results.items.len > cfg.limit) {
        for (results.items[cfg.limit..]) |*r| {
            freeResult(allocator, r);
        }
        results.shrinkRetainingCapacity(cfg.limit);
    }

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
    commit: []const u8,
    ts: i64,
    add_s: []const u8,
    del_s: []const u8,
    raw_path: []const u8,
) !void {
    const path = try normalizePath(allocator, raw_path);
    defer allocator.free(path);
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
        gop.value_ptr.* = .{ .path = try allocator.dupe(u8, path), .last_commit = try allocator.dupe(u8, ""), .evidence = std.array_list.Managed(EvidenceBuilder).init(allocator), .cochanges = std.StringHashMap(u32).init(allocator) };
    }
    var agg = gop.value_ptr;
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
    if (agg.evidence.items.len < 3) try agg.evidence.append(.{ .commit = commit[0..@min(commit.len, 12)], .timestamp = ts, .additions = add, .deletions = del });
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

    const churn = agg.additions + agg.deletions;
    const breakdown = scoring.score(agg.change_count, churn, agg.last_ts, head_ts, cc_total);
    try out.append(.{
        .path = try allocator.dupe(u8, agg.path),
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

test "unquotes git quoted tab path before prefix matching" {
    const normalized = try normalizePath(std.testing.allocator, "\"weird/tab\\tname.txt\"");
    defer std.testing.allocator.free(normalized);
    try std.testing.expectEqualStrings("weird/tab\tname.txt", normalized);
    try std.testing.expect(isExcludedPath(normalized, &.{"weird/"}));
}
