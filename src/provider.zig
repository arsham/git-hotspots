const std = @import("std");

pub const contract_version = "provider-symbol-evidence-v1";

pub const PathError = error{InvalidRepoRelativePath};

pub const ProviderKind = enum {
    symbol,
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
