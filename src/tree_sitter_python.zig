const std = @import("std");
const provider = @import("provider.zig");
const tree_sitter_common = @import("tree_sitter_common.zig");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_python() *const c.TSLanguage;

pub const provider_name = "tree-sitter-python";
pub const provider_version = "tree-sitter-core@v0.26.9/tree-sitter-python@v0.25.0/python-symbol-query-v1";
pub const relation_provider_name = "tree-sitter-python-relations";
pub const relation_provider_version = "tree-sitter-core@v0.26.9/tree-sitter-python@v0.25.0/python-relation-proof-v1";
const max_file_bytes: u64 = 1024 * 1024;
const query_source = @embedFile("queries/python-symbols.scm");

const ok_caveats = [_][]const u8{
    "current working-tree enrichment only; file-level Git evidence remains product truth",
    "supported subset: module roots, class and function definitions, direct class methods, nested definitions, and module-level simple assignments",
    "range convention: one-based inclusive lines; decorated definitions include decorators",
    "provider order: module symbol first, then deterministic source order by symbol node start byte",
    "module names are repo-relative .py paths; qualified Python names, imports, package discovery, virtualenvs, notebooks, and LSP analysis are out of scope",
    "dynamic assignments, tuple/list destructuring, dependency graphs, generated-source policy, scoring, and symbol or function moves are out of scope",
};
const unsupported_caveats = [_][]const u8{
    "provider unsupported: only repo-relative .py files are parsed",
    "no parser diagnostics or source snippets exposed",
};
const unavailable_caveats = [_][]const u8{
    "current working-tree file unavailable or not a regular bounded file",
    "no parser diagnostics, source snippets, absolute paths, remotes, author identities, commit messages, or private repo names exposed",
};
const failed_caveats = [_][]const u8{
    "provider failed to parse supported Python symbol evidence",
    "invalid or partial Python source failed closed without parser diagnostics or source snippets",
};
const method_caveats = ok_caveats ++ [_][]const u8{
    "method classification is derived from a direct enclosing class block; method names are bare identifiers",
};
const const_caveats = ok_caveats ++ [_][]const u8{
    "constant-like uppercase module assignments map to provider SymbolKind.other because no constant-specific kind exists",
};
const variable_caveats = ok_caveats ++ [_][]const u8{
    "module-level simple assignments map to provider SymbolKind.variable",
};
const generated_caveats = ok_caveats ++ [_][]const u8{
    "generated-file markers are caveated only; generated-source policy is not evaluated by this provider",
};
const relation_ok_caveats = [_][]const u8{
    "candidate relation evidence only; file-level Git evidence remains product truth",
    "bounded Python syntax proof: contains, local direct identifier references, direct calls, imports, unresolved identifiers, and ambiguous attribute syntax",
    "unresolved and external-string endpoints are caveated; no local target mapping is fabricated",
    "symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction",
};
const relation_unresolved_caveats = relation_ok_caveats ++ [_][]const u8{
    "target is unresolved by this bounded syntax proof",
};
const relation_import_caveats = relation_ok_caveats ++ [_][]const u8{
    "import target is an external string; local module resolution is out of scope",
};
const relation_unknown_caveats = relation_ok_caveats ++ [_][]const u8{
    "relation-like syntax is present but cannot be classified safely by this proof",
};
const relation_cap_caveats = relation_ok_caveats ++ [_][]const u8{
    "relation candidate cap reached; emitted evidence is partial and deterministically truncated",
};
const relation_unsupported_caveats = [_][]const u8{
    "relation provider unsupported: only repo-relative .py files are parsed",
    "no parser diagnostics or source snippets exposed",
};
const relation_unavailable_caveats = [_][]const u8{
    "relation provider unavailable or current working-tree source was not available to the bounded proof",
    "no parser diagnostics, source snippets, absolute paths, remotes, author identities, commit messages, or private repo names exposed",
};
const relation_oversized_caveats = [_][]const u8{
    "relation source skipped by bounded-size policy",
    "no source snippets or private path details exposed",
};
const relation_failed_caveats = [_][]const u8{
    "relation provider failed to parse supported Python source",
    "invalid or partial Python source failed closed without parser diagnostics or source snippets",
};

pub const Extraction = tree_sitter_common.Extraction;
pub const max_relation_candidates: usize = 64;

pub const RelationOptions = struct {
    max_source_bytes: u64 = max_file_bytes,
    max_candidates: usize = max_relation_candidates,
    force_provider_unavailable: bool = false,
};

pub const RelationExtraction = struct {
    provider: provider.ProviderEvidence,
    candidates: []provider.RelationCandidate,
    cap_reached: bool = false,
    omitted_count: usize = 0,

    pub fn deinit(self: *RelationExtraction, allocator: std.mem.Allocator) void {
        freeRelationProvider(allocator, self.provider);
        freeRelationCandidates(allocator, self.candidates);
        self.* = undefined;
    }
};
const DefinitionKind = enum {
    class,
    function,
    assignment,
};

const CaveatKind = enum {
    module,
    class,
    function,
    method,
    constant,
    variable,
};

const SymbolCandidate = struct {
    start_byte: u32,
    end_byte: u32,
    symbol: provider.CurrentSymbolEvidence,
};

const DefinitionRecord = struct {
    start_byte: u32,
    end_byte: u32,
    name_start_byte: u32,
    name_end_byte: u32,
    name: []const u8,
    kind: provider.SymbolKind,
    range: provider.CurrentRange,
};

const RelationBuildState = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    source: []const u8,
    definitions: []const DefinitionRecord,
    candidates: std.ArrayList(provider.RelationCandidate),
    max_candidates: usize,
    cap_reached: bool = false,
    omitted_count: usize = 0,

    fn deinit(self: *RelationBuildState) void {
        for (self.candidates.items) |candidate| freeRelationCandidate(self.allocator, candidate);
        self.candidates.deinit(self.allocator);
    }
};

const NamedEndpointTag = enum { unresolved, external_string };

pub fn extractPath(allocator: std.mem.Allocator, io: std.Io, repo_root: []const u8, repo_relative_path: []const u8) !Extraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!std.mem.endsWith(u8, repo_relative_path, ".py")) {
        return extraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &unsupported_caveats, &.{});
    }

    const source = try tree_sitter_common.readBoundedFile(allocator, io, repo_root, repo_relative_path, max_file_bytes) orelse return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    defer allocator.free(source);

    return extractSource(allocator, repo_relative_path, source);
}

pub fn extractSource(allocator: std.mem.Allocator, repo_relative_path: []const u8, source: []const u8) !Extraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!std.mem.endsWith(u8, repo_relative_path, ".py")) {
        return extraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &unsupported_caveats, &.{});
    }

    const parser = c.ts_parser_new() orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_python())) return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});

    const source_len = std.math.cast(u32, source.len) orelse return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});

    const query = compilePythonQuery() catch return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_query_delete(query);

    const cursor = c.ts_query_cursor_new() orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_query_cursor_delete(cursor);

    var candidates: std.ArrayList(SymbolCandidate) = .empty;
    defer candidates.deinit(allocator);
    errdefer tree_sitter_common.freeCandidateSymbols(allocator, candidates.items);

    const generated = hasGeneratedMarker(source);

    c.ts_query_cursor_exec(cursor, query, root);
    var match: c.TSQueryMatch = undefined;
    while (c.ts_query_cursor_next_match(cursor, &match)) {
        var definition_node: c.TSNode = undefined;
        var definition_kind: ?DefinitionKind = null;
        var name_node: c.TSNode = undefined;
        var has_name = false;

        var capture_index: usize = 0;
        while (capture_index < match.capture_count) : (capture_index += 1) {
            const capture = match.captures[capture_index];
            const name = queryCaptureName(query, capture.index);
            if (std.mem.eql(u8, name, "python.module")) {
                try appendCandidate(
                    allocator,
                    &candidates,
                    repo_relative_path,
                    repo_relative_path,
                    .module,
                    capture.node,
                    capture.node,
                    caveatsForModule(generated),
                );
            } else if (std.mem.eql(u8, name, "python.class.definition")) {
                definition_node = capture.node;
                definition_kind = .class;
            } else if (std.mem.eql(u8, name, "python.function.definition")) {
                definition_node = capture.node;
                definition_kind = .function;
            } else if (std.mem.eql(u8, name, "python.assignment.definition")) {
                definition_node = capture.node;
                definition_kind = .assignment;
            } else if (std.mem.eql(u8, name, "python.definition.name")) {
                name_node = capture.node;
                has_name = true;
            }
        }

        if (definition_kind) |kind| {
            if (!has_name) continue;
            try appendDefinitionCandidate(allocator, &candidates, repo_relative_path, source, definition_node, name_node, kind, generated);
        }
    }

    std.mem.sort(SymbolCandidate, candidates.items, {}, lessCandidate);

    const symbols = try allocator.alloc(provider.CurrentSymbolEvidence, candidates.items.len);
    var symbols_owned = true;
    errdefer if (symbols_owned) allocator.free(symbols);
    for (candidates.items, 0..) |candidate, i| symbols[i] = candidate.symbol;
    candidates.clearRetainingCapacity();

    symbols_owned = false;
    return extraction(allocator, repo_relative_path, .ok, .fresh, .high, caveatsForModule(generated), symbols);
}

pub fn extractRelationsSource(allocator: std.mem.Allocator, repo_relative_path: []const u8, source: []const u8, options: RelationOptions) !RelationExtraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (options.force_provider_unavailable) {
        return relationExtraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &relation_unavailable_caveats, false, 0, &.{});
    }
    if (!std.mem.endsWith(u8, repo_relative_path, ".py")) {
        return relationExtraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &relation_unsupported_caveats, false, 0, &.{});
    }
    if (source.len > options.max_source_bytes) {
        return relationExtraction(allocator, repo_relative_path, .skipped, .unknown, .unknown, &relation_oversized_caveats, false, 0, &.{});
    }

    const parser = c.ts_parser_new() orelse return relationExtraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &relation_unavailable_caveats, false, 0, &.{});
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_python())) return relationExtraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &relation_unavailable_caveats, false, 0, &.{});

    const source_len = std.math.cast(u32, source.len) orelse return relationExtraction(allocator, repo_relative_path, .skipped, .unknown, .unknown, &relation_oversized_caveats, false, 0, &.{});
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});

    const query = compilePythonQuery() catch return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});
    defer c.ts_query_delete(query);

    const cursor = c.ts_query_cursor_new() orelse return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});
    defer c.ts_query_cursor_delete(cursor);

    var definitions: std.ArrayList(DefinitionRecord) = .empty;
    defer definitions.deinit(allocator);

    c.ts_query_cursor_exec(cursor, query, root);
    var match: c.TSQueryMatch = undefined;
    while (c.ts_query_cursor_next_match(cursor, &match)) {
        var definition_node: c.TSNode = undefined;
        var definition_kind: ?DefinitionKind = null;
        var name_node: c.TSNode = undefined;
        var has_name = false;

        var capture_index: usize = 0;
        while (capture_index < match.capture_count) : (capture_index += 1) {
            const capture = match.captures[capture_index];
            const name = queryCaptureName(query, capture.index);
            if (std.mem.eql(u8, name, "python.class.definition")) {
                definition_node = capture.node;
                definition_kind = .class;
            } else if (std.mem.eql(u8, name, "python.function.definition")) {
                definition_node = capture.node;
                definition_kind = .function;
            } else if (std.mem.eql(u8, name, "python.assignment.definition")) {
                definition_node = capture.node;
                definition_kind = .assignment;
            } else if (std.mem.eql(u8, name, "python.definition.name")) {
                name_node = capture.node;
                has_name = true;
            }
        }

        if (definition_kind) |kind| {
            if (!has_name) continue;
            try appendDefinitionRecord(allocator, &definitions, source, definition_node, name_node, kind);
        }
    }
    std.mem.sort(DefinitionRecord, definitions.items, {}, lessDefinitionRecord);

    var state = RelationBuildState{
        .allocator = allocator,
        .path = repo_relative_path,
        .source = source,
        .definitions = definitions.items,
        .candidates = .empty,
        .max_candidates = options.max_candidates,
    };
    errdefer state.deinit();

    try appendContainmentRelations(&state);
    try walkRelationSyntax(&state, root);
    std.mem.sort(provider.RelationCandidate, state.candidates.items, {}, provider.lessRelation);

    const candidates = try state.candidates.toOwnedSlice(allocator);
    const cap_reached = state.cap_reached;
    const omitted_count = state.omitted_count;
    const caveats = if (cap_reached) &relation_cap_caveats else &relation_ok_caveats;
    return relationExtraction(allocator, repo_relative_path, .ok, if (cap_reached) .partial else .fresh, if (cap_reached) .low else .medium, caveats, cap_reached, omitted_count, candidates);
}

fn extraction(
    allocator: std.mem.Allocator,
    repo_relative_path: []const u8,
    failure: provider.Failure,
    freshness: provider.Freshness,
    confidence: provider.Confidence,
    caveats: []const []const u8,
    symbols: []provider.CurrentSymbolEvidence,
) !Extraction {
    return tree_sitter_common.makeExtraction(allocator, provider_name, provider_version, repo_relative_path, failure, freshness, confidence, caveats, symbols);
}

fn relationExtraction(
    allocator: std.mem.Allocator,
    repo_relative_path: []const u8,
    failure: provider.Failure,
    freshness: provider.Freshness,
    confidence: provider.Confidence,
    caveats: []const []const u8,
    cap_reached: bool,
    omitted_count: usize,
    candidates: []provider.RelationCandidate,
) !RelationExtraction {
    errdefer freeRelationCandidates(allocator, candidates);
    return .{
        .provider = try makeRelationProvider(allocator, repo_relative_path, failure, freshness, confidence, caveats),
        .candidates = candidates,
        .cap_reached = cap_reached,
        .omitted_count = omitted_count,
    };
}

fn makeRelationProvider(
    allocator: std.mem.Allocator,
    repo_relative_path: []const u8,
    failure: provider.Failure,
    freshness: provider.Freshness,
    confidence: provider.Confidence,
    caveats: []const []const u8,
) !provider.ProviderEvidence {
    const identity = try std.fmt.allocPrint(allocator, "working-tree:{s}", .{repo_relative_path});
    return .{
        .name = relation_provider_name,
        .kind = .relation,
        .version = relation_provider_version,
        .input = .{ .identity = identity },
        .freshness = freshness,
        .failure = failure,
        .confidence = confidence,
        .caveats = caveats,
        .provenance = .{ .provider_name = relation_provider_name, .input_identity = identity },
    };
}

fn freeRelationProvider(allocator: std.mem.Allocator, evidence: provider.ProviderEvidence) void {
    allocator.free(evidence.input.identity);
}

fn freeRelationCandidates(allocator: std.mem.Allocator, candidates: []provider.RelationCandidate) void {
    for (candidates) |candidate| freeRelationCandidate(allocator, candidate);
    if (candidates.len > 0) allocator.free(candidates);
}

fn freeRelationCandidate(allocator: std.mem.Allocator, candidate: provider.RelationCandidate) void {
    freeRelationEndpoint(allocator, candidate.source);
    freeRelationEndpoint(allocator, candidate.target);
    allocator.free(candidate.evidence_basis);
    freeRelationProvider(allocator, candidate.provider);
    allocator.free(candidate.order_key.path);
    allocator.free(candidate.order_key.relation);
    allocator.free(candidate.order_key.target);
}

fn freeRelationEndpoint(allocator: std.mem.Allocator, endpoint: provider.RelationEndpoint) void {
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

fn appendDefinitionRecord(
    allocator: std.mem.Allocator,
    definitions: *std.ArrayList(DefinitionRecord),
    source: []const u8,
    definition_node: c.TSNode,
    name_node: c.TSNode,
    kind: DefinitionKind,
) !void {
    const symbol_name = nodeSourceSlice(source, name_node) orelse return;
    switch (kind) {
        .class => try appendDefinitionRecordUnchecked(allocator, definitions, symbol_name, .class, name_node, rangeNode(definition_node)),
        .function => {
            const symbol_kind: provider.SymbolKind = if (isDirectClassBodyDefinition(definition_node)) .method else .function;
            try appendDefinitionRecordUnchecked(allocator, definitions, symbol_name, symbol_kind, name_node, rangeNode(definition_node));
        },
        .assignment => {
            if (!isModuleLevelDefinition(definition_node)) return;
            const symbol_kind: provider.SymbolKind = if (isConstantLikeName(symbol_name)) .other else .variable;
            try appendDefinitionRecordUnchecked(allocator, definitions, symbol_name, symbol_kind, name_node, definition_node);
        },
    }
}

fn appendDefinitionRecordUnchecked(
    allocator: std.mem.Allocator,
    definitions: *std.ArrayList(DefinitionRecord),
    symbol_name: []const u8,
    kind: provider.SymbolKind,
    name_node: c.TSNode,
    range_node: c.TSNode,
) !void {
    try definitions.append(allocator, .{
        .start_byte = c.ts_node_start_byte(range_node),
        .end_byte = c.ts_node_end_byte(range_node),
        .name_start_byte = c.ts_node_start_byte(name_node),
        .name_end_byte = c.ts_node_end_byte(name_node),
        .name = symbol_name,
        .kind = kind,
        .range = .{ .lines = nodeLineRange(range_node) },
    });
}

fn appendContainmentRelations(state: *RelationBuildState) !void {
    for (state.definitions, 0..) |definition, i| {
        const source_endpoint = if (containingDefinitionIndex(state.definitions, definition.start_byte, definition.end_byte, i)) |parent_index|
            try makeCurrentSymbolEndpoint(state.allocator, state.path, state.definitions[parent_index])
        else
            try makeFileEndpoint(state.allocator, state.path);
        errdefer freeRelationEndpoint(state.allocator, source_endpoint);

        const target_endpoint = try makeCurrentSymbolEndpoint(state.allocator, state.path, definition);
        errdefer freeRelationEndpoint(state.allocator, target_endpoint);

        try appendRelationOwned(
            state,
            .contains,
            .source_to_target,
            source_endpoint,
            target_endpoint,
            "python definition containment",
            definition.start_byte,
            definition.end_byte,
            &relation_ok_caveats,
            .medium,
        );
    }
}

fn walkRelationSyntax(state: *RelationBuildState, node: c.TSNode) !void {
    if (nodeTypeIs(node, "import_statement") or nodeTypeIs(node, "import_from_statement")) {
        try appendImportRelation(state, node);
    } else if (nodeTypeIs(node, "call")) {
        try appendCallRelation(state, node);
    } else if (nodeTypeIs(node, "attribute")) {
        try appendUnknownRelation(state, node);
    } else if (nodeTypeIs(node, "identifier")) {
        try appendIdentifierRelation(state, node);
    }

    const child_count = c.ts_node_named_child_count(node);
    var i: u32 = 0;
    while (i < child_count) : (i += 1) {
        try walkRelationSyntax(state, c.ts_node_named_child(node, i));
    }
}

fn appendImportRelation(state: *RelationBuildState, node: c.TSNode) !void {
    const target = importTarget(state.source, node) orelse return;
    const source_endpoint = try sourceEndpointForNode(state, node);
    errdefer freeRelationEndpoint(state.allocator, source_endpoint);
    const target_endpoint = try makeNamedEndpoint(state.allocator, .external_string, target);
    errdefer freeRelationEndpoint(state.allocator, target_endpoint);
    try appendRelationOwned(state, .import_include, .source_to_target, source_endpoint, target_endpoint, "python import/include syntax", c.ts_node_start_byte(node), c.ts_node_end_byte(node), &relation_import_caveats, .medium);
}

fn appendCallRelation(state: *RelationBuildState, node: c.TSNode) !void {
    const function_node = c.ts_node_named_child(node, 0);
    if (c.ts_node_is_null(function_node)) return;
    if (nodeTypeIs(function_node, "identifier")) {
        const target_name = nodeSourceSlice(state.source, function_node) orelse return;
        const source_endpoint = try sourceEndpointForNode(state, node);
        errdefer freeRelationEndpoint(state.allocator, source_endpoint);
        const target_endpoint = try targetEndpointForName(state, target_name);
        errdefer freeRelationEndpoint(state.allocator, target_endpoint);
        const caveats = if (findDefinitionByName(state.definitions, target_name) == null) &relation_unresolved_caveats else &relation_ok_caveats;
        try appendRelationOwned(state, .call, .source_to_target, source_endpoint, target_endpoint, "python direct call expression", c.ts_node_start_byte(node), c.ts_node_end_byte(node), caveats, .medium);
    } else {
        try appendUnknownRelation(state, function_node);
    }
}

fn appendUnknownRelation(state: *RelationBuildState, node: c.TSNode) !void {
    const target = nodeSourceSlice(state.source, node) orelse return;
    const source_endpoint = try sourceEndpointForNode(state, node);
    errdefer freeRelationEndpoint(state.allocator, source_endpoint);
    const target_endpoint = try makeNamedEndpoint(state.allocator, .unresolved, target);
    errdefer freeRelationEndpoint(state.allocator, target_endpoint);
    try appendRelationOwned(state, .unknown, .none, source_endpoint, target_endpoint, "python relation-like syntax not safely classified", c.ts_node_start_byte(node), c.ts_node_end_byte(node), &relation_unknown_caveats, .low);
}

fn appendIdentifierRelation(state: *RelationBuildState, node: c.TSNode) !void {
    if (isDefinitionName(state.definitions, node)) return;
    if (isImportIdentifier(node)) return;
    if (isCallFunctionNode(node)) return;
    if (isAttributeIdentifier(node)) return;
    if (isParameterIdentifier(node)) return;

    const name = nodeSourceSlice(state.source, node) orelse return;
    if (std.mem.eql(u8, name, "self") or std.mem.eql(u8, name, "cls")) return;

    const source_endpoint = try sourceEndpointForNode(state, node);
    errdefer freeRelationEndpoint(state.allocator, source_endpoint);
    const target_endpoint = try targetEndpointForName(state, name);
    errdefer freeRelationEndpoint(state.allocator, target_endpoint);
    const resolved = findDefinitionByName(state.definitions, name) != null;
    try appendRelationOwned(state, if (resolved) .reference else .unresolved, .source_to_target, source_endpoint, target_endpoint, "python identifier reference syntax", c.ts_node_start_byte(node), c.ts_node_end_byte(node), if (resolved) &relation_ok_caveats else &relation_unresolved_caveats, if (resolved) .medium else .low);
}

fn appendRelationOwned(
    state: *RelationBuildState,
    kind: provider.RelationKind,
    direction: provider.RelationDirection,
    source_endpoint: provider.RelationEndpoint,
    target_endpoint: provider.RelationEndpoint,
    evidence_basis: []const u8,
    start_byte: u32,
    end_byte: u32,
    caveats: []const []const u8,
    confidence: provider.Confidence,
) !void {
    if (state.candidates.items.len >= state.max_candidates) {
        freeRelationEndpoint(state.allocator, source_endpoint);
        freeRelationEndpoint(state.allocator, target_endpoint);
        state.cap_reached = true;
        state.omitted_count += 1;
        return;
    }

    const provider_envelope = try makeRelationProvider(state.allocator, state.path, .ok, .fresh, confidence, caveats);
    errdefer freeRelationProvider(state.allocator, provider_envelope);
    const owned_basis = try state.allocator.dupe(u8, evidence_basis);
    errdefer state.allocator.free(owned_basis);
    const order_path = try state.allocator.dupe(u8, state.path);
    errdefer state.allocator.free(order_path);
    const order_relation = try state.allocator.dupe(u8, @tagName(kind));
    errdefer state.allocator.free(order_relation);
    const order_target = try relationEndpointKey(state.allocator, target_endpoint);
    errdefer state.allocator.free(order_target);

    try state.candidates.append(state.allocator, .{
        .kind = kind,
        .direction = direction,
        .source = source_endpoint,
        .target = target_endpoint,
        .evidence_basis = owned_basis,
        .provider = provider_envelope,
        .freshness = .fresh,
        .failure = .ok,
        .confidence = confidence,
        .caveats = caveats,
        .order_key = .{
            .path = order_path,
            .start_byte = start_byte,
            .end_byte = end_byte,
            .relation = order_relation,
            .target = order_target,
        },
    });
}

fn sourceEndpointForNode(state: *RelationBuildState, node: c.TSNode) !provider.RelationEndpoint {
    const start = c.ts_node_start_byte(node);
    const end = c.ts_node_end_byte(node);
    if (containingDefinitionIndex(state.definitions, start, end, null)) |index| {
        return makeCurrentSymbolEndpoint(state.allocator, state.path, state.definitions[index]);
    }
    return makeFileEndpoint(state.allocator, state.path);
}

fn targetEndpointForName(state: *RelationBuildState, name: []const u8) !provider.RelationEndpoint {
    if (findDefinitionByName(state.definitions, name)) |definition| {
        return makeCurrentSymbolEndpoint(state.allocator, state.path, definition);
    }
    return makeNamedEndpoint(state.allocator, .unresolved, name);
}

fn makeFileEndpoint(allocator: std.mem.Allocator, path: []const u8) !provider.RelationEndpoint {
    return .{ .file = .{ .path = try allocator.dupe(u8, path) } };
}

fn makeCurrentSymbolEndpoint(allocator: std.mem.Allocator, path: []const u8, definition: DefinitionRecord) !provider.RelationEndpoint {
    const owned_path = try allocator.dupe(u8, path);
    errdefer allocator.free(owned_path);
    const owned_name = try allocator.dupe(u8, definition.name);
    return .{ .current_symbol = .{ .path = owned_path, .name = owned_name, .kind = definition.kind, .current_range = definition.range } };
}

fn makeNamedEndpoint(allocator: std.mem.Allocator, comptime tag: NamedEndpointTag, value: []const u8) !provider.RelationEndpoint {
    const owned_value = try allocator.dupe(u8, value);
    return switch (tag) {
        .unresolved => .{ .unresolved = .{ .value = owned_value } },
        .external_string => .{ .external_string = .{ .value = owned_value } },
    };
}

fn relationEndpointKey(allocator: std.mem.Allocator, endpoint: provider.RelationEndpoint) ![]u8 {
    return switch (endpoint) {
        .file => |file| allocator.dupe(u8, file.path),
        .current_symbol => |symbol| allocator.dupe(u8, symbol.name),
        .report_symbol => |symbol| allocator.dupe(u8, symbol.name),
        .unresolved, .external_string => |named| allocator.dupe(u8, named.value),
    };
}

fn containingDefinitionIndex(definitions: []const DefinitionRecord, start_byte: u32, end_byte: u32, skip_index: ?usize) ?usize {
    var selected: ?usize = null;
    var selected_span: u32 = std.math.maxInt(u32);
    for (definitions, 0..) |definition, i| {
        if (skip_index) |skip| if (i == skip) continue;
        if (definition.start_byte <= start_byte and definition.end_byte >= end_byte) {
            const span = definition.end_byte - definition.start_byte;
            if (span < selected_span) {
                selected = i;
                selected_span = span;
            }
        }
    }
    return selected;
}

fn findDefinitionByName(definitions: []const DefinitionRecord, name: []const u8) ?DefinitionRecord {
    var found: ?DefinitionRecord = null;
    for (definitions) |definition| {
        if (!std.mem.eql(u8, definition.name, name)) continue;
        if (found != null) return null;
        found = definition;
    }
    return found;
}

fn isDefinitionName(definitions: []const DefinitionRecord, node: c.TSNode) bool {
    const start = c.ts_node_start_byte(node);
    const end = c.ts_node_end_byte(node);
    for (definitions) |definition| {
        if (definition.name_start_byte == start and definition.name_end_byte == end) return true;
    }
    return false;
}

fn isImportIdentifier(node: c.TSNode) bool {
    var current = node;
    while (true) {
        const parent = c.ts_node_parent(current);
        if (c.ts_node_is_null(parent)) return false;
        if (nodeTypeIs(parent, "import_statement") or nodeTypeIs(parent, "import_from_statement") or nodeTypeIs(parent, "dotted_name") or nodeTypeIs(parent, "aliased_import")) return true;
        if (nodeTypeIs(parent, "module") or nodeTypeIs(parent, "block") or nodeTypeIs(parent, "function_definition") or nodeTypeIs(parent, "class_definition")) return false;
        current = parent;
    }
}

fn isCallFunctionNode(node: c.TSNode) bool {
    const parent = c.ts_node_parent(node);
    if (c.ts_node_is_null(parent) or !nodeTypeIs(parent, "call")) return false;
    const function_node = c.ts_node_named_child(parent, 0);
    return !c.ts_node_is_null(function_node) and c.ts_node_eq(function_node, node);
}

fn isAttributeIdentifier(node: c.TSNode) bool {
    const parent = c.ts_node_parent(node);
    return !c.ts_node_is_null(parent) and nodeTypeIs(parent, "attribute");
}

fn isParameterIdentifier(node: c.TSNode) bool {
    var current = node;
    while (true) {
        const parent = c.ts_node_parent(current);
        if (c.ts_node_is_null(parent)) return false;
        if (nodeTypeIs(parent, "parameters") or nodeTypeIs(parent, "typed_parameter") or nodeTypeIs(parent, "default_parameter")) return true;
        if (nodeTypeIs(parent, "function_definition") or nodeTypeIs(parent, "class_definition") or nodeTypeIs(parent, "module") or nodeTypeIs(parent, "block")) return false;
        current = parent;
    }
}

fn importTarget(source: []const u8, node: c.TSNode) ?[]const u8 {
    const text = std.mem.trim(u8, nodeSourceSlice(source, node) orelse return null, " \t\r\n");
    if (std.mem.startsWith(u8, text, "from ")) {
        const rest = text[5..];
        const import_index = std.mem.indexOf(u8, rest, " import") orelse return null;
        return firstDottedToken(rest[0..import_index]);
    }
    if (std.mem.startsWith(u8, text, "import ")) {
        return firstDottedToken(text[7..]);
    }
    return null;
}

fn firstDottedToken(text: []const u8) ?[]const u8 {
    const trimmed = std.mem.trim(u8, text, " \t\r\n");
    if (trimmed.len == 0) return null;
    var end: usize = 0;
    while (end < trimmed.len) : (end += 1) {
        const char = trimmed[end];
        if (!(std.ascii.isAlphanumeric(char) or char == '_' or char == '.')) break;
    }
    if (end == 0) return null;
    return trimmed[0..end];
}

fn lessDefinitionRecord(_: void, lhs: DefinitionRecord, rhs: DefinitionRecord) bool {
    if (lhs.start_byte != rhs.start_byte) return lhs.start_byte < rhs.start_byte;
    if (lhs.end_byte != rhs.end_byte) return lhs.end_byte < rhs.end_byte;
    return std.mem.order(u8, lhs.name, rhs.name) == .lt;
}

fn compilePythonQuery() !*c.TSQuery {
    var error_offset: u32 = 0;
    var error_type: c.TSQueryError = c.TSQueryErrorNone;
    return c.ts_query_new(
        tree_sitter_python(),
        query_source.ptr,
        @intCast(query_source.len),
        &error_offset,
        &error_type,
    ) orelse error.QueryCompileFailed;
}

fn appendDefinitionCandidate(
    allocator: std.mem.Allocator,
    candidates: *std.ArrayList(SymbolCandidate),
    path: []const u8,
    source: []const u8,
    definition_node: c.TSNode,
    name_node: c.TSNode,
    kind: DefinitionKind,
    generated: bool,
) !void {
    const symbol_name = nodeSourceSlice(source, name_node) orelse return;
    switch (kind) {
        .class => try appendCandidate(allocator, candidates, path, symbol_name, .class, name_node, rangeNode(definition_node), caveatsForDefinition(.class, generated)),
        .function => {
            const symbol_kind: provider.SymbolKind = if (isDirectClassBodyDefinition(definition_node)) .method else .function;
            try appendCandidate(allocator, candidates, path, symbol_name, symbol_kind, name_node, rangeNode(definition_node), caveatsForDefinition(if (symbol_kind == .method) .method else .function, generated));
        },
        .assignment => {
            if (!isModuleLevelDefinition(definition_node)) return;
            const symbol_kind: provider.SymbolKind = if (isConstantLikeName(symbol_name)) .other else .variable;
            try appendCandidate(allocator, candidates, path, symbol_name, symbol_kind, name_node, definition_node, caveatsForDefinition(if (symbol_kind == .other) .constant else .variable, generated));
        },
    }
}

fn appendCandidate(
    allocator: std.mem.Allocator,
    candidates: *std.ArrayList(SymbolCandidate),
    path: []const u8,
    symbol_name: []const u8,
    kind: provider.SymbolKind,
    order_node: c.TSNode,
    symbol_range_node: c.TSNode,
    caveats: []const []const u8,
) !void {
    const owned_path = try allocator.dupe(u8, path);
    errdefer allocator.free(owned_path);
    const owned_name = try allocator.dupe(u8, symbol_name);
    errdefer allocator.free(owned_name);

    try candidates.append(allocator, .{
        .start_byte = c.ts_node_start_byte(order_node),
        .end_byte = c.ts_node_end_byte(order_node),
        .symbol = .{
            .path = owned_path,
            .name = owned_name,
            .kind = kind,
            .current_range = .{ .lines = nodeLineRange(symbol_range_node) },
            .provider_name = provider_name,
            .confidence = .high,
            .caveats = caveats,
        },
    });
}

fn caveatsForModule(generated: bool) []const []const u8 {
    return if (generated) &generated_caveats else &ok_caveats;
}

fn caveatsForDefinition(kind: CaveatKind, generated: bool) []const []const u8 {
    if (generated) return &generated_caveats;
    return switch (kind) {
        .module, .class, .function => &ok_caveats,
        .method => &method_caveats,
        .constant => &const_caveats,
        .variable => &variable_caveats,
    };
}

fn rangeNode(node: c.TSNode) c.TSNode {
    const parent = c.ts_node_parent(node);
    if (!c.ts_node_is_null(parent) and nodeTypeIs(parent, "decorated_definition")) return parent;
    return node;
}

fn isDirectClassBodyDefinition(node: c.TSNode) bool {
    var definition = node;
    const decorated_parent = c.ts_node_parent(definition);
    if (!c.ts_node_is_null(decorated_parent) and nodeTypeIs(decorated_parent, "decorated_definition")) {
        definition = decorated_parent;
    }

    const parent = c.ts_node_parent(definition);
    if (c.ts_node_is_null(parent) or !nodeTypeIs(parent, "block")) return false;

    const grandparent = c.ts_node_parent(parent);
    return !c.ts_node_is_null(grandparent) and nodeTypeIs(grandparent, "class_definition");
}

fn isModuleLevelDefinition(node: c.TSNode) bool {
    var current = node;
    while (true) {
        const parent = c.ts_node_parent(current);
        if (c.ts_node_is_null(parent)) return false;
        if (nodeTypeIs(parent, "module")) return true;
        if (nodeTypeIs(parent, "block") or nodeTypeIs(parent, "class_definition") or nodeTypeIs(parent, "function_definition")) return false;
        current = parent;
    }
}

fn hasGeneratedMarker(source: []const u8) bool {
    const scan_len = @min(source.len, 2048);
    const prefix = source[0..scan_len];
    return std.mem.indexOf(u8, prefix, "Code generated") != null or std.mem.indexOf(u8, prefix, "DO NOT EDIT") != null;
}

fn isConstantLikeName(name: []const u8) bool {
    var saw_alpha = false;
    for (name) |char| {
        if (std.ascii.isAlphabetic(char)) {
            saw_alpha = true;
            if (std.ascii.isLower(char)) return false;
        } else if (std.ascii.isDigit(char) or char == '_') {
            continue;
        } else {
            return false;
        }
    }
    return saw_alpha;
}

fn queryCaptureName(query: *const c.TSQuery, capture_index: u32) []const u8 {
    var name_len: u32 = 0;
    const name_ptr = c.ts_query_capture_name_for_id(query, capture_index, &name_len);
    return name_ptr[0..name_len];
}

fn nodeTypeIs(node: c.TSNode, expected: []const u8) bool {
    if (c.ts_node_is_null(node)) return false;
    return std.mem.eql(u8, std.mem.span(c.ts_node_type(node)), expected);
}

fn nodeSourceSlice(source: []const u8, node: c.TSNode) ?[]const u8 {
    const start: usize = @intCast(c.ts_node_start_byte(node));
    const end: usize = @intCast(c.ts_node_end_byte(node));
    if (start > end or end > source.len) return null;
    return source[start..end];
}

fn nodeLineRange(node: c.TSNode) provider.LineRange {
    const start = c.ts_node_start_point(node);
    const end = c.ts_node_end_point(node);
    return .{
        .start = start.row + 1,
        .end = @max(start.row + 1, end.row + 1),
    };
}

fn lessCandidate(_: void, lhs: SymbolCandidate, rhs: SymbolCandidate) bool {
    if (lhs.start_byte != rhs.start_byte) return lhs.start_byte < rhs.start_byte;
    if (lhs.end_byte != rhs.end_byte) return lhs.end_byte < rhs.end_byte;
    return std.mem.order(u8, lhs.symbol.name, rhs.symbol.name) == .lt;
}

fn expectLineRange(symbol: provider.CurrentSymbolEvidence, start: u32, end: u32) !void {
    switch (symbol.current_range) {
        .lines => |range| {
            try std.testing.expectEqual(start, range.start);
            try std.testing.expectEqual(end, range.end);
        },
        .bytes => return error.ExpectedLineRange,
    }
}

fn expectSymbol(symbol: provider.CurrentSymbolEvidence, name: []const u8, kind: provider.SymbolKind, start: u32, end: u32) !void {
    try std.testing.expectEqualStrings(name, symbol.name);
    try std.testing.expectEqual(kind, symbol.kind);
    try std.testing.expectEqualStrings(provider_name, symbol.provider_name);
    try std.testing.expectEqual(provider.Confidence.high, symbol.confidence);
    try expectLineRange(symbol, start, end);
}

fn expectNoSymbol(symbols: []const provider.CurrentSymbolEvidence, name: []const u8) !void {
    for (symbols) |symbol| {
        if (std.mem.eql(u8, symbol.name, name)) return error.UnexpectedSymbol;
    }
}

fn expectCaveat(caveats: []const []const u8, expected: []const u8) !void {
    for (caveats) |caveat| {
        if (std.mem.eql(u8, caveat, expected)) return;
    }
    return error.ExpectedCaveat;
}

fn endpointName(endpoint: provider.RelationEndpoint) []const u8 {
    return switch (endpoint) {
        .file => |file| file.path,
        .current_symbol => |symbol| symbol.name,
        .report_symbol => |symbol| symbol.name,
        .unresolved, .external_string => |named| named.value,
    };
}

fn expectRelationTarget(relations: []const provider.RelationCandidate, kind: provider.RelationKind, target: []const u8) !void {
    for (relations) |relation| {
        if (relation.kind == kind and std.mem.eql(u8, endpointName(relation.target), target)) return;
    }
    return error.ExpectedRelation;
}

fn expectContains(relations: []const provider.RelationCandidate, source: []const u8, target: []const u8) !void {
    for (relations) |relation| {
        if (relation.kind == .contains and std.mem.eql(u8, endpointName(relation.source), source) and std.mem.eql(u8, endpointName(relation.target), target)) return;
    }
    return error.ExpectedContainsRelation;
}

fn expectRelationOrder(relations: []const provider.RelationCandidate) !void {
    var index: usize = 1;
    while (index < relations.len) : (index += 1) {
        const previous = relations[index - 1].order_key;
        const current = relations[index].order_key;
        if (previous.start_byte > current.start_byte) return error.RelationsOutOfOrder;
        if (previous.start_byte == current.start_byte and previous.end_byte > current.end_byte) return error.RelationsOutOfOrder;
        if (previous.start_byte == current.start_byte and previous.end_byte == current.end_byte and std.mem.order(u8, previous.relation, current.relation) == .gt) return error.RelationsOutOfOrder;
    }
}

test "extract source handles supported Python subset in source order" {
    const source =
        \\"""Module fixture with Markdown-sensitive text: ```python and | tables |."""
        \\
        \\from __future__ import annotations
        \\
        \\CONSTANT = 1
        \\mutable_value = 2
        \\FIRST, SECOND = (1, 2)
        \\locals()["DYNAMIC"] = 3
        \\
        \\@decorator
        \\def top_function(arg):
        \\    local_value = 1
        \\
        \\    def inner_function():
        \\        return arg
        \\
        \\    class InnerClass:
        \\        pass
        \\
        \\    return inner_function
        \\
        \\@decorator
        \\class Outer:
        \\    class Nested:
        \\        pass
        \\
        \\    @decorator
        \\    def method(self):
        \\        def method_inner():
        \\            return self
        \\        return method_inner
        \\
        \\def café():
        \\    return "unicode"
        \\
    ;

    var result = try extractSource(std.testing.allocator, "pkg/supported_subset.py", source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.provider.failure);
    try std.testing.expectEqual(@as(usize, 11), result.symbols.len);
    try expectSymbol(result.symbols[0], "pkg/supported_subset.py", .module, 1, 35);
    try expectSymbol(result.symbols[1], "CONSTANT", .other, 5, 5);
    try expectSymbol(result.symbols[2], "mutable_value", .variable, 6, 6);
    try expectSymbol(result.symbols[3], "top_function", .function, 10, 20);
    try expectSymbol(result.symbols[4], "inner_function", .function, 14, 15);
    try expectSymbol(result.symbols[5], "InnerClass", .class, 17, 18);
    try expectSymbol(result.symbols[6], "Outer", .class, 22, 31);
    try expectSymbol(result.symbols[7], "Nested", .class, 24, 25);
    try expectSymbol(result.symbols[8], "method", .method, 27, 31);
    try expectSymbol(result.symbols[9], "method_inner", .function, 29, 30);
    try expectSymbol(result.symbols[10], "café", .function, 33, 34);
    try expectNoSymbol(result.symbols, "FIRST");
    try expectNoSymbol(result.symbols, "SECOND");
    try expectNoSymbol(result.symbols, "DYNAMIC");
    try expectNoSymbol(result.symbols, "local_value");
    try expectCaveat(result.symbols[1].caveats, "constant-like uppercase module assignments map to provider SymbolKind.other because no constant-specific kind exists");
    try expectCaveat(result.symbols[2].caveats, "module-level simple assignments map to provider SymbolKind.variable");
    try expectCaveat(result.symbols[8].caveats, "method classification is derived from a direct enclosing class block; method names are bare identifiers");
}

test "extract source handles empty invalid generated unsupported and unsafe Python inputs" {
    var empty = try extractSource(std.testing.allocator, "pkg/empty.py", "");
    defer empty.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, empty.provider.failure);
    try std.testing.expectEqual(@as(usize, 1), empty.symbols.len);
    try expectSymbol(empty.symbols[0], "pkg/empty.py", .module, 1, 1);

    var broken = try extractSource(std.testing.allocator, "pkg/invalid_partial.py", "def broken(:\n    pass\n");
    defer broken.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.failed, broken.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), broken.symbols.len);
    try expectCaveat(broken.provider.caveats, "invalid or partial Python source failed closed without parser diagnostics or source snippets");

    const generated_source =
        \\# Code generated by local fixture; DO NOT EDIT.
        \\AUTO_CONSTANT = 1
        \\
        \\def generated_function():
        \\    return AUTO_CONSTANT
        \\
    ;
    var generated = try extractSource(std.testing.allocator, "pkg/generated.py", generated_source);
    defer generated.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, generated.provider.failure);
    try std.testing.expectEqual(@as(usize, 3), generated.symbols.len);
    try expectSymbol(generated.symbols[0], "pkg/generated.py", .module, 1, 6);
    try expectSymbol(generated.symbols[1], "AUTO_CONSTANT", .other, 2, 2);
    try expectSymbol(generated.symbols[2], "generated_function", .function, 4, 5);
    try expectCaveat(generated.symbols[2].caveats, "generated-file markers are caveated only; generated-source policy is not evaluated by this provider");

    var unsupported = try extractSource(std.testing.allocator, "docs/unsupported.md", "def hidden():\n    return 1\n");
    defer unsupported.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unsupported, unsupported.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), unsupported.symbols.len);

    try std.testing.expectError(error.InvalidRepoRelativePath, extractSource(std.testing.allocator, "../private/source.py", "def hidden():\n    return 1\n"));
}

test "extract relations emits bounded caveated Python relation candidates" {
    const source =
        \\import os.path
        \\from pkg.tools import worker
        \\
        \\CONSTANT = 1
        \\
        \\def helper():
        \\    return CONSTANT
        \\
        \\class Outer:
        \\    def method(self):
        \\        def nested():
        \\            return helper()
        \\        missing_value
        \\        registry.dynamic
        \\        return nested()
        \\
    ;

    var result = try extractRelationsSource(std.testing.allocator, "pkg/relations.py", source, .{});
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.ProviderKind.relation, result.provider.kind);
    try std.testing.expectEqual(provider.Failure.ok, result.provider.failure);
    try std.testing.expectEqual(provider.Freshness.fresh, result.provider.freshness);
    try std.testing.expect(!result.cap_reached);
    try std.testing.expect(result.candidates.len > 0);
    try expectRelationOrder(result.candidates);

    try expectRelationTarget(result.candidates, .contains, "helper");
    try expectRelationTarget(result.candidates, .contains, "Outer");
    try expectContains(result.candidates, "Outer", "method");
    try expectContains(result.candidates, "method", "nested");
    try expectRelationTarget(result.candidates, .import_include, "os.path");
    try expectRelationTarget(result.candidates, .import_include, "pkg.tools");
    try expectRelationTarget(result.candidates, .reference, "CONSTANT");
    try expectRelationTarget(result.candidates, .call, "helper");
    try expectRelationTarget(result.candidates, .call, "nested");
    try expectRelationTarget(result.candidates, .unresolved, "missing_value");
    try expectRelationTarget(result.candidates, .unknown, "registry.dynamic");

    for (result.candidates) |relation| {
        try provider.validateRelationEndpoint(relation.source);
        try provider.validateRelationEndpoint(relation.target);
        try std.testing.expectEqual(provider.ProviderKind.relation, relation.provider.kind);
        try expectCaveat(relation.caveats, "symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction");
    }
}

test "extract relations degrades for unsupported failure unavailable oversized and cap states" {
    var unsupported = try extractRelationsSource(std.testing.allocator, "docs/relations.md", "def hidden():\n    pass\n", .{});
    defer unsupported.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unsupported, unsupported.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), unsupported.candidates.len);

    var failed = try extractRelationsSource(std.testing.allocator, "pkg/broken.py", "def broken(:\n    pass\n", .{});
    defer failed.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.failed, failed.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), failed.candidates.len);

    var unavailable = try extractRelationsSource(std.testing.allocator, "pkg/unavailable.py", "def hidden():\n    pass\n", .{ .force_provider_unavailable = true });
    defer unavailable.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unavailable, unavailable.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), unavailable.candidates.len);

    var oversized = try extractRelationsSource(std.testing.allocator, "pkg/oversized.py", "def hidden():\n    pass\n", .{ .max_source_bytes = 4 });
    defer oversized.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.skipped, oversized.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), oversized.candidates.len);

    var capped = try extractRelationsSource(std.testing.allocator, "pkg/capped.py", "def one():\n    pass\ndef two():\n    one()\n", .{ .max_candidates = 2 });
    defer capped.deinit(std.testing.allocator);
    try std.testing.expect(capped.cap_reached);
    try std.testing.expect(capped.omitted_count > 0);
    try std.testing.expectEqual(provider.Freshness.partial, capped.provider.freshness);
    try std.testing.expectEqual(@as(usize, 2), capped.candidates.len);
    try expectCaveat(capped.provider.caveats, "relation candidate cap reached; emitted evidence is partial and deterministically truncated");

    try std.testing.expectError(error.InvalidRepoRelativePath, extractRelationsSource(std.testing.allocator, "../private/relations.py", "def hidden():\n    pass\n", .{}));
}
