const std = @import("std");
const provider = @import("provider.zig");
const tree_sitter_common = @import("tree_sitter_common.zig");

pub const provider_api = provider;

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_go() *const c.TSLanguage;

pub const provider_name = "tree-sitter-go";
pub const provider_version = "tree-sitter-core@v0.26.9/tree-sitter-go@v0.25.0";
pub const relation_provider_name = "tree-sitter-go-relations-internal";
pub const relation_provider_version = "tree-sitter-core@v0.26.9/tree-sitter-go@v0.25.0/go-relation-proof-v1";
const max_file_bytes: u64 = 1024 * 1024;

const ok_caveats = [_][]const u8{
    "current working-tree enrichment only; file-level Git evidence remains product truth",
    "supported subset: package clauses, top-level functions, methods, struct/interface type specs, and top-level const/var names",
    "range convention: one-based inclusive lines from the enclosing Go declaration",
    "build tags, generated-file markers, package loading, and cgo are not evaluated",
    "method names are bare identifiers; receiver-qualified naming is out of scope",
};
const unsupported_caveats = [_][]const u8{
    "provider unsupported: only repo-relative .go files are parsed",
    "no parser diagnostics or source snippets exposed",
};
const unavailable_caveats = [_][]const u8{
    "current working-tree file unavailable or not a regular bounded file",
    "no parser diagnostics, source snippets, absolute paths, remotes, author identities, commit messages, or private repo names exposed",
};
const failed_caveats = [_][]const u8{
    "provider failed to parse supported Go symbol evidence",
    "no parser diagnostics or source snippets exposed",
};
const const_caveats = ok_caveats ++ [_][]const u8{
    "const names map to provider SymbolKind.other because no constant-specific kind exists",
};
const type_caveats = ok_caveats ++ [_][]const u8{
    "struct and interface type specs map to provider SymbolKind.type",
};
const relation_ok_caveats = [_][]const u8{
    "candidate relation evidence only; file-level Git evidence remains product truth",
    "internal bounded Go syntax proof: contains, import includes, direct identifier calls, selector-like syntax, unresolved identifiers, and unknown relation-like syntax",
    "unresolved and external-string endpoints are caveated; no package, module, type, interface, method-set, build-tag, generated-source, cgo, vendored, or semantic dependency identity is fabricated",
    "symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction",
    "Go relationship evidence is internal proof evidence only and is not admitted as a public capability claim in this feature",
};
const relation_unresolved_caveats = relation_ok_caveats ++ [_][]const u8{
    "target is unresolved by this bounded Go syntax proof",
};
const relation_import_caveats = relation_ok_caveats ++ [_][]const u8{
    "import target is an external string; package, module, vendor, generated-source, build-tag, and cgo resolution are out of scope",
};
const relation_unknown_caveats = relation_ok_caveats ++ [_][]const u8{
    "Go relation-like syntax is present but cannot be classified safely by this proof",
};
const relation_cap_caveats = relation_ok_caveats ++ [_][]const u8{
    "relation candidate cap reached; emitted evidence is partial and deterministically truncated",
};
const relation_unsupported_caveats = [_][]const u8{
    "relation provider unsupported: only repo-relative .go files are parsed by the internal Go proof",
    "no parser diagnostics or source snippets exposed",
};
const relation_unavailable_caveats = [_][]const u8{
    "relation provider unavailable or current working-tree source was not available to the bounded Go proof",
    "no parser diagnostics, source snippets, absolute paths, remotes, author identities, commit messages, or private repo names exposed",
};
const relation_oversized_caveats = [_][]const u8{
    "Go relation source skipped by bounded-size policy",
    "no source snippets or private path details exposed",
};
const relation_failed_caveats = [_][]const u8{
    "relation provider failed to parse supported Go source",
    "invalid or partial Go source failed closed without parser diagnostics or source snippets",
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
    if (!std.mem.endsWith(u8, repo_relative_path, ".go")) {
        return extraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &unsupported_caveats, &.{});
    }

    const source = try tree_sitter_common.readBoundedFile(allocator, io, repo_root, repo_relative_path, max_file_bytes) orelse return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    defer allocator.free(source);

    return extractSource(allocator, repo_relative_path, source);
}

pub fn extractSource(allocator: std.mem.Allocator, repo_relative_path: []const u8, source: []const u8) !Extraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!std.mem.endsWith(u8, repo_relative_path, ".go")) {
        return extraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &unsupported_caveats, &.{});
    }

    const parser = c.ts_parser_new() orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_go())) return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});

    const source_len = std.math.cast(u32, source.len) orelse return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});

    var symbols: std.ArrayList(provider.CurrentSymbolEvidence) = .empty;
    errdefer {
        for (symbols.items) |symbol| {
            allocator.free(symbol.path);
            allocator.free(symbol.name);
        }
        symbols.deinit(allocator);
    }

    try collectTopLevelDeclarations(allocator, &symbols, repo_relative_path, source, root);
    std.mem.sort(provider.CurrentSymbolEvidence, symbols.items, {}, provider.lessSymbol);
    return extraction(allocator, repo_relative_path, .ok, .fresh, .high, &ok_caveats, try symbols.toOwnedSlice(allocator));
}

pub fn extractRelationsSource(allocator: std.mem.Allocator, repo_relative_path: []const u8, source: []const u8, options: RelationOptions) !RelationExtraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!std.mem.endsWith(u8, repo_relative_path, ".go")) {
        return relationExtraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &relation_unsupported_caveats, false, 0, &.{});
    }
    if (options.force_provider_unavailable) {
        return relationExtraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &relation_unavailable_caveats, false, 0, &.{});
    }
    if (source.len > options.max_source_bytes) {
        return relationExtraction(allocator, repo_relative_path, .skipped, .unknown, .low, &relation_oversized_caveats, false, 0, &.{});
    }

    const parser = c.ts_parser_new() orelse return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_go())) return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});

    const source_len = std.math.cast(u32, source.len) orelse return relationExtraction(allocator, repo_relative_path, .skipped, .unknown, .low, &relation_oversized_caveats, false, 0, &.{});
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});

    var definitions: std.ArrayList(DefinitionRecord) = .empty;
    defer definitions.deinit(allocator);
    try collectDefinitionRecords(allocator, &definitions, repo_relative_path, source, root);
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

fn collectTopLevelDeclarations(
    allocator: std.mem.Allocator,
    symbols: *std.ArrayList(provider.CurrentSymbolEvidence),
    path: []const u8,
    source: []const u8,
    root: c.TSNode,
) !void {
    if (c.ts_node_is_null(root) or !nodeTypeIs(root, "source_file")) return;

    const child_count = c.ts_node_named_child_count(root);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(root, index);
        if (nodeTypeIs(child, "package_clause")) {
            try appendSymbolFromFirstNamedChild(allocator, symbols, path, source, child, child, .module, &ok_caveats);
        } else if (nodeTypeIs(child, "function_declaration")) {
            try appendSymbolFromField(allocator, symbols, path, source, child, child, "name", .function, &ok_caveats);
        } else if (nodeTypeIs(child, "method_declaration")) {
            try appendSymbolFromField(allocator, symbols, path, source, child, child, "name", .method, &ok_caveats);
        } else if (nodeTypeIs(child, "type_declaration")) {
            try collectTypeSpecs(allocator, symbols, path, source, child);
        } else if (nodeTypeIs(child, "const_declaration")) {
            try collectConstOrVarSpecs(allocator, symbols, path, source, child, "const_spec", .other, &const_caveats);
        } else if (nodeTypeIs(child, "var_declaration")) {
            try collectConstOrVarSpecs(allocator, symbols, path, source, child, "var_spec", .variable, &ok_caveats);
        }
    }
}

fn collectDefinitionRecords(allocator: std.mem.Allocator, definitions: *std.ArrayList(DefinitionRecord), path: []const u8, source: []const u8, root: c.TSNode) !void {
    if (c.ts_node_is_null(root) or !nodeTypeIs(root, "source_file")) return;

    const child_count = c.ts_node_named_child_count(root);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(root, index);
        if (nodeTypeIs(child, "package_clause")) {
            try appendDefinitionFromFirstNamedChild(allocator, definitions, source, child, child, .module);
        } else if (nodeTypeIs(child, "function_declaration")) {
            try appendDefinitionFromField(allocator, definitions, source, child, child, "name", .function);
        } else if (nodeTypeIs(child, "method_declaration")) {
            try appendDefinitionFromField(allocator, definitions, source, child, child, "name", .method);
        } else if (nodeTypeIs(child, "type_declaration")) {
            try collectTypeDefinitionRecords(allocator, definitions, source, child);
        } else if (nodeTypeIs(child, "const_declaration")) {
            try collectConstOrVarDefinitionRecords(allocator, definitions, source, child, "const_spec", .other);
        } else if (nodeTypeIs(child, "var_declaration")) {
            try collectConstOrVarDefinitionRecords(allocator, definitions, source, child, "var_spec", .variable);
        }
    }

    _ = path;
}

fn collectTypeDefinitionRecords(allocator: std.mem.Allocator, definitions: *std.ArrayList(DefinitionRecord), source: []const u8, declaration: c.TSNode) !void {
    const child_count = c.ts_node_named_child_count(declaration);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(declaration, index);
        if (!nodeTypeIs(child, "type_spec")) continue;
        const type_node = childByField(child, "type");
        if (nodeTypeIs(type_node, "struct_type") or nodeTypeIs(type_node, "interface_type")) {
            try appendDefinitionFromField(allocator, definitions, source, child, declaration, "name", .type);
        }
    }
}

fn collectConstOrVarDefinitionRecords(allocator: std.mem.Allocator, definitions: *std.ArrayList(DefinitionRecord), source: []const u8, declaration: c.TSNode, spec_type: []const u8, kind: provider.SymbolKind) !void {
    const child_count = c.ts_node_named_child_count(declaration);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(declaration, index);
        if (nodeTypeIs(child, spec_type)) {
            try collectLeadingIdentifierDefinitionRecords(allocator, definitions, source, child, declaration, kind);
        } else if (nodeTypeIs(child, "var_spec_list") or nodeTypeIs(child, "const_spec_list")) {
            try collectConstOrVarDefinitionRecords(allocator, definitions, source, child, spec_type, kind);
        }
    }
}

fn collectLeadingIdentifierDefinitionRecords(allocator: std.mem.Allocator, definitions: *std.ArrayList(DefinitionRecord), source: []const u8, spec: c.TSNode, declaration: c.TSNode, kind: provider.SymbolKind) !void {
    const child_count = c.ts_node_named_child_count(spec);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(spec, index);
        if (!nodeTypeIs(child, "identifier")) break;
        try appendDefinitionRecordUnchecked(allocator, definitions, source, child, declaration, kind);
    }
}

fn appendDefinitionFromField(allocator: std.mem.Allocator, definitions: *std.ArrayList(DefinitionRecord), source: []const u8, name_owner: c.TSNode, range_node: c.TSNode, field_name: []const u8, kind: provider.SymbolKind) !void {
    const name_node = childByField(name_owner, field_name);
    if (!c.ts_node_is_null(name_node)) try appendDefinitionRecordUnchecked(allocator, definitions, source, name_node, range_node, kind);
}

fn appendDefinitionFromFirstNamedChild(allocator: std.mem.Allocator, definitions: *std.ArrayList(DefinitionRecord), source: []const u8, name_owner: c.TSNode, range_node: c.TSNode, kind: provider.SymbolKind) !void {
    const child = c.ts_node_named_child(name_owner, 0);
    if (!c.ts_node_is_null(child)) try appendDefinitionRecordUnchecked(allocator, definitions, source, child, range_node, kind);
}

fn appendDefinitionRecordUnchecked(allocator: std.mem.Allocator, definitions: *std.ArrayList(DefinitionRecord), source: []const u8, name_node: c.TSNode, range_node: c.TSNode, kind: provider.SymbolKind) !void {
    const symbol_name = nodeSourceSlice(source, name_node) orelse return;
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
    for (state.definitions) |definition| {
        const source_endpoint = try makeFileEndpoint(state.allocator, state.path);
        errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);
        const target_endpoint = try makeCurrentSymbolEndpoint(state.allocator, state.path, definition);
        errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);

        try appendRelationOwned(
            state,
            .contains,
            .source_to_target,
            source_endpoint,
            target_endpoint,
            "go top-level declaration containment",
            definition.start_byte,
            definition.end_byte,
            &relation_ok_caveats,
            .medium,
        );
    }
}

fn walkRelationSyntax(state: *RelationBuildState, node: c.TSNode) !void {
    if (nodeTypeIs(node, "import_spec")) {
        try appendImportRelation(state, node);
    } else if (nodeTypeIs(node, "call_expression")) {
        try appendCallRelation(state, node);
    } else if (nodeTypeIs(node, "selector_expression")) {
        try appendUnknownRelation(state, node);
    } else if (nodeTypeIs(node, "identifier")) {
        try appendIdentifierRelation(state, node);
    }

    const child_count = c.ts_node_named_child_count(node);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) try walkRelationSyntax(state, c.ts_node_named_child(node, index));
}

fn appendImportRelation(state: *RelationBuildState, node: c.TSNode) !void {
    const target = importSpecTarget(state.source, node) orelse return;
    const source_endpoint = try sourceEndpointForNode(state, node);
    errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);
    const target_endpoint = try makeNamedEndpoint(state.allocator, .external_string, target);
    errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);
    try appendRelationOwned(state, .import_include, .source_to_target, source_endpoint, target_endpoint, "go import spec syntax", c.ts_node_start_byte(node), c.ts_node_end_byte(node), &relation_import_caveats, .medium);
}

fn appendCallRelation(state: *RelationBuildState, node: c.TSNode) !void {
    const function_node = childByField(node, "function");
    if (c.ts_node_is_null(function_node)) return;

    const target_name = nodeSourceSlice(state.source, function_node) orelse return;
    const source_endpoint = try sourceEndpointForNode(state, node);
    errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);
    const target_endpoint = if (nodeTypeIs(function_node, "identifier"))
        try targetEndpointForName(state, target_name)
    else
        try makeNamedEndpoint(state.allocator, .unresolved, target_name);
    errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);

    const resolved = nodeTypeIs(function_node, "identifier") and findDefinitionByName(state.definitions, target_name) != null;
    try appendRelationOwned(state, .call, .source_to_target, source_endpoint, target_endpoint, "go call expression syntax", c.ts_node_start_byte(node), c.ts_node_end_byte(node), if (resolved) &relation_ok_caveats else &relation_unresolved_caveats, if (resolved) .medium else .low);
}

fn appendUnknownRelation(state: *RelationBuildState, node: c.TSNode) !void {
    const target = nodeSourceSlice(state.source, node) orelse return;
    const source_endpoint = try sourceEndpointForNode(state, node);
    errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);
    const target_endpoint = try makeNamedEndpoint(state.allocator, .unresolved, target);
    errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);
    try appendRelationOwned(state, .unknown, .none, source_endpoint, target_endpoint, "go selector syntax without package/type/method resolution", c.ts_node_start_byte(node), c.ts_node_end_byte(node), &relation_unknown_caveats, .low);
}

fn appendIdentifierRelation(state: *RelationBuildState, node: c.TSNode) !void {
    if (isDefinitionName(state.definitions, node)) return;
    if (isImportIdentifier(node)) return;
    if (isCallFunctionNode(node)) return;
    if (isSelectorIdentifier(node)) return;
    if (isParameterIdentifier(node)) return;

    const name = nodeSourceSlice(state.source, node) orelse return;
    if (isGoBuiltinOrKeywordLikeIdentifier(name)) return;

    const source_endpoint = try sourceEndpointForNode(state, node);
    errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);
    const target_endpoint = try targetEndpointForName(state, name);
    errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);
    const resolved = findDefinitionByName(state.definitions, name) != null;
    try appendRelationOwned(state, if (resolved) .reference else .unresolved, .source_to_target, source_endpoint, target_endpoint, "go identifier reference syntax", c.ts_node_start_byte(node), c.ts_node_end_byte(node), if (resolved) &relation_ok_caveats else &relation_unresolved_caveats, if (resolved) .medium else .low);
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
    if (containingDefinitionIndex(state.definitions, start, end)) |index| {
        return makeCurrentSymbolEndpoint(state.allocator, state.path, state.definitions[index]);
    }
    return makeFileEndpoint(state.allocator, state.path);
}

fn targetEndpointForName(state: *RelationBuildState, name: []const u8) !provider.RelationEndpoint {
    if (findDefinitionByName(state.definitions, name)) |definition| return makeCurrentSymbolEndpoint(state.allocator, state.path, definition);
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

fn containingDefinitionIndex(definitions: []const DefinitionRecord, start_byte: u32, end_byte: u32) ?usize {
    var selected: ?usize = null;
    var selected_span: u32 = std.math.maxInt(u32);
    for (definitions, 0..) |definition, index| {
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

fn isImportIdentifier(node: c.TSNode) bool {
    var current = node;
    while (true) {
        const parent = c.ts_node_parent(current);
        if (c.ts_node_is_null(parent)) return false;
        if (nodeTypeIs(parent, "import_spec") or nodeTypeIs(parent, "import_spec_list") or nodeTypeIs(parent, "import_declaration")) return true;
        if (nodeTypeIs(parent, "source_file") or nodeTypeIs(parent, "function_declaration") or nodeTypeIs(parent, "method_declaration") or nodeTypeIs(parent, "block")) return false;
        current = parent;
    }
}

fn isCallFunctionNode(node: c.TSNode) bool {
    const parent = c.ts_node_parent(node);
    if (c.ts_node_is_null(parent) or !nodeTypeIs(parent, "call_expression")) return false;
    const function_node = childByField(parent, "function");
    return !c.ts_node_is_null(function_node) and c.ts_node_eq(function_node, node);
}

fn isSelectorIdentifier(node: c.TSNode) bool {
    const parent = c.ts_node_parent(node);
    return !c.ts_node_is_null(parent) and nodeTypeIs(parent, "selector_expression");
}

fn isParameterIdentifier(node: c.TSNode) bool {
    var current = node;
    while (true) {
        const parent = c.ts_node_parent(current);
        if (c.ts_node_is_null(parent)) return false;
        if (nodeTypeIs(parent, "parameter_list") or nodeTypeIs(parent, "parameter_declaration") or nodeTypeIs(parent, "method_elem")) return true;
        if (nodeTypeIs(parent, "function_declaration") or nodeTypeIs(parent, "method_declaration") or nodeTypeIs(parent, "source_file") or nodeTypeIs(parent, "block")) return false;
        current = parent;
    }
}

fn isGoBuiltinOrKeywordLikeIdentifier(name: []const u8) bool {
    return std.mem.eql(u8, name, "nil") or
        std.mem.eql(u8, name, "true") or
        std.mem.eql(u8, name, "false") or
        std.mem.eql(u8, name, "iota") or
        std.mem.eql(u8, name, "int") or
        std.mem.eql(u8, name, "string") or
        std.mem.eql(u8, name, "bool") or
        std.mem.eql(u8, name, "error");
}

fn importSpecTarget(source: []const u8, node: c.TSNode) ?[]const u8 {
    const child_count = c.ts_node_named_child_count(node);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(node, index);
        if (nodeTypeIs(child, "interpreted_string_literal") or nodeTypeIs(child, "raw_string_literal")) {
            return unquoteImportLiteral(nodeSourceSlice(source, child) orelse return null);
        }
    }
    const text = nodeSourceSlice(source, node) orelse return null;
    return firstQuotedGoString(text);
}

fn firstQuotedGoString(text: []const u8) ?[]const u8 {
    var start: usize = 0;
    while (start < text.len) : (start += 1) {
        if (text[start] == '"' or text[start] == '`') {
            var end = start + 1;
            while (end < text.len and text[end] != text[start]) : (end += 1) {}
            if (end < text.len) return text[start + 1 .. end];
            return null;
        }
    }
    return null;
}

fn unquoteImportLiteral(text: []const u8) ?[]const u8 {
    const trimmed = std.mem.trim(u8, text, " \t\r\n");
    if (trimmed.len >= 2 and ((trimmed[0] == '"' and trimmed[trimmed.len - 1] == '"') or (trimmed[0] == '`' and trimmed[trimmed.len - 1] == '`'))) {
        return trimmed[1 .. trimmed.len - 1];
    }
    return trimmed;
}

fn lessDefinitionRecord(_: void, lhs: DefinitionRecord, rhs: DefinitionRecord) bool {
    if (lhs.start_byte != rhs.start_byte) return lhs.start_byte < rhs.start_byte;
    if (lhs.end_byte != rhs.end_byte) return lhs.end_byte < rhs.end_byte;
    return std.mem.order(u8, lhs.name, rhs.name) == .lt;
}

fn collectTypeSpecs(allocator: std.mem.Allocator, symbols: *std.ArrayList(provider.CurrentSymbolEvidence), path: []const u8, source: []const u8, declaration: c.TSNode) !void {
    const child_count = c.ts_node_named_child_count(declaration);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(declaration, index);
        if (!nodeTypeIs(child, "type_spec")) continue;
        const type_node = childByField(child, "type");
        if (nodeTypeIs(type_node, "struct_type") or nodeTypeIs(type_node, "interface_type")) {
            try appendSymbolFromField(allocator, symbols, path, source, child, declaration, "name", .type, &type_caveats);
        }
    }
}

fn collectConstOrVarSpecs(allocator: std.mem.Allocator, symbols: *std.ArrayList(provider.CurrentSymbolEvidence), path: []const u8, source: []const u8, declaration: c.TSNode, spec_type: []const u8, kind: provider.SymbolKind, caveats: []const []const u8) !void {
    const child_count = c.ts_node_named_child_count(declaration);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(declaration, index);
        if (nodeTypeIs(child, spec_type)) {
            try collectLeadingIdentifierNames(allocator, symbols, path, source, child, declaration, kind, caveats);
        } else if (nodeTypeIs(child, "var_spec_list") or nodeTypeIs(child, "const_spec_list")) {
            try collectConstOrVarSpecs(allocator, symbols, path, source, child, spec_type, kind, caveats);
        }
    }
}

fn collectLeadingIdentifierNames(allocator: std.mem.Allocator, symbols: *std.ArrayList(provider.CurrentSymbolEvidence), path: []const u8, source: []const u8, spec: c.TSNode, declaration: c.TSNode, kind: provider.SymbolKind, caveats: []const []const u8) !void {
    const child_count = c.ts_node_named_child_count(spec);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(spec, index);
        if (!nodeTypeIs(child, "identifier")) break;
        try appendSymbol(allocator, symbols, path, source, child, declaration, kind, caveats);
    }
}

fn appendSymbolFromField(allocator: std.mem.Allocator, symbols: *std.ArrayList(provider.CurrentSymbolEvidence), path: []const u8, source: []const u8, name_owner: c.TSNode, range_node: c.TSNode, field_name: []const u8, kind: provider.SymbolKind, caveats: []const []const u8) !void {
    const name_node = childByField(name_owner, field_name);
    if (!c.ts_node_is_null(name_node)) try appendSymbol(allocator, symbols, path, source, name_node, range_node, kind, caveats);
}

fn appendSymbolFromFirstNamedChild(allocator: std.mem.Allocator, symbols: *std.ArrayList(provider.CurrentSymbolEvidence), path: []const u8, source: []const u8, name_owner: c.TSNode, range_node: c.TSNode, kind: provider.SymbolKind, caveats: []const []const u8) !void {
    const child = c.ts_node_named_child(name_owner, 0);
    if (!c.ts_node_is_null(child)) try appendSymbol(allocator, symbols, path, source, child, range_node, kind, caveats);
}

fn appendSymbol(allocator: std.mem.Allocator, symbols: *std.ArrayList(provider.CurrentSymbolEvidence), path: []const u8, source: []const u8, name_node: c.TSNode, range_node: c.TSNode, kind: provider.SymbolKind, caveats: []const []const u8) !void {
    const symbol_name = nodeSourceSlice(source, name_node) orelse return;
    try symbols.append(allocator, .{
        .path = try allocator.dupe(u8, path),
        .name = try allocator.dupe(u8, symbol_name),
        .kind = kind,
        .current_range = .{ .lines = nodeLineRange(range_node) },
        .provider_name = provider_name,
        .confidence = .high,
        .caveats = caveats,
    });
}

fn childByField(node: c.TSNode, field_name: []const u8) c.TSNode {
    return c.ts_node_child_by_field_name(node, field_name.ptr, @intCast(field_name.len));
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
    return .{ .start = start.row + 1, .end = end.row + 1 };
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

test "extract source handles supported Go subset" {
    const source =
        \\package proof
        \\
        \\const (
        \\    Alpha = 1
        \\    Beta = 2
        \\)
        \\
        \\var Gamma = 3
        \\
        \\func Zebra() {}
        \\
        \\type Service struct{}
        \\type Runner interface{ Run() }
        \\
        \\func (s Service) Method() {}
        \\
    ;

    var result = try extractSource(std.testing.allocator, "internal/proof.go", source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.provider.failure);
    try std.testing.expectEqual(@as(usize, 8), result.symbols.len);
    try std.testing.expectEqualStrings("Alpha", result.symbols[0].name);
    try std.testing.expectEqualStrings("Beta", result.symbols[1].name);
    try std.testing.expectEqualStrings("Gamma", result.symbols[2].name);
    try std.testing.expectEqualStrings("Method", result.symbols[3].name);
    try std.testing.expectEqualStrings("Runner", result.symbols[4].name);
    try std.testing.expectEqualStrings("Service", result.symbols[5].name);
    try std.testing.expectEqualStrings("Zebra", result.symbols[6].name);
    try std.testing.expectEqualStrings("proof", result.symbols[7].name);
    try std.testing.expectEqual(provider.SymbolKind.other, result.symbols[0].kind);
    try std.testing.expectEqual(provider.SymbolKind.variable, result.symbols[2].kind);
    try std.testing.expectEqual(provider.SymbolKind.method, result.symbols[3].kind);
    try std.testing.expectEqual(provider.SymbolKind.type, result.symbols[4].kind);
    try std.testing.expectEqual(provider.SymbolKind.function, result.symbols[6].kind);
    try std.testing.expectEqual(provider.SymbolKind.module, result.symbols[7].kind);
    try std.testing.expectEqualStrings(provider_name, result.symbols[0].provider_name);
    try expectLineRange(result.symbols[6], 10, 10);
}

test "extract source handles empty unsupported invalid and caveated inputs" {
    var empty = try extractSource(std.testing.allocator, "empty.go", "");
    defer empty.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, empty.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), empty.symbols.len);

    var unsupported = try extractSource(std.testing.allocator, "README.md", "package hidden\nfunc Hidden() {}\n");
    defer unsupported.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unsupported, unsupported.provider.failure);

    var broken = try extractSource(std.testing.allocator, "broken.go", "package proof\nfunc {");
    defer broken.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.failed, broken.provider.failure);

    const caveated_source =
        \\// Code generated by local proof; DO NOT EDIT.
        \\//go:build linux
        \\package proof
        \\
        \\import "C"
        \\
        \\func Visible() {}
        \\
    ;
    var caveated = try extractSource(std.testing.allocator, "caveated.go", caveated_source);
    defer caveated.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, caveated.provider.failure);
    try std.testing.expectEqualStrings("build tags, generated-file markers, package loading, and cgo are not evaluated", caveated.provider.caveats[3]);
}

fn expectRelationTarget(relations: []const provider.RelationCandidate, kind: provider.RelationKind, target: []const u8) !void {
    for (relations) |relation| {
        if (relation.kind == kind and relationTargetEquals(relation.target, target)) return;
    }
    return error.ExpectedRelationMissing;
}

fn relationTargetEquals(endpoint: provider.RelationEndpoint, expected: []const u8) bool {
    return switch (endpoint) {
        .file => |file| std.mem.eql(u8, file.path, expected),
        .current_symbol => |symbol| std.mem.eql(u8, symbol.name, expected),
        .report_symbol => |symbol| std.mem.eql(u8, symbol.name, expected),
        .unresolved, .external_string => |named| std.mem.eql(u8, named.value, expected),
    };
}

fn expectRelationOrder(relations: []const provider.RelationCandidate) !void {
    var index: usize = 1;
    while (index < relations.len) : (index += 1) {
        try std.testing.expect(provider.lessRelation({}, relations[index - 1], relations[index]) or !provider.lessRelation({}, relations[index], relations[index - 1]));
    }
}

fn expectRelationCaveat(caveats: []const []const u8, expected: []const u8) !void {
    for (caveats) |caveat| if (std.mem.eql(u8, caveat, expected)) return;
    return error.ExpectedCaveatMissing;
}

test "extract relations emits internal bounded Go syntax candidates" {
    const source =
        \\// Code generated by local proof; DO NOT EDIT.
        \\//go:build linux
        \\package proof
        \\
        \\import (
        \\    alias "example.com/worker"
        \\    . "example.com/dot"
        \\    _ "example.com/blank"
        \\    "C"
        \\)
        \\
        \\const LIMIT = 3
        \\type Service struct{}
        \\type Runner interface{ Run() }
        \\
        \\func helper() {}
        \\func (s Service) Serve() {
        \\    helper()
        \\    LIMIT
        \\    missingValue
        \\    alias.Make()
        \\    receiver.Field
        \\}
        \\
    ;

    var result = try extractRelationsSource(std.testing.allocator, "internal/relations.go", source, .{});
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.provider.failure);
    try std.testing.expectEqual(provider.Freshness.fresh, result.provider.freshness);
    try std.testing.expectEqualStrings(relation_provider_name, result.provider.name);
    try std.testing.expect(!result.cap_reached);
    try std.testing.expect(result.candidates.len > 0);
    try expectRelationOrder(result.candidates);

    try expectRelationTarget(result.candidates, .contains, "LIMIT");
    try expectRelationTarget(result.candidates, .contains, "Service");
    try expectRelationTarget(result.candidates, .contains, "Runner");
    try expectRelationTarget(result.candidates, .contains, "helper");
    try expectRelationTarget(result.candidates, .contains, "Serve");
    try expectRelationTarget(result.candidates, .import_include, "example.com/worker");
    try expectRelationTarget(result.candidates, .import_include, "example.com/dot");
    try expectRelationTarget(result.candidates, .import_include, "example.com/blank");
    try expectRelationTarget(result.candidates, .import_include, "C");
    try expectRelationTarget(result.candidates, .call, "helper");
    try expectRelationTarget(result.candidates, .call, "alias.Make");
    try expectRelationTarget(result.candidates, .reference, "LIMIT");
    try expectRelationTarget(result.candidates, .unresolved, "missingValue");
    try expectRelationTarget(result.candidates, .unknown, "receiver.Field");

    for (result.candidates) |relation| {
        try provider.validateRelationEndpoint(relation.source);
        try provider.validateRelationEndpoint(relation.target);
        try std.testing.expectEqual(provider.ProviderKind.relation, relation.provider.kind);
        try std.testing.expectEqual(provider.Failure.ok, relation.failure);
        try expectRelationCaveat(relation.caveats, "symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction");
        try expectRelationCaveat(relation.caveats, "Go relationship evidence is internal proof evidence only and is not admitted as a public capability claim in this feature");
    }
}

test "extract relations degrades and caps internal Go proof safely" {
    const source =
        \\package proof
        \\func one() {}
        \\func two() { one(); missingValue; receiver.Field }
        \\
    ;

    var unsupported = try extractRelationsSource(std.testing.allocator, "docs/relations.md", source, .{});
    defer unsupported.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unsupported, unsupported.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), unsupported.candidates.len);

    var failed = try extractRelationsSource(std.testing.allocator, "internal/broken.go", "package proof\nfunc {", .{});
    defer failed.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.failed, failed.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), failed.candidates.len);

    var unavailable = try extractRelationsSource(std.testing.allocator, "internal/unavailable.go", source, .{ .force_provider_unavailable = true });
    defer unavailable.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unavailable, unavailable.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), unavailable.candidates.len);

    var oversized = try extractRelationsSource(std.testing.allocator, "internal/oversized.go", source, .{ .max_source_bytes = 4 });
    defer oversized.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.skipped, oversized.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), oversized.candidates.len);

    var capped = try extractRelationsSource(std.testing.allocator, "internal/capped.go", source, .{ .max_candidates = 2 });
    defer capped.deinit(std.testing.allocator);
    try std.testing.expect(capped.cap_reached);
    try std.testing.expect(capped.omitted_count > 0);
    try std.testing.expectEqual(provider.Freshness.partial, capped.provider.freshness);
    try expectRelationCaveat(capped.provider.caveats, "relation candidate cap reached; emitted evidence is partial and deterministically truncated");
}
