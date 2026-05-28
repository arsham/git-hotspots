const std = @import("std");

pub const contract_version = "provider-symbol-evidence-v1";

pub const PathError = error{InvalidRepoRelativePath};

pub const ProviderKind = enum {
    symbol,
    relation,
    dependency,
    @"test",
    coverage,
    language,
    other,
};

pub const Freshness = enum {
    fresh,
    stale,
    partial,
    unknown,
};

pub const Failure = enum {
    ok,
    unavailable,
    unsupported,
    failed,
    timed_out,
    skipped,
};

pub const Confidence = enum {
    high,
    medium,
    low,
    unknown,
};

pub const LocalInput = struct {
    /// Local repository HEAD, local input digest, or another bounded local id.
    identity: []const u8,
};

pub const HistoricalProviderInput = struct {
    /// Repo-relative path at the revision being parsed.
    path: []const u8,
    /// Local commit object id that supplied the revision-local blob.
    commit_id: []const u8,
    /// Local blob object id parsed without checking out the worktree.
    blob_id: []const u8,
};

pub const RevisionSymbolStatus = enum {
    current,
    historical,
    deleted,
    unknown,
};

pub const RevisionSymbolEvidence = struct {
    input: HistoricalProviderInput,
    name: []const u8,
    kind: SymbolKind,
    revision_range: LineRange,
    provider_name: []const u8,
    status: RevisionSymbolStatus,
    confidence: Confidence,
    caveats: []const []const u8 = &.{},
};

pub fn historicalIdentity(allocator: std.mem.Allocator, input: HistoricalProviderInput) ![]u8 {
    try validateRepoRelativePath(input.path);
    return std.fmt.allocPrint(allocator, "commit:{s}:blob:{s}:path:{s}", .{ input.commit_id, input.blob_id, input.path });
}

pub const ProviderEvidence = struct {
    name: []const u8,
    kind: ProviderKind,
    version: []const u8,
    contract_version: []const u8 = contract_version,
    config_fingerprint: ?[]const u8 = null,
    input: LocalInput,
    freshness: Freshness,
    failure: Failure,
    confidence: Confidence,
    caveats: []const []const u8 = &.{},
    provenance: LocalProvenance,
};

pub const LocalProvenance = struct {
    provider_name: []const u8,
    input_identity: []const u8,
};

pub const SymbolKind = enum {
    function,
    method,
    class,
    type,
    module,
    variable,
    other,
};

pub const CurrentRange = union(enum) {
    lines: LineRange,
    bytes: ByteRange,
};

pub const LineRange = struct {
    start: u32,
    end: u32,
};

pub const ByteRange = struct {
    start: u64,
    end: u64,
};

pub const CurrentSymbolEvidence = struct {
    path: []const u8,
    name: []const u8,
    kind: SymbolKind,
    current_range: CurrentRange,
    provider_name: []const u8,
    confidence: Confidence,
    caveats: []const []const u8 = &.{},
    current_line_history: ?CurrentLineHistoryEvidence = null,

    /// This seam models only current working-tree evidence. It deliberately has
    /// no lineage, ownership, dependency, snippet, or scoring fields.
    pub const semantics = "current-only";
};

pub const CurrentLineHistoryEvidence = struct {
    basis: []const u8 = "current-line-range-at-head",
    current_only: bool = true,
    line_count: u32,
    distinct_last_touch_commit_count: usize,
    most_recent_line_touched_timestamp: ?i64,
    uncommitted_or_unblamable_line_count: u32,
    sample_commits: [][]const u8,
    freshness: Freshness,
    failure: Failure,
    confidence: Confidence,
    caveats: [][]const u8,
};

pub const RelationKind = enum {
    contains,
    reference,
    call,
    import_include,
    unresolved,
    unknown,
};

pub const RelationDirection = enum {
    source_to_target,
    target_to_source,
    none,
};

pub const FileEndpoint = struct {
    path: []const u8,
};

pub const CurrentSymbolEndpoint = struct {
    path: []const u8,
    name: []const u8,
    kind: SymbolKind,
    current_range: CurrentRange,
};

pub const ReportSymbolEndpoint = struct {
    path: []const u8,
    name: []const u8,
    rank: ?usize = null,
};

pub const NamedRelationEndpoint = struct {
    value: []const u8,
};

pub const RelationEndpoint = union(enum) {
    file: FileEndpoint,
    current_symbol: CurrentSymbolEndpoint,
    report_symbol: ReportSymbolEndpoint,
    unresolved: NamedRelationEndpoint,
    external_string: NamedRelationEndpoint,
};

pub const RelationOrderKey = struct {
    path: []const u8,
    start_byte: u64,
    end_byte: u64,
    relation: []const u8,
    target: []const u8,
};

pub const RelationCandidate = struct {
    kind: RelationKind,
    direction: RelationDirection,
    source: RelationEndpoint,
    target: RelationEndpoint,
    evidence_basis: []const u8,
    provider: ProviderEvidence,
    freshness: Freshness,
    failure: Failure,
    confidence: Confidence,
    caveats: []const []const u8 = &.{},
    order_key: RelationOrderKey,
};

pub const RelationExtraction = struct {
    provider: ProviderEvidence,
    candidates: []RelationCandidate,
    cap_reached: bool = false,
    omitted_count: usize = 0,

    pub fn deinit(self: *RelationExtraction, allocator: std.mem.Allocator) void {
        freeRelationProvider(allocator, self.provider);
        freeRelationCandidates(allocator, self.candidates);
        self.* = undefined;
    }
};

pub fn freeRelationProvider(allocator: std.mem.Allocator, evidence: ProviderEvidence) void {
    allocator.free(evidence.input.identity);
}

pub fn freeRelationCandidates(allocator: std.mem.Allocator, candidates: []RelationCandidate) void {
    for (candidates) |candidate| freeRelationCandidate(allocator, candidate);
    if (candidates.len > 0) allocator.free(candidates);
}

pub fn freeRelationCandidate(allocator: std.mem.Allocator, candidate: RelationCandidate) void {
    freeRelationEndpoint(allocator, candidate.source);
    freeRelationEndpoint(allocator, candidate.target);
    allocator.free(candidate.evidence_basis);
    freeRelationProvider(allocator, candidate.provider);
    allocator.free(candidate.order_key.path);
    allocator.free(candidate.order_key.relation);
    allocator.free(candidate.order_key.target);
}

pub fn freeRelationEndpoint(allocator: std.mem.Allocator, endpoint: RelationEndpoint) void {
    switch (endpoint) {
        .file => |file| allocator.free(file.path),
        .current_symbol => |symbol| {
            allocator.free(symbol.path);
            allocator.free(symbol.name);
        },
        .report_symbol => |symbol| {
            allocator.free(symbol.path);
            allocator.free(symbol.name);
        },
        .unresolved, .external_string => |named| allocator.free(named.value),
    }
}

pub fn validateRelationEndpoint(endpoint: RelationEndpoint) PathError!void {
    switch (endpoint) {
        .file => |file| try validateRepoRelativePath(file.path),
        .current_symbol => |symbol| try validateRepoRelativePath(symbol.path),
        .report_symbol => |symbol| try validateRepoRelativePath(symbol.path),
        .unresolved, .external_string => {},
    }
}

pub fn lessRelation(_: void, lhs: RelationCandidate, rhs: RelationCandidate) bool {
    return compareRelation(lhs, rhs) == .lt;
}

pub fn validateRepoRelativePath(path: []const u8) PathError!void {
    if (path.len == 0) return error.InvalidRepoRelativePath;
    if (std.fs.path.isAbsolute(path) or path[0] == '\\') return error.InvalidRepoRelativePath;
    if (path.len >= 2 and std.ascii.isAlphabetic(path[0]) and path[1] == ':') return error.InvalidRepoRelativePath;
    for (path) |c| if (c < 0x20 or c == 0x7f) return error.InvalidRepoRelativePath;

    var segments = std.mem.splitScalar(u8, path, '/');
    while (segments.next()) |segment| {
        if (std.mem.eql(u8, segment, "..")) return error.InvalidRepoRelativePath;
    }
}

pub fn lessProvider(_: void, lhs: ProviderEvidence, rhs: ProviderEvidence) bool {
    return compareProvider(lhs, rhs) == .lt;
}

pub fn lessSymbol(_: void, lhs: CurrentSymbolEvidence, rhs: CurrentSymbolEvidence) bool {
    return compareSymbol(lhs, rhs) == .lt;
}

pub fn lessText(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.order(u8, lhs, rhs) == .lt;
}

fn compareProvider(lhs: ProviderEvidence, rhs: ProviderEvidence) std.math.Order {
    inline for (.{
        std.mem.order(u8, lhs.name, rhs.name),
        std.mem.order(u8, @tagName(lhs.kind), @tagName(rhs.kind)),
        std.mem.order(u8, lhs.version, rhs.version),
        std.mem.order(u8, lhs.contract_version, rhs.contract_version),
    }) |order| {
        if (order != .eq) return order;
    }
    return .eq;
}

fn compareSymbol(lhs: CurrentSymbolEvidence, rhs: CurrentSymbolEvidence) std.math.Order {
    inline for (.{
        std.mem.order(u8, lhs.path, rhs.path),
        std.mem.order(u8, lhs.name, rhs.name),
        std.mem.order(u8, @tagName(lhs.kind), @tagName(rhs.kind)),
        compareRange(lhs.current_range, rhs.current_range),
        std.mem.order(u8, lhs.provider_name, rhs.provider_name),
    }) |order| {
        if (order != .eq) return order;
    }
    return .eq;
}

fn compareRelation(lhs: RelationCandidate, rhs: RelationCandidate) std.math.Order {
    inline for (.{
        std.mem.order(u8, lhs.order_key.path, rhs.order_key.path),
        compareU64(lhs.order_key.start_byte, rhs.order_key.start_byte) orelse .eq,
        compareU64(lhs.order_key.end_byte, rhs.order_key.end_byte) orelse .eq,
        std.mem.order(u8, lhs.order_key.relation, rhs.order_key.relation),
        std.mem.order(u8, lhs.order_key.target, rhs.order_key.target),
        std.mem.order(u8, @tagName(lhs.kind), @tagName(rhs.kind)),
        std.mem.order(u8, @tagName(lhs.direction), @tagName(rhs.direction)),
        compareEndpoint(lhs.source, rhs.source),
        compareEndpoint(lhs.target, rhs.target),
    }) |order| {
        if (order != .eq) return order;
    }
    return .eq;
}

fn compareEndpoint(lhs: RelationEndpoint, rhs: RelationEndpoint) std.math.Order {
    const tag_order = std.mem.order(u8, @tagName(lhs), @tagName(rhs));
    if (tag_order != .eq) return tag_order;
    return switch (lhs) {
        .file => |lhs_file| std.mem.order(u8, lhs_file.path, switch (rhs) {
            .file => |rhs_file| rhs_file.path,
            else => unreachable,
        }),
        .current_symbol => |lhs_symbol| compareCurrentSymbolEndpoint(lhs_symbol, switch (rhs) {
            .current_symbol => |rhs_symbol| rhs_symbol,
            else => unreachable,
        }),
        .report_symbol => |lhs_symbol| compareReportSymbolEndpoint(lhs_symbol, switch (rhs) {
            .report_symbol => |rhs_symbol| rhs_symbol,
            else => unreachable,
        }),
        .unresolved => |lhs_named| std.mem.order(u8, lhs_named.value, switch (rhs) {
            .unresolved => |rhs_named| rhs_named.value,
            else => unreachable,
        }),
        .external_string => |lhs_named| std.mem.order(u8, lhs_named.value, switch (rhs) {
            .external_string => |rhs_named| rhs_named.value,
            else => unreachable,
        }),
    };
}

fn compareCurrentSymbolEndpoint(lhs: CurrentSymbolEndpoint, rhs: CurrentSymbolEndpoint) std.math.Order {
    inline for (.{
        std.mem.order(u8, lhs.path, rhs.path),
        std.mem.order(u8, lhs.name, rhs.name),
        std.mem.order(u8, @tagName(lhs.kind), @tagName(rhs.kind)),
        compareRange(lhs.current_range, rhs.current_range),
    }) |order| {
        if (order != .eq) return order;
    }
    return .eq;
}

fn compareReportSymbolEndpoint(lhs: ReportSymbolEndpoint, rhs: ReportSymbolEndpoint) std.math.Order {
    inline for (.{
        std.mem.order(u8, lhs.path, rhs.path),
        std.mem.order(u8, lhs.name, rhs.name),
        compareOptionalUsize(lhs.rank, rhs.rank),
    }) |order| {
        if (order != .eq) return order;
    }
    return .eq;
}

fn compareRange(lhs: CurrentRange, rhs: CurrentRange) std.math.Order {
    const lhs_tag = @tagName(lhs);
    const rhs_tag = @tagName(rhs);
    const tag_order = std.mem.order(u8, lhs_tag, rhs_tag);
    if (tag_order != .eq) return tag_order;
    return switch (lhs) {
        .lines => |lhs_lines| compareU64(lhs_lines.start, switch (rhs) {
            .lines => |r| r.start,
            else => unreachable,
        }) orelse
            (compareU64(lhs_lines.end, switch (rhs) {
                .lines => |r| r.end,
                else => unreachable,
            }) orelse .eq),
        .bytes => |lhs_bytes| compareU64(lhs_bytes.start, switch (rhs) {
            .bytes => |r| r.start,
            else => unreachable,
        }) orelse
            (compareU64(lhs_bytes.end, switch (rhs) {
                .bytes => |r| r.end,
                else => unreachable,
            }) orelse .eq),
    };
}

fn compareOptionalUsize(lhs: ?usize, rhs: ?usize) std.math.Order {
    if (lhs == null and rhs == null) return .eq;
    if (lhs == null) return .lt;
    if (rhs == null) return .gt;
    return compareU64(lhs.?, rhs.?) orelse .eq;
}

fn compareU64(lhs: u64, rhs: u64) ?std.math.Order {
    if (lhs < rhs) return .lt;
    if (lhs > rhs) return .gt;
    return null;
}

fn providerFixture(name: []const u8, kind: ProviderKind, freshness: Freshness, failure: Failure, confidence: Confidence) ProviderEvidence {
    return .{
        .name = name,
        .kind = kind,
        .version = "synthetic-1",
        .config_fingerprint = "local-config-digest",
        .input = .{ .identity = "HEAD:synthetic" },
        .freshness = freshness,
        .failure = failure,
        .confidence = confidence,
        .caveats = &.{ "synthetic", "current working tree only" },
        .provenance = .{ .provider_name = name, .input_identity = "HEAD:synthetic" },
    };
}

test "provider evidence model carries required local-only states" {
    const provider = providerFixture("tree-sitter", .symbol, .fresh, .ok, .high);
    try std.testing.expectEqualStrings("tree-sitter", provider.name);
    try std.testing.expectEqual(ProviderKind.symbol, provider.kind);
    try std.testing.expectEqualStrings("synthetic-1", provider.version);
    try std.testing.expectEqualStrings(contract_version, provider.contract_version);
    try std.testing.expectEqualStrings("local-config-digest", provider.config_fingerprint.?);
    try std.testing.expectEqualStrings("HEAD:synthetic", provider.input.identity);
    try std.testing.expectEqual(Freshness.fresh, provider.freshness);
    try std.testing.expectEqual(Failure.ok, provider.failure);
    try std.testing.expectEqual(Confidence.high, provider.confidence);
    try std.testing.expectEqual(@as(usize, 2), provider.caveats.len);
    try std.testing.expectEqualStrings(provider.name, provider.provenance.provider_name);
    try std.testing.expectEqualStrings(provider.input.identity, provider.provenance.input_identity);

    inline for (.{ .fresh, .stale, .partial, .unknown }) |state| {
        const with_state = providerFixture("state", .symbol, state, .ok, .medium);
        try std.testing.expectEqual(state, with_state.freshness);
    }
    inline for (.{ .ok, .unavailable, .unsupported, .failed, .timed_out, .skipped }) |state| {
        const with_state = providerFixture("state", .symbol, .unknown, state, .low);
        try std.testing.expectEqual(state, with_state.failure);
    }
    inline for (.{ .high, .medium, .low, .unknown }) |state| {
        const with_state = providerFixture("state", .symbol, .unknown, .skipped, state);
        try std.testing.expectEqual(state, with_state.confidence);
    }
}

test "provider and symbol ordering is deterministic" {
    var providers = [_]ProviderEvidence{
        providerFixture("lsp", .symbol, .unknown, .skipped, .low),
        providerFixture("tree-sitter", .symbol, .fresh, .ok, .high),
        providerFixture("coverage", .coverage, .partial, .failed, .low),
    };
    std.mem.sort(ProviderEvidence, &providers, {}, lessProvider);
    try std.testing.expectEqualStrings("coverage", providers[0].name);
    try std.testing.expectEqualStrings("lsp", providers[1].name);
    try std.testing.expectEqualStrings("tree-sitter", providers[2].name);

    var symbols = [_]CurrentSymbolEvidence{
        .{ .path = "src/main.zig", .name = "main", .kind = .function, .current_range = .{ .lines = .{ .start = 10, .end = 20 } }, .provider_name = "tree-sitter", .confidence = .high },
        .{ .path = "src/provider.zig", .name = "ProviderEvidence", .kind = .type, .current_range = .{ .lines = .{ .start = 1, .end = 30 } }, .provider_name = "tree-sitter", .confidence = .high },
        .{ .path = "src/main.zig", .name = "parseArgs", .kind = .function, .current_range = .{ .lines = .{ .start = 30, .end = 60 } }, .provider_name = "tree-sitter", .confidence = .medium },
    };
    std.mem.sort(CurrentSymbolEvidence, &symbols, {}, lessSymbol);
    try std.testing.expectEqualStrings("src/main.zig", symbols[0].path);
    try std.testing.expectEqualStrings("main", symbols[0].name);
    try std.testing.expectEqualStrings("parseArgs", symbols[1].name);
    try std.testing.expectEqualStrings("src/provider.zig", symbols[2].path);
}

fn relationProviderFixture(input_identity: []const u8) ProviderEvidence {
    return .{
        .name = "tree-sitter-python-relations",
        .kind = .relation,
        .version = "synthetic-relation-1",
        .input = .{ .identity = input_identity },
        .freshness = .fresh,
        .failure = .ok,
        .confidence = .medium,
        .caveats = &.{ "candidate relation evidence only", "not used for scoring or ranking" },
        .provenance = .{ .provider_name = "tree-sitter-python-relations", .input_identity = input_identity },
    };
}

fn relationFixture(kind: RelationKind, start_byte: u64, target: RelationEndpoint, target_key: []const u8) RelationCandidate {
    return .{
        .kind = kind,
        .direction = .source_to_target,
        .source = .{ .file = .{ .path = "pkg/example.py" } },
        .target = target,
        .evidence_basis = "synthetic Tree-sitter relation proof",
        .provider = relationProviderFixture("working-tree:pkg/example.py"),
        .freshness = .fresh,
        .failure = .ok,
        .confidence = .medium,
        .caveats = &.{ "candidate relation evidence only", "target mappings are unresolved unless syntactically local" },
        .order_key = .{
            .path = "pkg/example.py",
            .start_byte = start_byte,
            .end_byte = start_byte + 1,
            .relation = @tagName(kind),
            .target = target_key,
        },
    };
}

test "relation model represents provider-neutral endpoints and caveated states" {
    const relation = relationFixture(
        .call,
        42,
        .{ .unresolved = .{ .value = "missing_helper" } },
        "missing_helper",
    );

    try validateRelationEndpoint(relation.source);
    try validateRelationEndpoint(relation.target);
    try std.testing.expectEqual(RelationKind.call, relation.kind);
    try std.testing.expectEqual(RelationDirection.source_to_target, relation.direction);
    try std.testing.expectEqual(ProviderKind.relation, relation.provider.kind);
    try std.testing.expectEqual(Freshness.fresh, relation.freshness);
    try std.testing.expectEqual(Failure.ok, relation.failure);
    try std.testing.expectEqual(Confidence.medium, relation.confidence);
    try std.testing.expectEqualStrings("call", relation.order_key.relation);
    try std.testing.expectEqualStrings("missing_helper", relation.order_key.target);
    switch (relation.target) {
        .unresolved => |endpoint| try std.testing.expectEqualStrings("missing_helper", endpoint.value),
        else => return error.ExpectedUnresolvedEndpoint,
    }

    const endpoints = [_]RelationEndpoint{
        .{ .file = .{ .path = "pkg/example.py" } },
        .{ .current_symbol = .{ .path = "pkg/example.py", .name = "helper", .kind = .function, .current_range = .{ .lines = .{ .start = 1, .end = 2 } } } },
        .{ .report_symbol = .{ .path = "pkg/example.py", .name = "reported", .rank = 7 } },
        .{ .unresolved = .{ .value = "missing_helper" } },
        .{ .external_string = .{ .value = "package.module" } },
    };
    for (endpoints) |endpoint| try validateRelationEndpoint(endpoint);
}

test "relation candidate ordering is deterministic" {
    var relations = [_]RelationCandidate{
        relationFixture(.reference, 30, .{ .current_symbol = .{ .path = "pkg/example.py", .name = "helper", .kind = .function, .current_range = .{ .lines = .{ .start = 1, .end = 2 } } } }, "helper"),
        relationFixture(.contains, 10, .{ .current_symbol = .{ .path = "pkg/example.py", .name = "Container", .kind = .class, .current_range = .{ .lines = .{ .start = 3, .end = 8 } } } }, "Container"),
        relationFixture(.import_include, 20, .{ .external_string = .{ .value = "os.path" } }, "os.path"),
    };

    std.mem.sort(RelationCandidate, &relations, {}, lessRelation);
    try std.testing.expectEqual(RelationKind.contains, relations[0].kind);
    try std.testing.expectEqual(RelationKind.import_include, relations[1].kind);
    try std.testing.expectEqual(RelationKind.reference, relations[2].kind);
}

test "repo-relative path validation rejects unsafe paths but allows bounded metadata" {
    const valid = [_][]const u8{
        "src/main.zig",
        "docs/path with spaces.md",
        "unicode/☃.zig",
        "escaped/tab\\tname.zig",
        "markdown/[link]*#?.zig",
    };
    for (valid) |path| try validateRepoRelativePath(path);

    const invalid = [_][]const u8{
        "",
        "/tmp/private.zig",
        "C:/tmp/private.zig",
        "\\server\\share",
        "../src/main.zig",
        "src/../main.zig",
        "bad\npath.zig",
        "bad\tpath.zig",
        "bad\x7fpath.zig",
    };
    for (invalid) |path| try std.testing.expectError(error.InvalidRepoRelativePath, validateRepoRelativePath(path));
}

test "current symbol evidence is current-only and has no snippet or private path fields" {
    const symbol = CurrentSymbolEvidence{
        .path = "src/main.zig",
        .name = "parseArgs",
        .kind = .function,
        .current_range = .{ .lines = .{ .start = 158, .end = 275 } },
        .provider_name = "tree-sitter",
        .confidence = .medium,
        .caveats = &.{ "synthetic in-memory evidence", CurrentSymbolEvidence.semantics },
    };
    try validateRepoRelativePath(symbol.path);
    try std.testing.expectEqualStrings("current-only", CurrentSymbolEvidence.semantics);
    try std.testing.expectEqual(@as(usize, 2), symbol.caveats.len);
    try std.testing.expectEqualStrings("synthetic in-memory evidence", symbol.caveats[0]);
    try std.testing.expectEqualStrings("current-only", symbol.caveats[1]);

    const fields = @typeInfo(CurrentSymbolEvidence).@"struct".fields;
    inline for (fields) |field| {
        try std.testing.expect(!std.mem.eql(u8, field.name, "source"));
        try std.testing.expect(!std.mem.eql(u8, field.name, "snippet"));
        try std.testing.expect(!std.mem.eql(u8, field.name, "absolute_path"));
        try std.testing.expect(!std.mem.eql(u8, field.name, "author"));
        try std.testing.expect(!std.mem.eql(u8, field.name, "lineage"));
    }
}

test "caveat order is explicit and sortable when callers need stable output" {
    const caveats = [_][]const u8{ "stale", "unsupported language", "current working tree only" };
    const symbol = CurrentSymbolEvidence{
        .path = "src/provider.zig",
        .name = "CurrentSymbolEvidence",
        .kind = .type,
        .current_range = .{ .bytes = .{ .start = 100, .end = 200 } },
        .provider_name = "synthetic",
        .confidence = .unknown,
        .caveats = &caveats,
    };
    try std.testing.expectEqualStrings("stale", symbol.caveats[0]);
    try std.testing.expectEqualStrings("unsupported language", symbol.caveats[1]);
    try std.testing.expectEqualStrings("current working tree only", symbol.caveats[2]);

    var sorted = caveats;
    std.mem.sort([]const u8, &sorted, {}, lessText);
    try std.testing.expectEqualStrings("current working tree only", sorted[0]);
    try std.testing.expectEqualStrings("stale", sorted[1]);
    try std.testing.expectEqualStrings("unsupported language", sorted[2]);
}
