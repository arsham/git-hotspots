const std = @import("std");
const model = @import("model.zig");
const scoring = @import("scoring.zig");
const git_runner = @import("git_runner.zig");
const git_line_history = @import("git_line_history.zig");
const git_path = @import("git_path.zig");
const git_history = @import("git_history.zig");
const git_log = @import("git_log.zig");

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

pub fn attachCurrentLineHistory(allocator: std.mem.Allocator, io: std.Io, analysis: *model.Analysis) !void {
    return git_line_history.attachCurrentLineHistory(allocator, io, analysis);
}

fn trimNewline(s: []u8) []const u8 {
    return std.mem.trim(u8, s, "\r\n ");
}

fn dupTrim(allocator: std.mem.Allocator, s: []u8) ![]u8 {
    return allocator.dupe(u8, std.mem.trim(u8, s, "\r\n "));
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

    var map = std.StringHashMap(git_history.FileAgg).init(allocator);
    defer {
        var it = map.iterator();
        while (it.next()) |entry| git_history.deinitAgg(entry.key_ptr.*, entry.value_ptr.*, allocator);
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

    var parser = git_log.LogParser.init(allocator, &map, &commit_paths, &outside_include_paths, &outside_include_change_count, &excluded_paths, &excluded_change_count, cfg.include_prefixes, cfg.exclude_prefixes, &aliases);
    defer parser.deinit();
    try git_log.streamGitLog(allocator, io, cfg.repo_path, log_args.items, &parser);
    commit_count = parser.commit_count;

    if (commit_count == 0) return error.EmptyRepository;

    try writeTimedProgress(progress, "git-read-parse", phase_started, io);

    var caveats = std.array_list.Managed([]const u8).init(allocator);
    errdefer {
        for (caveats.items) |c| allocator.free(c);
        caveats.deinit();
    }
    if (is_shallow) try git_history.addCaveat(allocator, &caveats, "history is shallow; auto_fetch is false");
    if (is_partial) try git_history.addCaveat(allocator, &caveats, "history may be partial/promisor; auto_fetch is false");
    if (dirty) try git_history.addCaveat(allocator, &caveats, "dirty worktree detected; ranking uses committed history only");
    if (parser.rename_detected) try git_history.addCaveat(allocator, &caveats, "Git rename lineage is conservative: local --find-renames=40% file edges only; copies, splits, merges, and symbol moves are not tracked");
    if (parser.partial_lineage) try git_history.addCaveat(allocator, &caveats, "some observed rename edges were outside active scope filters; lineage may be partial");

    phase_started = std.Io.Clock.Timestamp.now(io, .awake);
    try writeProgress(progress, "scoring files");

    var results = std.array_list.Managed(model.Result).init(allocator);
    errdefer {
        for (results.items) |*r| freeResult(allocator, r);
        results.deinit();
    }

    var it2 = map.iterator();
    while (it2.next()) |entry| try git_history.appendResult(allocator, io, &results, repo_root, entry.value_ptr.*, head_ts);
    std.mem.sort(model.Result, results.items, {}, scoring.lessThan);

    var inspect: ?model.Inspect = null;
    errdefer if (inspect) |meta| {
        allocator.free(meta.requested_path);
        allocator.free(meta.matched_path);
    };
    if (cfg.inspect_path) |requested| {
        var found_index: ?usize = null;
        for (results.items, 0..) |row, i| {
            if (std.mem.eql(u8, row.path, requested) or git_history.hasLineageAlias(row, requested)) {
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

    const scope_include_prefixes = try git_history.dupeStringList(allocator, cfg.include_prefixes);
    errdefer git_history.freeStringList(allocator, scope_include_prefixes);
    const scope_exclude_prefixes = try git_history.dupeStringList(allocator, cfg.exclude_prefixes);
    errdefer git_history.freeStringList(allocator, scope_exclude_prefixes);

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
