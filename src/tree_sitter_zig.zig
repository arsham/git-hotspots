const std = @import("std");
const provider = @import("provider.zig");
const tree_sitter_common = @import("tree_sitter_common.zig");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_zig() *const c.TSLanguage;

pub const provider_name = "tree-sitter-zig";
pub const provider_version = "tree-sitter-core@v0.26.9/tree-sitter-zig@v1.1.2";
pub const relation_provider_name = "tree-sitter-zig-relations";
pub const relation_provider_version = "tree-sitter-core@v0.26.9/tree-sitter-zig@v1.1.2/zig-relation-proof-v1";
const max_file_bytes: u64 = 1024 * 1024;

const ok_caveats = [_][]const u8{
    "current working-tree enrichment only; file-level Git evidence remains product truth",
    "supported subset: named Zig function declarations only",
    "range convention: one-based inclusive lines",
};
const unsupported_caveats = [_][]const u8{
    "provider unsupported: only repo-relative .zig files are parsed",
    "no parser diagnostics or source snippets exposed",
};
const unavailable_caveats = [_][]const u8{
    "current working-tree file unavailable or not a regular bounded file",
    "no parser diagnostics, source snippets, absolute paths, remotes, author identities, commit messages, or private repo names exposed",
};
const failed_caveats = [_][]const u8{
    "provider failed to parse supported Zig symbol evidence",
    "no parser diagnostics or source snippets exposed",
};
const partial_caveats = [_][]const u8{
    "partial parse: supported function declarations are low-confidence current evidence",
    "no parser diagnostics or source snippets exposed",
};
const relation_ok_caveats = [_][]const u8{
    "candidate relation evidence only; file-level Git evidence remains product truth",
    "bounded Zig syntax proof: contains, @import strings, direct identifier calls, local identifier references, unresolved identifiers, and ambiguous member or comptime syntax",
    "unresolved and external-string endpoints are caveated; no package, build graph, namespace, type, method, comptime, or generated-code truth is fabricated",
    "symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction",
};
const relation_unresolved_caveats = relation_ok_caveats ++ [_][]const u8{
    "target is unresolved by this bounded Zig syntax proof",
};
const relation_import_caveats = relation_ok_caveats ++ [_][]const u8{
    "@import target is an external string; package lookup, build graph meaning, and file-system resolution are out of scope",
};
const relation_unknown_caveats = relation_ok_caveats ++ [_][]const u8{
    "relation-like Zig syntax is present but cannot be classified safely by this proof",
};
const relation_cap_caveats = relation_ok_caveats ++ [_][]const u8{
    "relation candidate cap reached; emitted evidence is partial and deterministically truncated",
};
const relation_unsupported_caveats = [_][]const u8{
    "relation provider unsupported: only repo-relative .zig files are parsed",
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
    "relation provider failed to parse supported Zig source",
    "invalid or partial Zig source failed closed without parser diagnostics or source snippets",
};

pub const Extraction = tree_sitter_common.Extraction;
pub const RelationExtraction = provider.RelationExtraction;
pub const max_relation_candidates: usize = 64;

pub const RelationOptions = struct {
    max_source_bytes: u64 = max_file_bytes,
    max_candidates: usize = max_relation_candidates,
    force_provider_unavailable: bool = false,
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
        for (self.candidates.items) |candidate| provider.freeRelationCandidate(self.allocator, candidate);
        self.candidates.deinit(self.allocator);
    }
};

const NamedEndpointTag = enum { unresolved, external_string };

pub fn extractPath(allocator: std.mem.Allocator, io: std.Io, repo_root: []const u8, repo_relative_path: []const u8) !Extraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!std.mem.endsWith(u8, repo_relative_path, ".zig")) {
        return extraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &unsupported_caveats, &.{});
    }

    const source = try tree_sitter_common.readBoundedFile(allocator, io, repo_root, repo_relative_path, max_file_bytes) orelse return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    defer allocator.free(source);

    return extractSource(allocator, repo_relative_path, source);
}

pub fn extractSource(allocator: std.mem.Allocator, repo_relative_path: []const u8, source: []const u8) !Extraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!std.mem.endsWith(u8, repo_relative_path, ".zig")) {
        return extraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &unsupported_caveats, &.{});
    }

    const parser = c.ts_parser_new() orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .unknown, &failed_caveats, &.{});
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_zig())) return extraction(allocator, repo_relative_path, .failed, .unknown, .unknown, &failed_caveats, &.{});

    const source_len = std.math.cast(u32, source.len) orelse return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .unknown, &failed_caveats, &.{});
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    var symbols: std.ArrayList(provider.CurrentSymbolEvidence) = .empty;
    errdefer {
        for (symbols.items) |symbol| {
            allocator.free(symbol.path);
            allocator.free(symbol.name);
        }
        symbols.deinit(allocator);
    }

    const has_error = c.ts_node_has_error(root);
    try collectFunctionDeclarations(allocator, &symbols, repo_relative_path, source, root, has_error);
    std.mem.sort(provider.CurrentSymbolEvidence, symbols.items, {}, provider.lessSymbol);

    if (has_error and symbols.items.len == 0) {
        return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    }

    const confidence: provider.Confidence = if (has_error) .low else .high;
    const caveats = if (has_error) &partial_caveats else &ok_caveats;
    return extraction(allocator, repo_relative_path, .ok, .fresh, confidence, caveats, try symbols.toOwnedSlice(allocator));
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

pub fn extractRelationsPath(allocator: std.mem.Allocator, io: std.Io, repo_root: []const u8, repo_relative_path: []const u8, options: RelationOptions) !RelationExtraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!std.mem.endsWith(u8, repo_relative_path, ".zig")) {
        return relationExtraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &relation_unsupported_caveats, false, 0, &.{});
    }

    if (options.force_provider_unavailable) {
        return relationExtraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &relation_unavailable_caveats, false, 0, &.{});
    }

    const source = try tree_sitter_common.readBoundedFile(allocator, io, repo_root, repo_relative_path, options.max_source_bytes) orelse return relationExtraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &relation_unavailable_caveats, false, 0, &.{});
    defer allocator.free(source);

    return extractRelationsSource(allocator, repo_relative_path, source, options);
}

pub fn extractRelationsSource(allocator: std.mem.Allocator, repo_relative_path: []const u8, source: []const u8, options: RelationOptions) !RelationExtraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!std.mem.endsWith(u8, repo_relative_path, ".zig")) {
        return relationExtraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &relation_unsupported_caveats, false, 0, &.{});
    }
    if (options.force_provider_unavailable) {
        return relationExtraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &relation_unavailable_caveats, false, 0, &.{});
    }
    if (source.len > options.max_source_bytes) {
        return relationExtraction(allocator, repo_relative_path, .skipped, .unknown, .unknown, &relation_oversized_caveats, false, 0, &.{});
    }

    const parser = c.ts_parser_new() orelse return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_zig())) return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});

    const source_len = std.math.cast(u32, source.len) orelse return relationExtraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &relation_unavailable_caveats, false, 0, &.{});
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});

    var definitions: std.ArrayList(DefinitionRecord) = .empty;
    defer definitions.deinit(allocator);
    try collectRelationDefinitions(allocator, &definitions, source, root);
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
    errdefer provider.freeRelationCandidates(allocator, candidates);
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

fn collectRelationDefinitions(allocator: std.mem.Allocator, definitions: *std.ArrayList(DefinitionRecord), source: []const u8, node: c.TSNode) !void {
    if (c.ts_node_is_null(node)) return;

    if (nodeTypeIs(node, "function_declaration")) {
        const name_node = childByFieldName(node, "name");
        try appendDefinitionRecord(allocator, definitions, source, node, name_node, .function);
    } else if (nodeTypeIs(node, "variable_declaration")) {
        if (firstNamedChildOfType(node, "identifier")) |name_node| {
            const kind: provider.SymbolKind = if (variableInitializesContainer(node)) .type else .other;
            try appendDefinitionRecord(allocator, definitions, source, node, name_node, kind);
        }
    }

    const child_count = c.ts_node_named_child_count(node);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        try collectRelationDefinitions(allocator, definitions, source, c.ts_node_named_child(node, index));
    }
}

fn appendDefinitionRecord(
    allocator: std.mem.Allocator,
    definitions: *std.ArrayList(DefinitionRecord),
    source: []const u8,
    definition_node: c.TSNode,
    name_node: c.TSNode,
    kind: provider.SymbolKind,
) !void {
    const symbol_name = nodeSourceSlice(source, name_node) orelse return;
    try definitions.append(allocator, .{
        .start_byte = c.ts_node_start_byte(definition_node),
        .end_byte = c.ts_node_end_byte(definition_node),
        .name_start_byte = c.ts_node_start_byte(name_node),
        .name_end_byte = c.ts_node_end_byte(name_node),
        .name = symbol_name,
        .kind = kind,
        .range = .{ .lines = nodeLineRange(definition_node) },
    });
}

fn appendContainmentRelations(state: *RelationBuildState) !void {
    for (state.definitions, 0..) |definition, i| {
        const source_endpoint = if (containingDefinitionIndex(state.definitions, definition.start_byte, definition.end_byte, i)) |parent_index|
            try makeCurrentSymbolEndpoint(state.allocator, state.path, state.definitions[parent_index])
        else
            try makeFileEndpoint(state.allocator, state.path);
        errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);

        const target_endpoint = try makeCurrentSymbolEndpoint(state.allocator, state.path, definition);
        errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);

        try appendRelationOwned(state, .contains, .source_to_target, source_endpoint, target_endpoint, "zig definition containment", definition.start_byte, definition.end_byte, &relation_ok_caveats, .medium);
    }
}

fn walkRelationSyntax(state: *RelationBuildState, node: c.TSNode) !void {
    if (nodeTypeIs(node, "builtin_function")) {
        try appendBuiltinFunctionRelation(state, node);
    } else if (nodeTypeIs(node, "call_expression")) {
        try appendCallRelation(state, node);
    } else if (nodeTypeIs(node, "field_expression")) {
        try appendUnknownRelation(state, node, "zig member access syntax without type or namespace proof");
    } else if (nodeTypeIs(node, "identifier")) {
        try appendIdentifierRelation(state, node);
    }

    const child_count = c.ts_node_named_child_count(node);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        try walkRelationSyntax(state, c.ts_node_named_child(node, index));
    }
}

fn appendBuiltinFunctionRelation(state: *RelationBuildState, node: c.TSNode) !void {
    const builtin_node = firstNamedChildOfType(node, "builtin_identifier") orelse return;
    const builtin_name = nodeSourceSlice(state.source, builtin_node) orelse return;
    if (std.mem.eql(u8, builtin_name, "@import")) {
        const target = firstStringContent(state.source, node) orelse return;
        const source_endpoint = try sourceEndpointForNode(state, node);
        errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);
        const target_endpoint = try makeNamedEndpoint(state.allocator, .external_string, target);
        errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);
        try appendRelationOwned(state, .import_include, .source_to_target, source_endpoint, target_endpoint, "zig @import string syntax", c.ts_node_start_byte(node), c.ts_node_end_byte(node), &relation_import_caveats, .medium);
    } else {
        const source_endpoint = try sourceEndpointForNode(state, node);
        errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);
        const target_endpoint = try makeNamedEndpoint(state.allocator, .unresolved, builtin_name);
        errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);
        try appendRelationOwned(state, .unknown, .none, source_endpoint, target_endpoint, "zig builtin function syntax without comptime semantic proof", c.ts_node_start_byte(node), c.ts_node_end_byte(node), &relation_unknown_caveats, .low);
    }
}

fn appendCallRelation(state: *RelationBuildState, node: c.TSNode) !void {
    const function_node = childByFieldName(node, "function");
    if (c.ts_node_is_null(function_node) or !nodeTypeIs(function_node, "identifier")) return;

    const target_name = nodeSourceSlice(state.source, function_node) orelse return;
    const source_endpoint = try sourceEndpointForNode(state, node);
    errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);
    const target_endpoint = try targetEndpointForName(state, target_name);
    errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);
    const resolved = findDefinitionByName(state.definitions, target_name) != null;
    try appendRelationOwned(state, .call, .source_to_target, source_endpoint, target_endpoint, "zig direct identifier call expression", c.ts_node_start_byte(node), c.ts_node_end_byte(node), if (resolved) &relation_ok_caveats else &relation_unresolved_caveats, if (resolved) .medium else .low);
}

fn appendUnknownRelation(state: *RelationBuildState, node: c.TSNode, evidence_basis: []const u8) !void {
    const target = nodeSourceSlice(state.source, node) orelse return;
    const source_endpoint = try sourceEndpointForNode(state, node);
    errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);
    const target_endpoint = try makeNamedEndpoint(state.allocator, .unresolved, target);
    errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);
    try appendRelationOwned(state, .unknown, .none, source_endpoint, target_endpoint, evidence_basis, c.ts_node_start_byte(node), c.ts_node_end_byte(node), &relation_unknown_caveats, .low);
}

fn appendIdentifierRelation(state: *RelationBuildState, node: c.TSNode) !void {
    if (isDefinitionName(state.definitions, node)) return;
    if (isCallFunctionNode(node)) return;
    if (isFieldExpressionIdentifier(node)) return;
    if (isBuiltinFunctionIdentifier(node)) return;
    if (isParameterIdentifier(node)) return;
    if (isContainerSyntaxIdentifier(node)) return;

    const name = nodeSourceSlice(state.source, node) orelse return;
    const source_endpoint = try sourceEndpointForNode(state, node);
    errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);
    const target_endpoint = try targetEndpointForName(state, name);
    errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);
    const resolved = findDefinitionByName(state.definitions, name) != null;
    try appendRelationOwned(state, if (resolved) .reference else .unresolved, .source_to_target, source_endpoint, target_endpoint, "zig identifier reference syntax", c.ts_node_start_byte(node), c.ts_node_end_byte(node), if (resolved) &relation_ok_caveats else &relation_unresolved_caveats, if (resolved) .medium else .low);
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
        provider.freeRelationEndpoint(state.allocator, source_endpoint);
        provider.freeRelationEndpoint(state.allocator, target_endpoint);
        state.cap_reached = true;
        state.omitted_count += 1;
        return;
    }

    const provider_envelope = try makeRelationProvider(state.allocator, state.path, .ok, .fresh, confidence, caveats);
    errdefer provider.freeRelationProvider(state.allocator, provider_envelope);
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
    for (definitions, 0..) |definition, index| {
        if (skip_index) |skip| if (index == skip) continue;
        if (definition.start_byte <= start_byte and definition.end_byte >= end_byte) {
            const span = definition.end_byte - definition.start_byte;
            if (span < selected_span) {
                selected = index;
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

fn isCallFunctionNode(node: c.TSNode) bool {
    const parent = c.ts_node_parent(node);
    if (c.ts_node_is_null(parent) or !nodeTypeIs(parent, "call_expression")) return false;
    const function_node = childByFieldName(parent, "function");
    return !c.ts_node_is_null(function_node) and c.ts_node_eq(function_node, node);
}

fn isFieldExpressionIdentifier(node: c.TSNode) bool {
    const parent = c.ts_node_parent(node);
    return !c.ts_node_is_null(parent) and nodeTypeIs(parent, "field_expression");
}

fn isBuiltinFunctionIdentifier(node: c.TSNode) bool {
    const parent = c.ts_node_parent(node);
    return !c.ts_node_is_null(parent) and nodeTypeIs(parent, "builtin_function");
}

fn isParameterIdentifier(node: c.TSNode) bool {
    var current = node;
    while (true) {
        const parent = c.ts_node_parent(current);
        if (c.ts_node_is_null(parent)) return false;
        if (nodeTypeIs(parent, "parameters") or nodeTypeIs(parent, "parameter")) return true;
        if (nodeTypeIs(parent, "function_declaration") or nodeTypeIs(parent, "block") or nodeTypeIs(parent, "source_file")) return false;
        current = parent;
    }
}

fn isContainerSyntaxIdentifier(node: c.TSNode) bool {
    var current = node;
    while (true) {
        const parent = c.ts_node_parent(current);
        if (c.ts_node_is_null(parent)) return false;
        if (nodeTypeIs(parent, "struct_declaration") or nodeTypeIs(parent, "enum_declaration") or nodeTypeIs(parent, "union_declaration") or nodeTypeIs(parent, "opaque_declaration")) return true;
        if (nodeTypeIs(parent, "function_declaration") or nodeTypeIs(parent, "block") or nodeTypeIs(parent, "source_file")) return false;
        current = parent;
    }
}

fn firstStringContent(source: []const u8, node: c.TSNode) ?[]const u8 {
    if (nodeTypeIs(node, "string_content")) return nodeSourceSlice(source, node);
    if (nodeTypeIs(node, "string")) {
        const text = nodeSourceSlice(source, node) orelse return null;
        if (text.len >= 2 and text[0] == '"' and text[text.len - 1] == '"') return text[1 .. text.len - 1];
    }
    const child_count = c.ts_node_named_child_count(node);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        if (firstStringContent(source, c.ts_node_named_child(node, index))) |content| return content;
    }
    return null;
}

fn variableInitializesContainer(node: c.TSNode) bool {
    const child_count = c.ts_node_named_child_count(node);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(node, index);
        if (nodeTypeIs(child, "struct_declaration") or nodeTypeIs(child, "enum_declaration") or nodeTypeIs(child, "union_declaration") or nodeTypeIs(child, "opaque_declaration")) return true;
    }
    return false;
}

fn firstNamedChildOfType(node: c.TSNode, expected: []const u8) ?c.TSNode {
    const child_count = c.ts_node_named_child_count(node);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(node, index);
        if (nodeTypeIs(child, expected)) return child;
    }
    return null;
}

fn lessDefinitionRecord(_: void, lhs: DefinitionRecord, rhs: DefinitionRecord) bool {
    if (lhs.start_byte != rhs.start_byte) return lhs.start_byte < rhs.start_byte;
    if (lhs.end_byte != rhs.end_byte) return lhs.end_byte < rhs.end_byte;
    return std.mem.order(u8, lhs.name, rhs.name) == .lt;
}

fn childByFieldName(node: c.TSNode, comptime field_name: []const u8) c.TSNode {
    return c.ts_node_child_by_field_name(node, field_name.ptr, @intCast(field_name.len));
}

fn nodeTypeIs(node: c.TSNode, expected: []const u8) bool {
    if (c.ts_node_is_null(node)) return false;
    return std.mem.eql(u8, std.mem.span(c.ts_node_type(node)), expected);
}

fn collectFunctionDeclarations(
    allocator: std.mem.Allocator,
    symbols: *std.ArrayList(provider.CurrentSymbolEvidence),
    path: []const u8,
    source: []const u8,
    node: c.TSNode,
    low_confidence: bool,
) !void {
    if (c.ts_node_is_null(node)) return;

    const node_type = std.mem.span(c.ts_node_type(node));
    if (std.mem.eql(u8, node_type, "function_declaration")) {
        const name_node = c.ts_node_child_by_field_name(node, "name".ptr, "name".len);
        if (!c.ts_node_is_null(name_node)) {
            if (nodeSourceSlice(source, name_node)) |symbol_name| {
                try symbols.append(allocator, .{
                    .path = try allocator.dupe(u8, path),
                    .name = try allocator.dupe(u8, symbol_name),
                    .kind = .function,
                    .current_range = .{ .lines = nodeLineRange(node) },
                    .provider_name = provider_name,
                    .confidence = if (low_confidence or c.ts_node_has_error(node)) .low else .high,
                    .caveats = if (low_confidence) &partial_caveats else &ok_caveats,
                });
            }
        }
    }

    const child_count = c.ts_node_named_child_count(node);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        try collectFunctionDeclarations(allocator, symbols, path, source, c.ts_node_named_child(node, index), low_confidence);
    }
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
    return .{ .start = start.row + 1, .end = end.row + 1 };
}

test "extract source handles supported, empty, unsupported, and invalid inputs" {
    var ok = try extractSource(std.testing.allocator, "src/example.zig", "pub fn zebra() void {}\nfn alpha() void {}\n");
    defer ok.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, ok.provider.failure);
    try std.testing.expectEqual(@as(usize, 2), ok.symbols.len);
    try std.testing.expectEqualStrings("alpha", ok.symbols[0].name);
    try std.testing.expectEqualStrings("zebra", ok.symbols[1].name);
    switch (ok.symbols[0].current_range) {
        .lines => |range| try std.testing.expectEqual(@as(u32, 2), range.start),
        .bytes => return error.ExpectedLineRange,
    }

    var empty = try extractSource(std.testing.allocator, "empty.zig", "");
    defer empty.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, empty.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), empty.symbols.len);

    var unsupported = try extractSource(std.testing.allocator, "README.md", "pub fn hidden() void {}");
    defer unsupported.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unsupported, unsupported.provider.failure);

    var broken = try extractSource(std.testing.allocator, "broken.zig", "pub fn {");
    defer broken.deinit(std.testing.allocator);
    try std.testing.expect(broken.provider.failure == .failed or broken.provider.confidence == .low);
}
