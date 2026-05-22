const std = @import("std");

pub const Format = enum { table, json, markdown };

pub const ScopePreset = enum { all, project };

pub fn scopePresetName(scope: ScopePreset) []const u8 {
    return @tagName(scope);
}

pub const Config = struct {
    repo_path: []const u8,
    limit: usize = 10,
    format: Format = .table,
    since: ?[]const u8 = null,
    inspect_path: ?[]const u8 = null,
    scope: ScopePreset = .all,
    include_prefixes: []const []const u8 = &.{},
    exclude_prefixes: []const []const u8 = &.{},
};

pub const Inspect = struct {
    requested_path: []const u8,
    matched_path: []const u8,
    rank: usize,
};

pub const Scope = struct {
    selected_scope: ScopePreset,
    filters_active: bool,
    include_prefixes: [][]const u8,
    exclude_prefixes: [][]const u8,
    outside_include_path_count: usize,
    outside_include_change_count: usize,
    excluded_path_count: usize,
    excluded_change_count: usize,
};

pub const History = struct {
    head: []const u8,
    head_timestamp: i64,
    range: ?[]const u8,
    is_shallow: bool,
    is_partial: bool,
    auto_fetch: bool = false,
    dirty_worktree: bool,
    commit_count: usize,
};

pub const Evidence = struct {
    commit: []const u8,
    timestamp: i64,
    additions: ?u64,
    deletions: ?u64,
};

pub const CoChange = struct {
    path: []const u8,
    count: u32,
};

pub const ScoreBreakdown = struct {
    frequency: f64,
    churn: f64,
    recency: f64,
    cochange: f64,
    total: f64,
};

pub const Result = struct {
    path: []const u8,
    score: ScoreBreakdown,
    change_count: u32,
    additions: u64,
    deletions: u64,
    churn: u64,
    last_changed_timestamp: i64,
    last_changed_commit: []const u8,
    current_size: ?u64,
    cochanges: []CoChange,
    confidence: []const u8,
    caveats: [][]const u8,
    evidence: []Evidence,
};

pub const Analysis = struct {
    allocator: std.mem.Allocator,
    repo_root: []const u8,
    history: History,
    scope: Scope,
    inspect: ?Inspect = null,
    results: []Result,
    caveats: [][]const u8,

    pub fn deinit(self: *Analysis) void {
        for (self.results) |row| {
            self.allocator.free(row.path);
            self.allocator.free(row.last_changed_commit);
            for (row.cochanges) |cc| self.allocator.free(cc.path);
            self.allocator.free(row.cochanges);
            for (row.caveats) |c| self.allocator.free(c);
            self.allocator.free(row.caveats);
            for (row.evidence) |ev| self.allocator.free(ev.commit);
            self.allocator.free(row.evidence);
        }
        self.allocator.free(self.results);
        if (self.inspect) |inspect| {
            self.allocator.free(inspect.requested_path);
            self.allocator.free(inspect.matched_path);
        }
        for (self.scope.include_prefixes) |prefix| self.allocator.free(prefix);
        self.allocator.free(self.scope.include_prefixes);
        for (self.scope.exclude_prefixes) |prefix| self.allocator.free(prefix);
        self.allocator.free(self.scope.exclude_prefixes);
        for (self.caveats) |c| self.allocator.free(c);
        self.allocator.free(self.caveats);
        self.allocator.free(self.history.head);
        if (self.history.range) |r| self.allocator.free(r);
        self.allocator.free(self.repo_root);
    }
};
