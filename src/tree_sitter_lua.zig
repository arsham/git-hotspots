const std = @import("std");
const provider = @import("provider.zig");
const tree_sitter_common = @import("tree_sitter_common.zig");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_lua() *const c.TSLanguage;

pub const provider_name = "tree-sitter-lua";
pub const provider_version = "tree-sitter-core@v0.26.9/tree-sitter-lua@v0.5.0/lua-symbol-query-v1";
pub const relation_provider_name = "tree-sitter-lua-relations";
pub const relation_provider_version = "tree-sitter-core@v0.26.9/tree-sitter-lua@v0.5.0/lua-relation-proof-v1";
const query_fingerprint = "src/queries/lua-symbols.scm:lua-symbol-query-v1";
const max_file_bytes: u64 = 1024 * 1024;
const query_source = @embedFile("queries/lua-symbols.scm");

const ok_caveats = [_][]const u8{
    "current working-tree enrichment only; file-level Git evidence remains product truth",
    "supported subset: module roots, function declarations, colon methods, module-level local/global function assignments, module-level locals, stable table constructor fields, and stable dot table function assignments",
    "range convention: one-based inclusive lines; qualified Lua names and method names are bare terminal identifiers",
    "provider order: module symbol first, then deterministic source order by symbol node start byte",
    "module names are repo-relative .lua paths; package, require, runtime module resolution, metatables, LSP, and symbol history are out of scope",
    "dynamic table keys, dependency graphs, runtime execution, generated-source policy, scoring, and semantic moves are out of scope",
};
const unsupported_caveats = [_][]const u8{
    "provider unsupported: only repo-relative .lua files are parsed",
    "no parser diagnostics or source snippets exposed",
};
const unavailable_caveats = [_][]const u8{
    "current working-tree file unavailable or not a regular bounded file",
    "no parser diagnostics, source snippets, absolute paths, remotes, author identities, commit messages, or private repo names exposed",
};
const failed_caveats = [_][]const u8{
    "provider failed to parse supported Lua symbol evidence",
    "invalid or partial Lua source failed closed without parser diagnostics or source snippets",
};
const function_caveats = ok_caveats ++ [_][]const u8{
    "function declarations use bare terminal identifiers; qualified Lua names are out of scope",
};
const method_caveats = ok_caveats ++ [_][]const u8{
    "colon method classification is derived from method_index_expression; method names are bare identifiers",
};
const variable_caveats = ok_caveats ++ [_][]const u8{
    "module-level local declarations map to provider SymbolKind.variable",
};
const assigned_function_caveats = ok_caveats ++ [_][]const u8{
    "stable local or global anonymous function assignments map to provider SymbolKind.function by syntactic left-hand identifier only",
};
const constant_caveats = ok_caveats ++ [_][]const u8{
    "constant-like uppercase Lua names map to provider SymbolKind.other because no constant-specific kind exists",
};
const table_field_caveats = ok_caveats ++ [_][]const u8{
    "module-level table constructor fields map to provider SymbolKind.variable unless the value is a function",
};
const table_function_caveats = ok_caveats ++ [_][]const u8{
    "module-level table constructor fields and stable dot table assignments with function values map to provider SymbolKind.function",
};
const generated_caveats = ok_caveats ++ [_][]const u8{
    "generated-file markers are caveated only; generated-source policy is not evaluated by this provider",
};
const dynamic_table_caveats = ok_caveats ++ [_][]const u8{
    "dynamic bracket table assignments are skipped because runtime table keys are not deterministic symbols",
};
const metatable_caveats = ok_caveats ++ [_][]const u8{
    "metatable-heavy Lua is caveated; metamethod fields and runtime metatable behaviour are skipped",
};
const embedded_dsl_caveats = ok_caveats ++ [_][]const u8{
    "embedded DSL strings are caveated only; string contents are not parsed as Lua symbols",
};
const relation_ok_caveats = [_][]const u8{
    "candidate relation evidence only; file-level Git evidence remains product truth",
    "bounded Lua syntax evidence: contains, require-like imports, direct calls, table/member reference-like syntax, unresolved identifiers, and unknown relation-like syntax",
    "unresolved and external-string endpoints are caveated; no module loader, package.path, metatable, dynamic table, runtime mutation, generated-source, or semantic dependency identity is fabricated",
    "symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction",
};
const relation_unresolved_caveats = relation_ok_caveats ++ [_][]const u8{
    "target is unresolved by this bounded Lua syntax proof",
};
const relation_import_caveats = relation_ok_caveats ++ [_][]const u8{
    "require target is an external string; module loader, package.path, package.searchers, filesystem, and runtime module resolution are out of scope",
};
const relation_unknown_caveats = relation_ok_caveats ++ [_][]const u8{
    "Lua relation-like table, metatable, dynamic key, or callable syntax is present but cannot be classified safely by this proof",
};
const relation_cap_caveats = relation_ok_caveats ++ [_][]const u8{
    "relation candidate cap reached; emitted evidence is partial and deterministically truncated",
};
const relation_unsupported_caveats = [_][]const u8{
    "relation provider unsupported: only repo-relative .lua files are parsed by the Lua relation provider",
    "no parser diagnostics or source snippets exposed",
};
const relation_unavailable_caveats = [_][]const u8{
    "relation provider unavailable or current working-tree source was not available to the Lua relation provider",
    "no parser diagnostics, source snippets, absolute paths, remotes, author identities, commit messages, or private repo names exposed",
};
const relation_oversized_caveats = [_][]const u8{
    "Lua relation source skipped by bounded-size policy",
    "no source snippets or private path details exposed",
};
const relation_failed_caveats = [_][]const u8{
    "relation provider failed to parse supported Lua source",
    "invalid or partial Lua source failed closed without parser diagnostics or source snippets",
};

pub const Extraction = tree_sitter_common.Extraction;
pub const RelationExtraction = provider.RelationExtraction;
pub const max_relation_candidates: usize = 64;

pub const RelationOptions = struct {
    max_source_bytes: u64 = max_file_bytes,
    max_candidates: usize = max_relation_candidates,
    force_provider_unavailable: bool = false,
};

const DefinitionKind = enum {
    function,
    method,
    variable,
    table_field,
};

const CaveatKind = enum {
    module,
    function,
    method,
    variable,
    assigned_function,
    constant,
    table_field,
    table_function,
};

const SourceProfile = struct {
    generated: bool,
    dynamic_table_assignment_skip_count: usize,
    metatable_skip_count: usize,
    embedded_dsl: bool,
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
        for (self.candidates.items) |candidate| provider.freeRelationCandidate(self.allocator, candidate);
        self.candidates.deinit(self.allocator);
    }
};

const NamedEndpointTag = enum { unresolved, external_string };

pub fn isSupportedPath(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".lua");
}

pub fn extractPath(allocator: std.mem.Allocator, io: std.Io, repo_root: []const u8, repo_relative_path: []const u8) !Extraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!isSupportedPath(repo_relative_path)) {
        return extraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &unsupported_caveats, &.{});
    }

    const source = try tree_sitter_common.readBoundedFile(allocator, io, repo_root, repo_relative_path, max_file_bytes) orelse return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    defer allocator.free(source);

    return extractSource(allocator, repo_relative_path, source);
}

pub fn extractSource(allocator: std.mem.Allocator, repo_relative_path: []const u8, source: []const u8) !Extraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!isSupportedPath(repo_relative_path)) {
        return extraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &unsupported_caveats, &.{});
    }

    const parser = c.ts_parser_new() orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_lua())) return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});

    const source_len = std.math.cast(u32, source.len) orelse return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});

    const query = compileLuaQuery() catch return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_query_delete(query);

    const cursor = c.ts_query_cursor_new() orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_query_cursor_delete(cursor);

    var candidates: std.ArrayList(SymbolCandidate) = .empty;
    defer candidates.deinit(allocator);
    errdefer tree_sitter_common.freeCandidateSymbols(allocator, candidates.items);

    const profile = sourceProfile(source, root);

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
            if (std.mem.eql(u8, name, "lua.module")) {
                try appendCandidate(
                    allocator,
                    &candidates,
                    repo_relative_path,
                    repo_relative_path,
                    .module,
                    capture.node,
                    capture.node,
                    caveatsForModule(profile),
                );
            } else if (std.mem.eql(u8, name, "lua.function.definition")) {
                definition_node = capture.node;
                definition_kind = .function;
            } else if (std.mem.eql(u8, name, "lua.method.definition")) {
                definition_node = capture.node;
                definition_kind = .method;
            } else if (std.mem.eql(u8, name, "lua.variable.definition")) {
                definition_node = capture.node;
                definition_kind = .variable;
            } else if (std.mem.eql(u8, name, "lua.table.field.definition")) {
                definition_node = capture.node;
                definition_kind = .table_field;
            } else if (std.mem.eql(u8, name, "lua.definition.name")) {
                name_node = capture.node;
                has_name = true;
            }
        }

        if (definition_kind) |kind| {
            if (!has_name) continue;
            try appendDefinitionCandidate(allocator, &candidates, repo_relative_path, source, definition_node, name_node, kind, profile);
        }
    }

    std.mem.sort(SymbolCandidate, candidates.items, {}, lessCandidate);

    const symbols = try allocator.alloc(provider.CurrentSymbolEvidence, candidates.items.len);
    var symbols_owned = true;
    errdefer if (symbols_owned) allocator.free(symbols);
    for (candidates.items, 0..) |candidate, i| symbols[i] = candidate.symbol;
    candidates.clearRetainingCapacity();

    symbols_owned = false;
    return extraction(allocator, repo_relative_path, .ok, .fresh, .high, caveatsForModule(profile), symbols);
}

pub fn extractRelationsSource(allocator: std.mem.Allocator, repo_relative_path: []const u8, source: []const u8, options: RelationOptions) !RelationExtraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!isSupportedPath(repo_relative_path)) {
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

    if (!c.ts_parser_set_language(parser, tree_sitter_lua())) return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});

    const source_len = std.math.cast(u32, source.len) orelse return relationExtraction(allocator, repo_relative_path, .skipped, .unknown, .low, &relation_oversized_caveats, false, 0, &.{});
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});

    const query = compileLuaQuery() catch return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});
    defer c.ts_query_delete(query);

    const cursor = c.ts_query_cursor_new() orelse return relationExtraction(allocator, repo_relative_path, .failed, .unknown, .low, &relation_failed_caveats, false, 0, &.{});
    defer c.ts_query_cursor_delete(cursor);

    var definitions: std.ArrayList(DefinitionRecord) = .empty;
    defer definitions.deinit(allocator);

    const profile = sourceProfile(source, root);

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
            if (std.mem.eql(u8, name, "lua.function.definition")) {
                definition_node = capture.node;
                definition_kind = .function;
            } else if (std.mem.eql(u8, name, "lua.method.definition")) {
                definition_node = capture.node;
                definition_kind = .method;
            } else if (std.mem.eql(u8, name, "lua.variable.definition")) {
                definition_node = capture.node;
                definition_kind = .variable;
            } else if (std.mem.eql(u8, name, "lua.table.field.definition")) {
                definition_node = capture.node;
                definition_kind = .table_field;
            } else if (std.mem.eql(u8, name, "lua.definition.name")) {
                name_node = capture.node;
                has_name = true;
            }
        }

        if (definition_kind) |kind| {
            if (!has_name) continue;
            try appendRelationDefinitionRecord(allocator, &definitions, source, definition_node, name_node, kind, profile);
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

fn compileLuaQuery() !*c.TSQuery {
    var error_offset: u32 = 0;
    var error_type: c.TSQueryError = c.TSQueryErrorNone;
    return c.ts_query_new(
        tree_sitter_lua(),
        query_source.ptr,
        @intCast(query_source.len),
        &error_offset,
        &error_type,
    ) orelse error.QueryCompileFailed;
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
    return tree_sitter_common.makeExtractionWithConfig(allocator, provider_name, provider_version, query_fingerprint, repo_relative_path, failure, freshness, confidence, caveats, symbols);
}

fn appendDefinitionCandidate(
    allocator: std.mem.Allocator,
    candidates: *std.ArrayList(SymbolCandidate),
    path: []const u8,
    source: []const u8,
    definition_node: c.TSNode,
    name_node: c.TSNode,
    kind: DefinitionKind,
    profile: SourceProfile,
) !void {
    if (!isModuleLevelDefinition(definition_node)) return;

    const symbol_name = nodeSourceSlice(source, name_node) orelse return;
    switch (kind) {
        .function => try appendCandidate(allocator, candidates, path, symbol_name, .function, name_node, definition_node, caveatsForDefinition(.function, profile)),
        .method => try appendCandidate(allocator, candidates, path, symbol_name, .method, name_node, definition_node, caveatsForDefinition(.method, profile)),
        .variable => {
            if (nodeTypeIs(definition_node, "assignment_statement") and nodeTypeIs(c.ts_node_parent(definition_node), "variable_declaration")) return;
            const assigned_value = assignedSingleValueNode(definition_node);
            const symbol_kind: provider.SymbolKind = if (assigned_value) |value|
                if (nodeTypeIs(value, "function_definition")) .function else if (isConstantLikeName(symbol_name)) .other else .variable
            else if (isConstantLikeName(symbol_name)) .other else .variable;
            const caveat_kind: CaveatKind = if (symbol_kind == .function) .assigned_function else if (symbol_kind == .other) .constant else .variable;
            try appendCandidate(allocator, candidates, path, symbol_name, symbol_kind, name_node, definition_node, caveatsForDefinition(caveat_kind, profile));
        },
        .table_field => {
            if (!isModuleLevelStableTableDefinition(definition_node)) return;
            if (std.mem.startsWith(u8, symbol_name, "__")) return;
            const value = tableDefinitionValueNode(definition_node);
            const symbol_kind: provider.SymbolKind = if (nodeTypeIs(value, "function_definition")) .function else if (isConstantLikeName(symbol_name)) .other else .variable;
            const caveat_kind: CaveatKind = if (symbol_kind == .function) .table_function else if (symbol_kind == .other) .constant else .table_field;
            try appendCandidate(allocator, candidates, path, symbol_name, symbol_kind, name_node, definition_node, caveatsForDefinition(caveat_kind, profile));
        },
    }
}

fn appendRelationDefinitionRecord(
    allocator: std.mem.Allocator,
    definitions: *std.ArrayList(DefinitionRecord),
    source: []const u8,
    definition_node: c.TSNode,
    name_node: c.TSNode,
    kind: DefinitionKind,
    profile: SourceProfile,
) !void {
    if (!isModuleLevelDefinition(definition_node)) return;

    const symbol_name = nodeSourceSlice(source, name_node) orelse return;
    switch (kind) {
        .function => try appendDefinitionRecordUnchecked(allocator, definitions, symbol_name, .function, name_node, definition_node),
        .method => try appendDefinitionRecordUnchecked(allocator, definitions, symbol_name, .method, name_node, definition_node),
        .variable => {
            if (nodeTypeIs(definition_node, "assignment_statement") and nodeTypeIs(c.ts_node_parent(definition_node), "variable_declaration")) return;
            const assigned_value = assignedSingleValueNode(definition_node);
            const symbol_kind: provider.SymbolKind = if (assigned_value) |value|
                if (nodeTypeIs(value, "function_definition")) .function else if (isConstantLikeName(symbol_name)) .other else .variable
            else if (isConstantLikeName(symbol_name)) .other else .variable;
            try appendDefinitionRecordUnchecked(allocator, definitions, symbol_name, symbol_kind, name_node, definition_node);
        },
        .table_field => {
            if (!isModuleLevelStableTableDefinition(definition_node)) return;
            if (std.mem.startsWith(u8, symbol_name, "__")) return;
            const value = tableDefinitionValueNode(definition_node);
            const symbol_kind: provider.SymbolKind = if (nodeTypeIs(value, "function_definition")) .function else if (isConstantLikeName(symbol_name)) .other else .variable;
            try appendDefinitionRecordUnchecked(allocator, definitions, symbol_name, symbol_kind, name_node, definition_node);
        },
    }

    _ = profile;
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
            "lua module-level symbol containment",
            definition.start_byte,
            definition.end_byte,
            &relation_ok_caveats,
            .medium,
        );
    }
}

fn walkRelationSyntax(state: *RelationBuildState, node: c.TSNode) !void {
    if (nodeTypeIs(node, "function_call")) {
        try appendCallRelation(state, node);
    } else if (nodeTypeIs(node, "dot_index_expression") or nodeTypeIs(node, "bracket_index_expression")) {
        if (!isFunctionCallNameNode(node)) try appendUnknownRelation(state, node, "lua table/member reference-like syntax without table, metatable, or runtime resolution");
    } else if (nodeTypeIs(node, "identifier")) {
        try appendIdentifierRelation(state, node);
    }

    const child_count = c.ts_node_named_child_count(node);
    var child_index: u32 = 0;
    while (child_index < child_count) : (child_index += 1) try walkRelationSyntax(state, c.ts_node_named_child(node, child_index));
}

fn appendCallRelation(state: *RelationBuildState, node: c.TSNode) !void {
    const function_node = childByFieldName(node, "name");
    if (c.ts_node_is_null(function_node)) return;

    if (nodeTypeIs(function_node, "identifier")) {
        const target_name = nodeSourceSlice(state.source, function_node) orelse return;
        if (std.mem.eql(u8, target_name, "require")) {
            if (firstCallStringArgument(state.source, node)) |target| {
                const source_endpoint = try sourceEndpointForNode(state, node);
                errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);
                const target_endpoint = try makeNamedEndpoint(state.allocator, .external_string, target);
                errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);
                try appendRelationOwned(state, .import_include, .source_to_target, source_endpoint, target_endpoint, "lua require-like string syntax", c.ts_node_start_byte(node), c.ts_node_end_byte(node), &relation_import_caveats, .medium);
                return;
            }
        }

        const source_endpoint = try sourceEndpointForNode(state, node);
        errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);
        const target_endpoint = try targetEndpointForName(state, target_name);
        errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);
        const resolved = findDefinitionByName(state.definitions, target_name) != null;
        try appendRelationOwned(state, .call, .source_to_target, source_endpoint, target_endpoint, "lua direct call syntax", c.ts_node_start_byte(node), c.ts_node_end_byte(node), if (resolved) &relation_ok_caveats else &relation_unresolved_caveats, if (resolved) .medium else .low);
    } else if (nodeTypeIs(function_node, "dot_index_expression") or nodeTypeIs(function_node, "method_index_expression")) {
        const target_name = nodeSourceSlice(state.source, function_node) orelse return;
        const source_endpoint = try sourceEndpointForNode(state, node);
        errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);
        const target_endpoint = try makeNamedEndpoint(state.allocator, .unresolved, target_name);
        errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);
        try appendRelationOwned(state, .call, .source_to_target, source_endpoint, target_endpoint, "lua table or method call syntax without receiver, metatable, or runtime resolution", c.ts_node_start_byte(node), c.ts_node_end_byte(node), &relation_unresolved_caveats, .low);
    } else {
        try appendUnknownRelation(state, function_node, "lua callable syntax not safely classified");
    }
}

fn appendUnknownRelation(state: *RelationBuildState, node: c.TSNode, basis: []const u8) !void {
    const target = nodeSourceSlice(state.source, node) orelse return;
    const source_endpoint = try sourceEndpointForNode(state, node);
    errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);
    const target_endpoint = try makeNamedEndpoint(state.allocator, .unresolved, target);
    errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);
    try appendRelationOwned(state, .unknown, .none, source_endpoint, target_endpoint, basis, c.ts_node_start_byte(node), c.ts_node_end_byte(node), &relation_unknown_caveats, .low);
}

fn appendIdentifierRelation(state: *RelationBuildState, node: c.TSNode) !void {
    if (isDefinitionName(state.definitions, node)) return;
    if (isFunctionCallNameNode(node)) return;
    if (isInsideIndexExpression(node)) return;
    if (isTableFieldName(node)) return;
    if (isParameterIdentifier(node)) return;

    const name = nodeSourceSlice(state.source, node) orelse return;
    if (isLuaBuiltinOrKeywordLikeIdentifier(name)) return;

    const source_endpoint = try sourceEndpointForNode(state, node);
    errdefer provider.freeRelationEndpoint(state.allocator, source_endpoint);
    const target_endpoint = try targetEndpointForName(state, name);
    errdefer provider.freeRelationEndpoint(state.allocator, target_endpoint);
    const resolved = findDefinitionByName(state.definitions, name) != null;
    try appendRelationOwned(state, if (resolved) .reference else .unresolved, .source_to_target, source_endpoint, target_endpoint, "lua identifier reference syntax", c.ts_node_start_byte(node), c.ts_node_end_byte(node), if (resolved) &relation_ok_caveats else &relation_unresolved_caveats, if (resolved) .medium else .low);
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

fn firstCallStringArgument(source: []const u8, node: c.TSNode) ?[]const u8 {
    const arguments = childByFieldName(node, "arguments");
    if (c.ts_node_is_null(arguments)) return null;
    if (nodeTypeIs(arguments, "string")) return unquoteLuaString(nodeSourceSlice(source, arguments) orelse return null);

    const child_count = c.ts_node_named_child_count(arguments);
    var child_index: u32 = 0;
    while (child_index < child_count) : (child_index += 1) {
        const child = c.ts_node_named_child(arguments, child_index);
        if (nodeTypeIs(child, "string")) return unquoteLuaString(nodeSourceSlice(source, child) orelse return null);
    }
    return null;
}

fn unquoteLuaString(text: []const u8) ?[]const u8 {
    const trimmed = std.mem.trim(u8, text, " \t\r\n");
    if (trimmed.len >= 2 and ((trimmed[0] == '"' and trimmed[trimmed.len - 1] == '"') or (trimmed[0] == '\'' and trimmed[trimmed.len - 1] == '\''))) {
        return trimmed[1 .. trimmed.len - 1];
    }
    if (trimmed.len >= 4 and std.mem.startsWith(u8, trimmed, "[[") and std.mem.endsWith(u8, trimmed, "]]")) {
        return trimmed[2 .. trimmed.len - 2];
    }
    return null;
}

fn isFunctionCallNameNode(node: c.TSNode) bool {
    var current = node;
    while (true) {
        const parent = c.ts_node_parent(current);
        if (c.ts_node_is_null(parent)) return false;
        if (nodeTypeIs(parent, "function_call")) {
            const name = childByFieldName(parent, "name");
            return !c.ts_node_is_null(name) and c.ts_node_eq(name, current);
        }
        if (nodeTypeIs(parent, "chunk") or nodeTypeIs(parent, "block") or nodeTypeIs(parent, "function_declaration") or nodeTypeIs(parent, "function_definition")) return false;
        current = parent;
    }
}

fn isInsideIndexExpression(node: c.TSNode) bool {
    var current = node;
    while (true) {
        const parent = c.ts_node_parent(current);
        if (c.ts_node_is_null(parent)) return false;
        if (nodeTypeIs(parent, "dot_index_expression") or nodeTypeIs(parent, "bracket_index_expression") or nodeTypeIs(parent, "method_index_expression")) return true;
        if (nodeTypeIs(parent, "chunk") or nodeTypeIs(parent, "block") or nodeTypeIs(parent, "function_declaration") or nodeTypeIs(parent, "function_definition") or nodeTypeIs(parent, "function_call")) return false;
        current = parent;
    }
}

fn isTableFieldName(node: c.TSNode) bool {
    const parent = c.ts_node_parent(node);
    if (c.ts_node_is_null(parent) or !nodeTypeIs(parent, "field")) return false;
    const name = childByFieldName(parent, "name");
    return !c.ts_node_is_null(name) and c.ts_node_eq(name, node);
}

fn isParameterIdentifier(node: c.TSNode) bool {
    var current = node;
    while (true) {
        const parent = c.ts_node_parent(current);
        if (c.ts_node_is_null(parent)) return false;
        if (nodeTypeIs(parent, "parameters") or nodeTypeIs(parent, "variable_list")) return true;
        if (nodeTypeIs(parent, "function_declaration") or nodeTypeIs(parent, "function_definition") or nodeTypeIs(parent, "chunk") or nodeTypeIs(parent, "block")) return false;
        current = parent;
    }
}

fn isLuaBuiltinOrKeywordLikeIdentifier(name: []const u8) bool {
    inline for (.{
        "nil",      "true",  "false",  "and",       "or",    "not",   "self",  "_G",     "_ENV",
        "assert",   "error", "ipairs", "next",      "pairs", "pcall", "print", "select", "tonumber",
        "tostring", "type",  "xpcall", "coroutine", "debug", "io",    "math",  "os",     "package",
        "string",   "table", "utf8",
    }) |builtin| {
        if (std.mem.eql(u8, name, builtin)) return true;
    }
    return false;
}

fn lessDefinitionRecord(_: void, lhs: DefinitionRecord, rhs: DefinitionRecord) bool {
    if (lhs.start_byte != rhs.start_byte) return lhs.start_byte < rhs.start_byte;
    if (lhs.end_byte != rhs.end_byte) return lhs.end_byte < rhs.end_byte;
    return std.mem.order(u8, lhs.name, rhs.name) == .lt;
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

fn caveatsForModule(profile: SourceProfile) []const []const u8 {
    if (profile.generated) return &generated_caveats;
    if (profile.metatable_skip_count > 0) return &metatable_caveats;
    if (profile.dynamic_table_assignment_skip_count > 0) return &dynamic_table_caveats;
    if (profile.embedded_dsl) return &embedded_dsl_caveats;
    return &ok_caveats;
}

fn caveatsForDefinition(kind: CaveatKind, profile: SourceProfile) []const []const u8 {
    if (profile.generated) return &generated_caveats;
    if (profile.metatable_skip_count > 0) return &metatable_caveats;
    if (profile.dynamic_table_assignment_skip_count > 0) return &dynamic_table_caveats;
    if (profile.embedded_dsl) return &embedded_dsl_caveats;
    return switch (kind) {
        .module => &ok_caveats,
        .function => &function_caveats,
        .method => &method_caveats,
        .variable => &variable_caveats,
        .assigned_function => &assigned_function_caveats,
        .constant => &constant_caveats,
        .table_field => &table_field_caveats,
        .table_function => &table_function_caveats,
    };
}

fn isModuleLevelDefinition(node: c.TSNode) bool {
    var current = node;
    while (true) {
        const parent = c.ts_node_parent(current);
        if (c.ts_node_is_null(parent)) return false;
        if (nodeTypeIs(parent, "chunk")) return true;
        if (nodeTypeIs(parent, "block") or nodeTypeIs(parent, "function_declaration") or nodeTypeIs(parent, "function_definition")) return false;
        current = parent;
    }
}

fn isModuleLevelStableTableDefinition(node: c.TSNode) bool {
    if (nodeTypeIs(node, "assignment_statement")) return assignedSingleValueNode(node) != null;
    return isModuleLevelTableField(node);
}

fn isModuleLevelTableField(node: c.TSNode) bool {
    const table = c.ts_node_parent(node);
    if (c.ts_node_is_null(table) or !nodeTypeIs(table, "table_constructor")) return false;

    const table_owner = c.ts_node_parent(table);
    if (!c.ts_node_is_null(table_owner) and nodeTypeIs(table_owner, "field")) return false;

    return true;
}

fn tableDefinitionValueNode(node: c.TSNode) c.TSNode {
    if (nodeTypeIs(node, "assignment_statement")) return assignedSingleValueNode(node) orelse unreachable;
    return childByFieldName(node, "value");
}

fn assignedSingleValueNode(definition_node: c.TSNode) ?c.TSNode {
    const assignment = if (nodeTypeIs(definition_node, "assignment_statement"))
        definition_node
    else
        firstNamedChildOfType(definition_node, "assignment_statement") orelse return null;

    const variables = firstNamedChildOfType(assignment, "variable_list") orelse return null;
    const expressions = firstNamedChildOfType(assignment, "expression_list") orelse return null;
    if (c.ts_node_named_child_count(variables) != 1) return null;
    if (c.ts_node_named_child_count(expressions) == 0) return null;
    return c.ts_node_named_child(expressions, 0);
}

fn firstNamedChildOfType(node: c.TSNode, expected: []const u8) ?c.TSNode {
    const child_count = c.ts_node_named_child_count(node);
    var child_index: u32 = 0;
    while (child_index < child_count) : (child_index += 1) {
        const child = c.ts_node_named_child(node, child_index);
        if (nodeTypeIs(child, expected)) return child;
    }
    return null;
}

fn sourceProfile(source: []const u8, root: c.TSNode) SourceProfile {
    return .{
        .generated = hasGeneratedMarker(source),
        .dynamic_table_assignment_skip_count = countModuleLevelDynamicTableAssignments(root),
        .metatable_skip_count = countMetatableSkips(source, root),
        .embedded_dsl = hasEmbeddedDslMarker(source),
    };
}

fn countModuleLevelDynamicTableAssignments(root: c.TSNode) usize {
    var count: usize = 0;
    countModuleLevelDynamicTableAssignmentsInner(root, &count);
    return count;
}

fn countModuleLevelDynamicTableAssignmentsInner(node: c.TSNode, count: *usize) void {
    if (nodeTypeIs(node, "assignment_statement") and isModuleLevelDefinition(node)) {
        const variables = firstNamedChildOfType(node, "variable_list");
        if (variables) |variable_list| {
            const child_count = c.ts_node_named_child_count(variable_list);
            var child_index: u32 = 0;
            while (child_index < child_count) : (child_index += 1) {
                if (nodeTypeIs(c.ts_node_named_child(variable_list, child_index), "bracket_index_expression")) count.* += 1;
            }
        }
    }

    const child_count = c.ts_node_named_child_count(node);
    var child_index: u32 = 0;
    while (child_index < child_count) : (child_index += 1) countModuleLevelDynamicTableAssignmentsInner(c.ts_node_named_child(node, child_index), count);
}

fn countMetatableSkips(source: []const u8, root: c.TSNode) usize {
    var count: usize = 0;
    countMetatableSkipsInner(source, root, &count);
    return count;
}

fn countMetatableSkipsInner(source: []const u8, node: c.TSNode, count: *usize) void {
    if (nodeTypeIs(node, "function_call")) {
        const name = childByFieldName(node, "name");
        const name_source = nodeSourceSlice(source, name) orelse "";
        if (std.mem.eql(u8, name_source, "setmetatable")) count.* += 1;
    } else if (nodeTypeIs(node, "field")) {
        const name = childByFieldName(node, "name");
        const name_source = nodeSourceSlice(source, name) orelse "";
        if (std.mem.startsWith(u8, name_source, "__")) count.* += 1;
    }

    const child_count = c.ts_node_named_child_count(node);
    var child_index: u32 = 0;
    while (child_index < child_count) : (child_index += 1) countMetatableSkipsInner(source, c.ts_node_named_child(node, child_index), count);
}

fn hasEmbeddedDslMarker(source: []const u8) bool {
    return std.mem.indexOf(u8, source, "embedded DSL") != null or
        std.mem.indexOf(u8, source, "SELECT ") != null or
        std.mem.indexOf(u8, source, "{%") != null;
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

fn childByFieldName(node: c.TSNode, comptime field_name: []const u8) c.TSNode {
    return c.ts_node_child_by_field_name(node, field_name.ptr, @intCast(field_name.len));
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
    if (c.ts_node_is_null(node)) return null;
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

fn expectRelationTarget(relations: []const provider.RelationCandidate, kind: provider.RelationKind, target: []const u8) !void {
    for (relations) |relation| {
        if (relation.kind == kind and std.mem.eql(u8, endpointName(relation.target), target)) return;
    }
    return error.ExpectedRelationTarget;
}

fn expectRelationOrder(relations: []const provider.RelationCandidate) !void {
    var index: usize = 1;
    while (index < relations.len) : (index += 1) {
        try std.testing.expect(provider.lessRelation({}, relations[index - 1], relations[index]) or !provider.lessRelation({}, relations[index], relations[index - 1]));
    }
}

fn endpointName(endpoint: provider.RelationEndpoint) []const u8 {
    return switch (endpoint) {
        .file => |file| file.path,
        .current_symbol => |symbol| symbol.name,
        .report_symbol => |symbol| symbol.name,
        .unresolved, .external_string => |named| named.value,
    };
}

test "extract relations emits bounded Lua syntax candidates" {
    const source =
        \\local helper_value = 1
        \\local exports = {
        \\  answer = 42,
        \\  build = function(input)
        \\    return input + helper_value
        \\  end,
        \\}
        \\
        \\local loaded = require("demo.worker")
        \\local unknown_module = require(module_name)
        \\
        \\local function helper()
        \\  return exports.answer
        \\end
        \\
        \\function exports:run()
        \\  helper()
        \\  missing_call()
        \\  local observed = missing_value
        \\  exports.build(helper_value)
        \\  exports[dynamic_key] = true
        \\  setmetatable(exports, {})
        \\end
        \\
        \\return exports
        \\
    ;

    var result = try extractRelationsSource(std.testing.allocator, "lua/relations.lua", source, .{});
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.ProviderKind.relation, result.provider.kind);
    try std.testing.expectEqual(provider.Failure.ok, result.provider.failure);
    try std.testing.expectEqual(provider.Freshness.fresh, result.provider.freshness);
    try std.testing.expectEqualStrings(relation_provider_name, result.provider.name);
    try std.testing.expect(result.candidates.len > 0);
    try std.testing.expect(!result.cap_reached);
    try expectRelationOrder(result.candidates);
    try expectCaveat(result.provider.caveats, "bounded Lua syntax evidence: contains, require-like imports, direct calls, table/member reference-like syntax, unresolved identifiers, and unknown relation-like syntax");

    try expectRelationTarget(result.candidates, .contains, "helper_value");
    try expectRelationTarget(result.candidates, .contains, "exports");
    try expectRelationTarget(result.candidates, .contains, "answer");
    try expectRelationTarget(result.candidates, .contains, "build");
    try expectRelationTarget(result.candidates, .contains, "helper");
    try expectRelationTarget(result.candidates, .contains, "run");
    try expectRelationTarget(result.candidates, .import_include, "demo.worker");
    try expectRelationTarget(result.candidates, .reference, "helper_value");
    try expectRelationTarget(result.candidates, .call, "helper");
    try expectRelationTarget(result.candidates, .call, "missing_call");
    try expectRelationTarget(result.candidates, .unresolved, "missing_value");
    try expectRelationTarget(result.candidates, .unknown, "exports.answer");
    try expectRelationTarget(result.candidates, .unknown, "exports[dynamic_key]");

    for (result.candidates) |relation| {
        try provider.validateRelationEndpoint(relation.source);
        try provider.validateRelationEndpoint(relation.target);
        try std.testing.expectEqual(provider.ProviderKind.relation, relation.provider.kind);
        try std.testing.expectEqual(provider.Failure.ok, relation.failure);
        try expectCaveat(relation.caveats, "symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction");
        try expectCaveat(relation.caveats, "bounded Lua syntax evidence: contains, require-like imports, direct calls, table/member reference-like syntax, unresolved identifiers, and unknown relation-like syntax");
    }
}

test "extract relations degrades and caps Lua proof safely" {
    const source =
        \\local one = 1
        \\local two = 2
        \\local function call()
        \\  local observed = one + two
        \\  missing()
        \\end
        \\
    ;

    var unsupported = try extractRelationsSource(std.testing.allocator, "docs/relations.md", source, .{});
    defer unsupported.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unsupported, unsupported.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), unsupported.candidates.len);

    var failed = try extractRelationsSource(std.testing.allocator, "lua/broken.lua", "local function broken(\n  return 1\n", .{});
    defer failed.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.failed, failed.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), failed.candidates.len);

    var unavailable = try extractRelationsSource(std.testing.allocator, "lua/unavailable.lua", source, .{ .force_provider_unavailable = true });
    defer unavailable.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unavailable, unavailable.provider.failure);

    var oversized = try extractRelationsSource(std.testing.allocator, "lua/oversized.lua", source, .{ .max_source_bytes = 4 });
    defer oversized.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.skipped, oversized.provider.failure);

    var capped = try extractRelationsSource(std.testing.allocator, "lua/capped.lua", source, .{ .max_candidates = 2 });
    defer capped.deinit(std.testing.allocator);
    try std.testing.expect(capped.cap_reached);
    try std.testing.expect(capped.omitted_count > 0);
    try std.testing.expectEqual(provider.Freshness.partial, capped.provider.freshness);
    try expectCaveat(capped.provider.caveats, "relation candidate cap reached; emitted evidence is partial and deterministically truncated");

    try std.testing.expectError(error.InvalidRepoRelativePath, extractRelationsSource(std.testing.allocator, "../private/relations.lua", source, .{}));
}

test "extract source handles supported Lua subset in source order" {
    const source =
        \\-- Module comment: table-like words are not exposed.
        \\local CONFIG = "markdown | value"
        \\local mutable_value = 2
        \\local exports = {
        \\  answer = 42,
        \\  build = function(input)
        \\    local ignored_inner = input
        \\    return ignored_inner
        \\  end,
        \\  Nested = {
        \\    skipped = function()
        \\      return "not module-level"
        \\    end,
        \\  },
        \\}
        \\
        \\local function local_worker()
        \\  local inside = function()
        \\    return "inside"
        \\  end
        \\  return inside()
        \\end
        \\
        \\function exports.make_thing()
        \\  return exports.answer
        \\end
        \\
        \\function exports:run()
        \\  return local_worker()
        \\end
        \\
        \\return exports
        \\
    ;

    var result = try extractSource(std.testing.allocator, "lua/supported_subset.lua", source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.provider.failure);
    try std.testing.expectEqual(@as(usize, 10), result.symbols.len);
    try expectSymbol(result.symbols[0], "lua/supported_subset.lua", .module, 1, 33);
    try expectSymbol(result.symbols[1], "CONFIG", .other, 2, 2);
    try expectSymbol(result.symbols[2], "mutable_value", .variable, 3, 3);
    try expectSymbol(result.symbols[3], "exports", .variable, 4, 15);
    try expectSymbol(result.symbols[4], "answer", .variable, 5, 5);
    try expectSymbol(result.symbols[5], "build", .function, 6, 9);
    try expectSymbol(result.symbols[6], "Nested", .variable, 10, 14);
    try expectSymbol(result.symbols[7], "local_worker", .function, 17, 22);
    try expectSymbol(result.symbols[8], "make_thing", .function, 24, 26);
    try expectSymbol(result.symbols[9], "run", .method, 28, 30);
    try expectNoSymbol(result.symbols, "ignored_inner");
    try expectNoSymbol(result.symbols, "inside");
    try expectNoSymbol(result.symbols, "skipped");
    try expectCaveat(result.symbols[1].caveats, "constant-like uppercase Lua names map to provider SymbolKind.other because no constant-specific kind exists");
    try expectCaveat(result.symbols[5].caveats, "module-level table constructor fields and stable dot table assignments with function values map to provider SymbolKind.function");
    try expectCaveat(result.symbols[9].caveats, "colon method classification is derived from method_index_expression; method names are bare identifiers");
}

test "extract source handles Lua assignments caveats and failures" {
    const assignments_source =
        \\function bare_global()
        \\  return 1
        \\end
        \\
        \\local local_assigned = function(value)
        \\  return value
        \\end
        \\
        \\global_assigned = function()
        \\  return local_assigned(1)
        \\end
        \\
    ;
    var assignments = try extractSource(std.testing.allocator, "lua/assignments.lua", assignments_source);
    defer assignments.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, assignments.provider.failure);
    try std.testing.expectEqual(@as(usize, 4), assignments.symbols.len);
    try expectSymbol(assignments.symbols[1], "bare_global", .function, 1, 3);
    try expectSymbol(assignments.symbols[2], "local_assigned", .function, 5, 7);
    try expectSymbol(assignments.symbols[3], "global_assigned", .function, 9, 11);
    try expectCaveat(assignments.symbols[2].caveats, "stable local or global anonymous function assignments map to provider SymbolKind.function by syntactic left-hand identifier only");

    var empty = try extractSource(std.testing.allocator, "lua/empty.lua", "");
    defer empty.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, empty.provider.failure);
    try std.testing.expectEqual(@as(usize, 1), empty.symbols.len);
    try expectSymbol(empty.symbols[0], "lua/empty.lua", .module, 1, 1);

    var unsupported = try extractSource(std.testing.allocator, "README.md", "local hidden = true\n");
    defer unsupported.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unsupported, unsupported.provider.failure);

    var broken = try extractSource(std.testing.allocator, "lua/broken.lua", "local function broken(\n  return 1\n");
    defer broken.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.failed, broken.provider.failure);

    const generated_source =
        \\-- Code generated by fixture; DO NOT EDIT.
        \\local AUTO_VALUE = 1
        \\local generated = {
        \\  make = function()
        \\    return AUTO_VALUE
        \\  end,
        \\}
        \\
    ;
    var generated = try extractSource(std.testing.allocator, "lua/generated.lua", generated_source);
    defer generated.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, generated.provider.failure);
    try expectCaveat(generated.provider.caveats, "generated-file markers are caveated only; generated-source policy is not evaluated by this provider");

    const dynamic_source =
        \\local exports = {}
        \\local dynamic_name = "run"
        \\exports[dynamic_name] = function()
        \\  return true
        \\end
        \\exports.static = function()
        \\  return false
        \\end
        \\return exports
        \\
    ;
    var dynamic = try extractSource(std.testing.allocator, "lua/dynamic.lua", dynamic_source);
    defer dynamic.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, dynamic.provider.failure);
    try expectNoSymbol(dynamic.symbols, "run");
    try expectCaveat(dynamic.provider.caveats, "dynamic bracket table assignments are skipped because runtime table keys are not deterministic symbols");

    try std.testing.expectError(error.InvalidRepoRelativePath, extractSource(std.testing.allocator, "../private/source.lua", "local hidden = true\n"));
}
