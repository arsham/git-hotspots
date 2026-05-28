const std = @import("std");
const provider = @import("provider.zig");
const historical_symbol_attribution = @import("historical_symbol_attribution.zig");

pub const Format = enum { table, json, markdown };

pub const ScopePreset = enum { all, project };

pub fn scopePresetName(scope: ScopePreset) []const u8 {
    return @tagName(scope);
}

pub const Config = struct {
    repo_path: []const u8,
    limit: usize = 10,
    symbol_limit: ?usize = null,
    format: Format = .table,
    progress: bool = false,
    symbols: bool = false,
    symbol_line_history: bool = false,
    historical_symbols: bool = false,
    since: ?[]const u8 = null,
    inspect_path: ?[]const u8 = null,
    scope: ScopePreset = .project,
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
    lineage_aliases: [][]const u8,
    lineage_partial: bool = false,
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

pub const SymbolReport = struct {
    provider: provider.ProviderEvidence,
    symbols: []provider.CurrentSymbolEvidence,
};

pub const ProjectSymbolFile = struct {
    file_path: []const u8,
    parent_rank: usize,
    parent_score: f64,
    provider: provider.ProviderEvidence,
    symbols: []provider.CurrentSymbolEvidence,
};

pub const ProjectSymbolReport = struct {
    files: []ProjectSymbolFile,
    unsupported_count: usize,
    unavailable_count: usize,
    failed_count: usize,
    skipped_count: usize,

    pub fn totalSymbols(self: ProjectSymbolReport) usize {
        var total: usize = 0;
        for (self.files) |file| total += file.symbols.len;
        return total;
    }
};

pub const HistoricalSymbolReport = struct {
    candidate_path_count: usize,
    retained_candidate_path_count: usize,
    aggregate_record_bound: usize,
    aggregate_record_bound_exceeded: bool,
    aggregates: []historical_symbol_attribution.AggregateRecord,
    caveats: [][]const u8,

    pub fn deinit(self: HistoricalSymbolReport, allocator: std.mem.Allocator) void {
        historical_symbol_attribution.deinitAggregateRecords(allocator, self.aggregates);
        for (self.caveats) |caveat| allocator.free(caveat);
        allocator.free(self.caveats);
    }
};

pub const default_symbol_display_limit: usize = 25;

pub const SymbolDisplay = struct {
    limit: usize = default_symbol_display_limit,
    explicit_limit: bool = false,
};

pub const Analysis = struct {
    allocator: std.mem.Allocator,
    repo_root: []const u8,
    history: History,
    scope: Scope,
    inspect: ?Inspect = null,
    symbol_report: ?SymbolReport = null,
    project_symbol_report: ?ProjectSymbolReport = null,
    historical_symbol_report: ?HistoricalSymbolReport = null,
    symbol_display: SymbolDisplay = .{},
    results: []Result,
    caveats: [][]const u8,

    pub fn deinit(self: *Analysis) void {
        for (self.results) |row| {
            self.allocator.free(row.path);
            for (row.lineage_aliases) |alias| self.allocator.free(alias);
            self.allocator.free(row.lineage_aliases);
            self.allocator.free(row.last_changed_commit);
            for (row.cochanges) |cc| self.allocator.free(cc.path);
            self.allocator.free(row.cochanges);
            for (row.caveats) |c| self.allocator.free(c);
            self.allocator.free(row.caveats);
            for (row.evidence) |ev| self.allocator.free(ev.commit);
            self.allocator.free(row.evidence);
        }
        self.allocator.free(self.results);
        if (self.symbol_report) |symbols| {
            self.allocator.free(symbols.provider.input.identity);
            for (symbols.symbols) |symbol| {
                self.allocator.free(symbol.path);
                self.allocator.free(symbol.name);
                if (symbol.current_line_history) |line_history| {
                    for (line_history.sample_commits) |commit| self.allocator.free(commit);
                    self.allocator.free(line_history.sample_commits);
                    for (line_history.caveats) |caveat| self.allocator.free(caveat);
                    self.allocator.free(line_history.caveats);
                }
            }
            self.allocator.free(symbols.symbols);
        }
        if (self.project_symbol_report) |project_symbols| {
            for (project_symbols.files) |file| {
                self.allocator.free(file.file_path);
                self.allocator.free(file.provider.input.identity);
                for (file.symbols) |symbol| {
                    self.allocator.free(symbol.path);
                    self.allocator.free(symbol.name);
                    if (symbol.current_line_history) |line_history| {
                        for (line_history.sample_commits) |commit| self.allocator.free(commit);
                        self.allocator.free(line_history.sample_commits);
                        for (line_history.caveats) |caveat| self.allocator.free(caveat);
                        self.allocator.free(line_history.caveats);
                    }
                }
                self.allocator.free(file.symbols);
            }
            self.allocator.free(project_symbols.files);
        }
        if (self.historical_symbol_report) |historical_symbols| historical_symbols.deinit(self.allocator);
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
