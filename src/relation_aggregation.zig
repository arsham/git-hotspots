const std = @import("std");
const model = @import("model.zig");
const provider = @import("provider.zig");
const tree_sitter_common = @import("tree_sitter_common.zig");
const tree_sitter_javascript = @import("tree_sitter_javascript.zig");
const tree_sitter_python = @import("tree_sitter_python.zig");
const tree_sitter_typescript = @import("tree_sitter_typescript.zig");

const invalid_path_caveats = [_][]const u8{
    "relation provider skipped candidate with invalid repo-relative path; retained provider failure for internal diagnostics",
    "symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction",
};

pub const Options = struct {
    max_candidate_files: usize = 64,
    max_relation_records: usize = 1024,
    max_source_bytes: u64 = tree_sitter_common.default_max_file_bytes,
    max_candidates_per_file: usize = tree_sitter_python.max_relation_candidates,
    force_provider_unavailable: bool = false,
};

const CandidateFile = struct {
    path: []const u8,
    parent_rank: usize,
};

pub fn attach(
    allocator: std.mem.Allocator,
    io: std.Io,
    analysis: *model.Analysis,
    options: Options,
) !void {
    if (analysis.relation_report) |report| {
        report.deinit(allocator);
        analysis.relation_report = null;
    }
    analysis.relation_report = try build(allocator, io, analysis.*, options);
}

pub fn build(
    allocator: std.mem.Allocator,
    io: std.Io,
    analysis: model.Analysis,
    options: Options,
) !model.RelationAggregationReport {
    const candidates = try candidateFiles(allocator, analysis.results);
    defer freeCandidateFiles(allocator, candidates);

    var providers: std.ArrayList(model.RelationProviderReport) = .empty;
    errdefer {
        deinitProviderReports(allocator, providers.items);
        providers.deinit(allocator);
    }

    var records: std.ArrayList(model.RelationRecord) = .empty;
    errdefer {
        deinitRelationRecords(allocator, records.items);
        records.deinit(allocator);
    }

    var caveats: std.ArrayList([]const u8) = .empty;
    errdefer {
        deinitStringList(allocator, caveats.items);
        caveats.deinit(allocator);
    }

    const retained_file_count = @min(candidates.len, options.max_candidate_files);
    if (candidates.len > retained_file_count) try appendOwnedCaveat(allocator, &caveats, "relation candidate file bound exceeded; trailing retained ranked-file candidates skipped");
    try addAnalysisCaveats(allocator, &caveats, analysis);

    var relation_bound_exceeded = false;
    var omitted_record_count: usize = 0;

    for (candidates[0..retained_file_count]) |candidate| {
        var extraction = extractRelationsPath(allocator, io, analysis.repo_root, candidate.path, options) catch |err| switch (err) {
            error.InvalidRepoRelativePath => {
                try appendInvalidPathProviderReport(allocator, &providers, candidate);
                try appendOwnedCaveat(allocator, &caveats, invalid_path_caveats[0]);
                continue;
            },
            else => return err,
        };
        defer extraction.deinit(allocator);

        try appendProviderReport(allocator, &providers, candidate, extraction);
        try addProviderCaveats(allocator, &caveats, extraction);

        for (extraction.candidates) |relation| {
            if (try appendRelationRecord(allocator, &records, relation, options.max_relation_records)) |omitted| {
                if (omitted) {
                    relation_bound_exceeded = true;
                    omitted_record_count += 1;
                }
            }
        }
    }

    if (relation_bound_exceeded) try appendOwnedCaveat(allocator, &caveats, "relation record bound exceeded; trailing relation candidates omitted");

    std.mem.sort(model.RelationProviderReport, providers.items, {}, lessProviderReport);
    std.mem.sort(model.RelationRecord, records.items, {}, lessRelationRecord);

    return .{
        .candidate_file_count = candidates.len,
        .retained_candidate_file_count = retained_file_count,
        .current_symbol_candidate_count = currentSymbolCandidateCount(analysis),
        .relation_record_bound = options.max_relation_records,
        .relation_record_bound_exceeded = relation_bound_exceeded,
        .omitted_record_count = omitted_record_count,
        .providers = try providers.toOwnedSlice(allocator),
        .records = try records.toOwnedSlice(allocator),
        .caveats = try caveats.toOwnedSlice(allocator),
    };
}

fn extractRelationsPath(
    allocator: std.mem.Allocator,
    io: std.Io,
    repo_root: []const u8,
    path: []const u8,
    options: Options,
) !tree_sitter_python.RelationExtraction {
    if (std.mem.endsWith(u8, path, ".py")) {
        const relation_options: tree_sitter_python.RelationOptions = .{
            .max_source_bytes = options.max_source_bytes,
            .max_candidates = options.max_candidates_per_file,
            .force_provider_unavailable = options.force_provider_unavailable,
        };
        const source = try tree_sitter_common.readBoundedFile(allocator, io, repo_root, path, options.max_source_bytes) orelse
            return tree_sitter_python.extractRelationsSource(allocator, path, "", .{
                .max_source_bytes = options.max_source_bytes,
                .max_candidates = options.max_candidates_per_file,
                .force_provider_unavailable = true,
            });
        defer allocator.free(source);
        return tree_sitter_python.extractRelationsSource(allocator, path, source, relation_options);
    }

    if (tree_sitter_javascript.isSupportedJavaScriptPath(path)) {
        const relation_options: tree_sitter_javascript.RelationOptions = .{
            .max_source_bytes = options.max_source_bytes,
            .max_candidates = options.max_candidates_per_file,
            .force_provider_unavailable = options.force_provider_unavailable,
        };
        const source = try tree_sitter_common.readBoundedFile(allocator, io, repo_root, path, options.max_source_bytes) orelse
            return tree_sitter_javascript.extractRelationsSource(allocator, path, "", .{
                .max_source_bytes = options.max_source_bytes,
                .max_candidates = options.max_candidates_per_file,
                .force_provider_unavailable = true,
            });
        defer allocator.free(source);
        return tree_sitter_javascript.extractRelationsSource(allocator, path, source, relation_options);
    }

    if (tree_sitter_typescript.isSupportedPath(path)) {
        const relation_options: tree_sitter_typescript.RelationOptions = .{
            .max_source_bytes = options.max_source_bytes,
            .max_candidates = options.max_candidates_per_file,
            .force_provider_unavailable = options.force_provider_unavailable,
        };
        const source = try tree_sitter_common.readBoundedFile(allocator, io, repo_root, path, options.max_source_bytes) orelse
            return tree_sitter_typescript.extractRelationsSource(allocator, path, "", .{
                .max_source_bytes = options.max_source_bytes,
                .max_candidates = options.max_candidates_per_file,
                .force_provider_unavailable = true,
            });
        defer allocator.free(source);
        return tree_sitter_typescript.extractRelationsSource(allocator, path, source, relation_options);
    }

    const relation_options: tree_sitter_python.RelationOptions = .{
        .max_source_bytes = options.max_source_bytes,
        .max_candidates = options.max_candidates_per_file,
        .force_provider_unavailable = options.force_provider_unavailable,
    };
    return tree_sitter_python.extractRelationsSource(allocator, path, "", relation_options);
}

fn candidateFiles(allocator: std.mem.Allocator, results: []const model.Result) ![]CandidateFile {
    var seen = std.StringHashMap(void).init(allocator);
    defer {
        var it = seen.keyIterator();
        while (it.next()) |key| allocator.free(key.*);
        seen.deinit();
    }

    var files: std.ArrayList(CandidateFile) = .empty;
    errdefer {
        for (files.items) |file| allocator.free(file.path);
        files.deinit(allocator);
    }

    for (results, 0..) |result, index| {
        if (seen.contains(result.path)) continue;
        var seen_path: ?[]u8 = try allocator.dupe(u8, result.path);
        errdefer if (seen_path) |value| allocator.free(value);
        var owned_path: ?[]u8 = try allocator.dupe(u8, result.path);
        errdefer if (owned_path) |value| allocator.free(value);

        try seen.put(seen_path.?, {});
        errdefer if (seen_path) |value| {
            _ = seen.remove(value);
            allocator.free(value);
        };
        try files.append(allocator, .{ .path = owned_path.?, .parent_rank = index + 1 });
        seen_path = null;
        owned_path = null;
    }

    return files.toOwnedSlice(allocator);
}

fn appendProviderReport(
    allocator: std.mem.Allocator,
    providers: *std.ArrayList(model.RelationProviderReport),
    candidate: CandidateFile,
    extraction: tree_sitter_python.RelationExtraction,
) !void {
    const provider_report = try cloneProvider(allocator, extraction.provider);
    errdefer allocator.free(provider_report.input.identity);
    try providers.append(allocator, .{
        .file_path = try allocator.dupe(u8, candidate.path),
        .parent_rank = candidate.parent_rank,
        .provider = provider_report,
        .candidate_count = extraction.candidates.len,
        .omitted_count = extraction.omitted_count,
        .cap_reached = extraction.cap_reached,
    });
}

fn appendInvalidPathProviderReport(
    allocator: std.mem.Allocator,
    providers: *std.ArrayList(model.RelationProviderReport),
    candidate: CandidateFile,
) !void {
    const identity = try std.fmt.allocPrint(allocator, "working-tree:{s}", .{candidate.path});
    errdefer allocator.free(identity);
    try providers.append(allocator, .{
        .file_path = try allocator.dupe(u8, candidate.path),
        .parent_rank = candidate.parent_rank,
        .provider = .{
            .name = "tree-sitter-python-relations",
            .kind = .relation,
            .version = "0.25.0-local-relations-1",
            .input = .{ .identity = identity },
            .freshness = .unknown,
            .failure = .skipped,
            .confidence = .low,
            .caveats = &invalid_path_caveats,
            .provenance = .{ .provider_name = "tree-sitter-python-relations", .input_identity = identity },
        },
        .candidate_count = 0,
        .omitted_count = 0,
        .cap_reached = false,
    });
}

fn cloneProvider(allocator: std.mem.Allocator, evidence: provider.ProviderEvidence) !provider.ProviderEvidence {
    const identity = try allocator.dupe(u8, evidence.input.identity);
    errdefer allocator.free(identity);
    return .{
        .name = evidence.name,
        .kind = evidence.kind,
        .version = evidence.version,
        .contract_version = evidence.contract_version,
        .config_fingerprint = evidence.config_fingerprint,
        .input = .{ .identity = identity },
        .freshness = evidence.freshness,
        .failure = evidence.failure,
        .confidence = evidence.confidence,
        .caveats = evidence.caveats,
        .provenance = .{ .provider_name = evidence.provenance.provider_name, .input_identity = identity },
    };
}

fn appendRelationRecord(
    allocator: std.mem.Allocator,
    records: *std.ArrayList(model.RelationRecord),
    relation: provider.RelationCandidate,
    bound: usize,
) !?bool {
    const source_key = try relationEndpointKey(allocator, relation.source);
    errdefer allocator.free(source_key);
    const target_key = try relationEndpointKey(allocator, relation.target);
    errdefer allocator.free(target_key);
    const sort_key = try std.fmt.allocPrint(allocator, "{s}\x1f{s}\x1f{s}\x1f{s}\x1f{s}\x1f{s}", .{ source_key, target_key, @tagName(relation.kind), @tagName(relation.direction), relation.provider.name, relation.evidence_basis });
    errdefer allocator.free(sort_key);

    for (records.items) |*existing| {
        if (!std.mem.eql(u8, existing.sort_key, sort_key)) continue;
        allocator.free(source_key);
        allocator.free(target_key);
        allocator.free(sort_key);
        try mergeCaveats(allocator, &existing.caveats, relation.caveats);
        try mergeCaveats(allocator, &existing.caveats, relation.provider.caveats);
        return false;
    }

    if (records.items.len >= bound) {
        allocator.free(source_key);
        allocator.free(target_key);
        allocator.free(sort_key);
        return true;
    }

    var caveats: std.ArrayList([]const u8) = .empty;
    errdefer {
        deinitStringList(allocator, caveats.items);
        caveats.deinit(allocator);
    }
    try mergeCaveatsList(allocator, &caveats, relation.caveats);
    try mergeCaveatsList(allocator, &caveats, relation.provider.caveats);

    try records.append(allocator, .{
        .kind = relation.kind,
        .direction = relation.direction,
        .source_key = source_key,
        .target_key = target_key,
        .evidence_basis = try allocator.dupe(u8, relation.evidence_basis),
        .provider_name = try allocator.dupe(u8, relation.provider.name),
        .provider_input_identity = try allocator.dupe(u8, relation.provider.input.identity),
        .freshness = relation.freshness,
        .failure = relation.failure,
        .confidence = relation.confidence,
        .caveats = try caveats.toOwnedSlice(allocator),
        .sort_key = sort_key,
    });
    return false;
}

fn relationEndpointKey(allocator: std.mem.Allocator, endpoint: provider.RelationEndpoint) ![]u8 {
    return switch (endpoint) {
        .file => |file| std.fmt.allocPrint(allocator, "file:{s}", .{file.path}),
        .current_symbol => |symbol| std.fmt.allocPrint(allocator, "symbol:{s}:{s}:{s}", .{ symbol.path, symbol.name, @tagName(symbol.kind) }),
        .report_symbol => |symbol| std.fmt.allocPrint(allocator, "report-symbol:{s}:{s}:{any}", .{ symbol.path, symbol.name, symbol.rank }),
        .unresolved => |named| std.fmt.allocPrint(allocator, "unresolved:{s}", .{named.value}),
        .external_string => |named| std.fmt.allocPrint(allocator, "external:{s}", .{named.value}),
    };
}

fn addProviderCaveats(allocator: std.mem.Allocator, caveats: *std.ArrayList([]const u8), extraction: tree_sitter_python.RelationExtraction) !void {
    if (extraction.provider.failure != .ok) try appendOwnedCaveat(allocator, caveats, "relation provider produced non-ok evidence; retained provider failure for internal diagnostics");
    switch (extraction.provider.freshness) {
        .partial => try appendOwnedCaveat(allocator, caveats, "relation evidence is partial; provider candidate cap or bounded input limited the internal graph"),
        .stale => try appendOwnedCaveat(allocator, caveats, "relation evidence is stale; internal graph must not be used as product truth"),
        else => {},
    }
    for (extraction.provider.caveats) |caveat| try appendOwnedCaveat(allocator, caveats, caveat);
}

fn addAnalysisCaveats(allocator: std.mem.Allocator, caveats: *std.ArrayList([]const u8), analysis: model.Analysis) !void {
    if (analysis.scope.filters_active and (analysis.scope.outside_include_path_count > 0 or analysis.scope.excluded_path_count > 0)) {
        try appendOwnedCaveat(allocator, caveats, "relation aggregation used filtered retained hotspot scope; excluded or outside-include files were not relation candidates");
    }
    if (analysis.historical_symbol_report != null) {
        try appendOwnedCaveat(allocator, caveats, "relation evidence is current working-tree only; historical symbol evidence is not used for relation aggregation");
    }
}

fn currentSymbolCandidateCount(analysis: model.Analysis) usize {
    if (analysis.symbol_report) |symbols| return symbols.symbols.len;
    if (analysis.project_symbol_report) |project_symbols| return project_symbols.totalSymbols();
    return 0;
}

fn appendOwnedCaveat(allocator: std.mem.Allocator, caveats: *std.ArrayList([]const u8), caveat: []const u8) !void {
    for (caveats.items) |existing| if (std.mem.eql(u8, existing, caveat)) return;
    try caveats.append(allocator, try allocator.dupe(u8, caveat));
}

fn mergeCaveats(allocator: std.mem.Allocator, target: *[][]const u8, caveats: []const []const u8) !void {
    var merged: std.ArrayList([]const u8) = .empty;
    errdefer deinitStringList(allocator, merged.items);
    for (target.*) |existing| try appendOwnedCaveat(allocator, &merged, existing);
    for (caveats) |caveat| try appendOwnedCaveat(allocator, &merged, caveat);
    deinitStringList(allocator, target.*);
    allocator.free(target.*);
    target.* = try merged.toOwnedSlice(allocator);
}

fn mergeCaveatsList(allocator: std.mem.Allocator, target: *std.ArrayList([]const u8), caveats: []const []const u8) !void {
    for (caveats) |caveat| try appendOwnedCaveat(allocator, target, caveat);
}

fn lessProviderReport(_: void, lhs: model.RelationProviderReport, rhs: model.RelationProviderReport) bool {
    if (std.mem.order(u8, lhs.file_path, rhs.file_path) != .eq) return std.mem.order(u8, lhs.file_path, rhs.file_path) == .lt;
    return lhs.parent_rank < rhs.parent_rank;
}

fn lessRelationRecord(_: void, lhs: model.RelationRecord, rhs: model.RelationRecord) bool {
    return std.mem.order(u8, lhs.sort_key, rhs.sort_key) == .lt;
}

fn deinitProviderReports(allocator: std.mem.Allocator, reports: []model.RelationProviderReport) void {
    for (reports) |report| {
        allocator.free(report.file_path);
        allocator.free(report.provider.input.identity);
    }
}

fn deinitRelationRecords(allocator: std.mem.Allocator, records: []model.RelationRecord) void {
    for (records) |record| {
        allocator.free(record.source_key);
        allocator.free(record.target_key);
        allocator.free(record.evidence_basis);
        allocator.free(record.provider_name);
        allocator.free(record.provider_input_identity);
        deinitStringList(allocator, record.caveats);
        allocator.free(record.caveats);
        allocator.free(record.sort_key);
    }
}

fn deinitStringList(allocator: std.mem.Allocator, strings: []const []const u8) void {
    for (strings) |string| allocator.free(string);
}

fn freeCandidateFiles(allocator: std.mem.Allocator, files: []const CandidateFile) void {
    for (files) |file| allocator.free(file.path);
    allocator.free(files);
}

fn reportContainsCaveat(report: model.RelationAggregationReport, needle: []const u8) bool {
    for (report.caveats) |caveat| if (std.mem.indexOf(u8, caveat, needle) != null) return true;
    return false;
}

fn writeFixtureFile(io: std.Io, root: []const u8, relative_path: []const u8, contents: []const u8) !void {
    const full_path = try std.fs.path.join(std.testing.allocator, &.{ root, relative_path });
    defer std.testing.allocator.free(full_path);
    if (std.fs.path.dirname(full_path)) |dir| try std.Io.Dir.cwd().createDirPath(io, dir);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = full_path, .data = contents });
}

fn emptySlice(comptime T: type, allocator: std.mem.Allocator) ![]T {
    return allocator.alloc(T, 0);
}

fn makeResult(allocator: std.mem.Allocator, path: []const u8) !model.Result {
    return .{
        .path = try allocator.dupe(u8, path),
        .lineage_aliases = try emptySlice([]const u8, allocator),
        .score = .{ .frequency = 1, .churn = 1, .recency = 1, .cochange = 0, .total = 3 },
        .change_count = 1,
        .additions = 1,
        .deletions = 0,
        .churn = 1,
        .last_changed_timestamp = 1,
        .last_changed_commit = try allocator.dupe(u8, "fixture"),
        .current_size = 1,
        .cochanges = try emptySlice(model.CoChange, allocator),
        .confidence = "fixture",
        .caveats = try emptySlice([]const u8, allocator),
        .evidence = try emptySlice(model.Evidence, allocator),
    };
}

fn makeAnalysis(allocator: std.mem.Allocator, repo_root: []const u8, results: []model.Result) !model.Analysis {
    return .{
        .allocator = allocator,
        .repo_root = try allocator.dupe(u8, repo_root),
        .history = .{ .head = try allocator.dupe(u8, "fixture-head"), .head_timestamp = 1, .range = null, .is_shallow = false, .is_partial = false, .dirty_worktree = false, .commit_count = 1 },
        .scope = .{ .selected_scope = .all, .filters_active = false, .include_prefixes = try emptySlice([]const u8, allocator), .exclude_prefixes = try emptySlice([]const u8, allocator), .outside_include_path_count = 0, .outside_include_change_count = 0, .excluded_path_count = 0, .excluded_change_count = 0 },
        .results = results,
        .caveats = try emptySlice([]const u8, allocator),
    };
}

fn attachSymbolFixture(allocator: std.mem.Allocator, analysis: *model.Analysis) !void {
    const files = try allocator.alloc(model.ProjectSymbolFile, 1);
    const symbols = try allocator.alloc(provider.CurrentSymbolEvidence, 1);
    const identity = try allocator.dupe(u8, "working-tree:pkg/app.py");
    symbols[0] = .{
        .path = try allocator.dupe(u8, "pkg/app.py"),
        .name = try allocator.dupe(u8, "helper"),
        .kind = .function,
        .current_range = .{ .lines = .{ .start = 3, .end = 4 } },
        .provider_name = "fixture-symbol-provider",
        .confidence = .high,
    };
    files[0] = .{
        .file_path = try allocator.dupe(u8, "pkg/app.py"),
        .parent_rank = 1,
        .parent_score = 3,
        .provider = .{
            .name = "fixture-symbol-provider",
            .kind = .symbol,
            .version = "fixture",
            .input = .{ .identity = identity },
            .freshness = .fresh,
            .failure = .ok,
            .confidence = .high,
            .provenance = .{ .provider_name = "fixture-symbol-provider", .input_identity = identity },
        },
        .symbols = symbols,
    };
    analysis.project_symbol_report = .{ .files = files, .unsupported_count = 0, .unavailable_count = 0, .failed_count = 0, .skipped_count = 0 };
}

test "relation aggregation attaches retained file and symbol candidates internally" {
    const allocator = std.testing.allocator;
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const repo = ".zig-cache/relation-aggregation-fixture";
    std.Io.Dir.cwd().deleteTree(io, repo) catch {};
    try std.Io.Dir.cwd().createDirPath(io, repo);
    defer std.Io.Dir.cwd().deleteTree(io, repo) catch {};
    try writeFixtureFile(io, repo, "pkg/app.py",
        \\import os
        \\def helper():
        \\    return 1
        \\def caller():
        \\    return helper()
        \\
    );
    try writeFixtureFile(io, repo, "README.md", "# unsupported\n");

    const results = try allocator.alloc(model.Result, 2);
    results[0] = try makeResult(allocator, "pkg/app.py");
    results[1] = try makeResult(allocator, "README.md");
    var analysis = try makeAnalysis(allocator, repo, results);
    defer analysis.deinit();
    try attachSymbolFixture(allocator, &analysis);

    try attach(allocator, io, &analysis, .{ .max_candidate_files = 4, .max_relation_records = 64 });
    const report = analysis.relation_report.?;
    try std.testing.expectEqual(@as(usize, 2), report.candidate_file_count);
    try std.testing.expectEqual(@as(usize, 2), report.retained_candidate_file_count);
    try std.testing.expectEqual(@as(usize, 1), report.current_symbol_candidate_count);
    try std.testing.expect(report.records.len > 0);
    try std.testing.expectEqual(@as(usize, 2), report.providers.len);
    try std.testing.expect(reportContainsCaveat(report, "optional caveated provider evidence"));

    var saw_unsupported = false;
    for (report.providers) |file| {
        if (std.mem.eql(u8, file.file_path, "README.md")) saw_unsupported = file.provider.failure == .unsupported;
    }
    try std.testing.expect(saw_unsupported);

    var second = try build(allocator, io, analysis, .{ .max_candidate_files = 4, .max_relation_records = 64 });
    defer second.deinit(allocator);
    try std.testing.expectEqual(report.records.len, second.records.len);
    if (report.records.len > 0) try std.testing.expectEqualStrings(report.records[0].sort_key, second.records[0].sort_key);
}

test "relation aggregation preserves bounds provider failures and omission counts" {
    const allocator = std.testing.allocator;
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const repo = ".zig-cache/relation-aggregation-bounds-fixture";
    std.Io.Dir.cwd().deleteTree(io, repo) catch {};
    try std.Io.Dir.cwd().createDirPath(io, repo);
    defer std.Io.Dir.cwd().deleteTree(io, repo) catch {};
    try writeFixtureFile(io, repo, "pkg/many.py",
        \\def one():
        \\    return 1
        \\def two():
        \\    return one()
        \\def three():
        \\    return two()
        \\
    );

    const results = try allocator.alloc(model.Result, 1);
    results[0] = try makeResult(allocator, "pkg/many.py");
    var analysis = try makeAnalysis(allocator, repo, results);
    defer analysis.deinit();

    try attach(allocator, io, &analysis, .{ .max_candidate_files = 1, .max_relation_records = 1, .max_candidates_per_file = 2 });
    const report = analysis.relation_report.?;
    try std.testing.expect(report.relation_record_bound_exceeded or report.providers[0].cap_reached);
    try std.testing.expect(report.records.len <= 1);
    try std.testing.expect(report.omitted_record_count > 0 or report.providers[0].omitted_count > 0);
    try std.testing.expect(reportContainsCaveat(report, "partial"));
}

test "relation aggregation records filtered scope and no provider success cases" {
    const allocator = std.testing.allocator;
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const repo = ".zig-cache/relation-aggregation-filtered-fixture";
    std.Io.Dir.cwd().deleteTree(io, repo) catch {};
    try std.Io.Dir.cwd().createDirPath(io, repo);
    defer std.Io.Dir.cwd().deleteTree(io, repo) catch {};
    try writeFixtureFile(io, repo, "pkg/app.py",
        \\def helper():
        \\    return 1
        \\
    );

    const results = try allocator.alloc(model.Result, 1);
    results[0] = try makeResult(allocator, "pkg/app.py");
    var analysis = try makeAnalysis(allocator, repo, results);
    defer analysis.deinit();
    analysis.scope.filters_active = true;
    analysis.scope.excluded_path_count = 2;
    analysis.scope.excluded_change_count = 3;

    try attach(allocator, io, &analysis, .{ .force_provider_unavailable = true });
    const report = analysis.relation_report.?;
    try std.testing.expectEqual(@as(usize, 1), analysis.results.len);
    try std.testing.expectEqualStrings("pkg/app.py", analysis.results[0].path);
    try std.testing.expectEqual(@as(usize, 1), report.providers.len);
    try std.testing.expectEqual(provider.Failure.unavailable, report.providers[0].provider.failure);
    try std.testing.expectEqual(@as(usize, 0), report.records.len);
    try std.testing.expect(reportContainsCaveat(report, "filtered retained hotspot scope"));
    try std.testing.expect(reportContainsCaveat(report, "non-ok evidence"));
}

test "relation aggregation merges duplicate candidate caveats across passes" {
    const allocator = std.testing.allocator;
    var records: std.ArrayList(model.RelationRecord) = .empty;
    defer {
        deinitRelationRecords(allocator, records.items);
        records.deinit(allocator);
    }

    const first = relationCandidateFixture(&.{"first caveat"});
    const second = relationCandidateFixture(&.{"second caveat"});
    try std.testing.expectEqual(false, (try appendRelationRecord(allocator, &records, first, 8)).?);
    try std.testing.expectEqual(false, (try appendRelationRecord(allocator, &records, second, 8)).?);
    try std.testing.expectEqual(@as(usize, 1), records.items.len);
    try containsCaveat(records.items[0].caveats, "first caveat");
    try containsCaveat(records.items[0].caveats, "second caveat");
}

test "relation aggregation file cap can truncate one file while another completes" {
    const allocator = std.testing.allocator;
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const repo = ".zig-cache/relation-aggregation-mixed-cap-fixture";
    std.Io.Dir.cwd().deleteTree(io, repo) catch {};
    try std.Io.Dir.cwd().createDirPath(io, repo);
    defer std.Io.Dir.cwd().deleteTree(io, repo) catch {};
    try writeFixtureFile(io, repo, "pkg/capped.py",
        \\def one():
        \\    return 1
        \\def two():
        \\    return one()
        \\def three():
        \\    return two()
        \\
    );
    try writeFixtureFile(io, repo, "pkg/complete.py", "def only():\n    return 1\n");

    const results = try allocator.alloc(model.Result, 2);
    results[0] = try makeResult(allocator, "pkg/capped.py");
    results[1] = try makeResult(allocator, "pkg/complete.py");
    var analysis = try makeAnalysis(allocator, repo, results);
    defer analysis.deinit();

    try attach(allocator, io, &analysis, .{ .max_candidates_per_file = 2, .max_relation_records = 16 });
    const report = analysis.relation_report.?;
    var saw_capped = false;
    var saw_complete = false;
    for (report.providers) |file| {
        if (std.mem.eql(u8, file.file_path, "pkg/capped.py")) saw_capped = file.cap_reached and file.omitted_count > 0;
        if (std.mem.eql(u8, file.file_path, "pkg/complete.py")) saw_complete = !file.cap_reached and file.provider.failure == .ok;
    }
    try std.testing.expect(saw_capped);
    try std.testing.expect(saw_complete);
}

test "relation aggregation remains current-only when historical symbols exist" {
    const allocator = std.testing.allocator;
    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const repo = ".zig-cache/relation-aggregation-current-only-fixture";
    std.Io.Dir.cwd().deleteTree(io, repo) catch {};
    try std.Io.Dir.cwd().createDirPath(io, repo);
    defer std.Io.Dir.cwd().deleteTree(io, repo) catch {};
    try writeFixtureFile(io, repo, "pkg/app.py", "def helper():\n    return 1\n");

    const results = try allocator.alloc(model.Result, 1);
    results[0] = try makeResult(allocator, "pkg/app.py");
    var analysis = try makeAnalysis(allocator, repo, results);
    defer analysis.deinit();
    analysis.historical_symbol_report = .{
        .candidate_path_count = 1,
        .retained_candidate_path_count = 1,
        .aggregate_record_bound = 0,
        .aggregate_record_bound_exceeded = false,
        .aggregates = try emptySlice(@import("historical_symbol_attribution.zig").AggregateRecord, allocator),
        .caveats = try emptySlice([]const u8, allocator),
    };

    try attach(allocator, io, &analysis, .{});
    const report = analysis.relation_report.?;
    try std.testing.expect(reportContainsCaveat(report, "current working-tree only"));
    for (report.providers) |file| try std.testing.expect(std.mem.startsWith(u8, file.provider.input.identity, "working-tree:"));
}

fn relationCandidateFixture(extra_caveats: []const []const u8) provider.RelationCandidate {
    return .{
        .kind = .reference,
        .direction = .source_to_target,
        .source = .{ .file = .{ .path = "pkg/app.py" } },
        .target = .{ .unresolved = .{ .value = "target" } },
        .evidence_basis = "fixture relation syntax",
        .provider = .{
            .name = "fixture-relation-provider",
            .kind = .relation,
            .version = "fixture",
            .input = .{ .identity = "working-tree:pkg/app.py" },
            .freshness = .fresh,
            .failure = .ok,
            .confidence = .medium,
            .caveats = &.{"provider caveat"},
            .provenance = .{ .provider_name = "fixture-relation-provider", .input_identity = "working-tree:pkg/app.py" },
        },
        .freshness = .fresh,
        .failure = .ok,
        .confidence = .medium,
        .caveats = extra_caveats,
        .order_key = .{ .path = "pkg/app.py", .start_byte = 0, .end_byte = 1, .relation = "reference", .target = "target" },
    };
}

fn containsCaveat(caveats: []const []const u8, needle: []const u8) !void {
    for (caveats) |caveat| if (std.mem.eql(u8, caveat, needle)) return;
    return error.MissingCaveat;
}
