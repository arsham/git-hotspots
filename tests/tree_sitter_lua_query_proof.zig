const std = @import("std");
const provider = @import("provider");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_lua() *const c.TSLanguage;

const query_source = @embedFile("fixtures/tree_sitter_lua_query/lua-symbols.scm");
const supported_source = @embedFile("fixtures/tree_sitter_lua_query/supported_subset.lua");
const assignments_source = @embedFile("fixtures/tree_sitter_lua_query/assignments.lua");
const dynamic_table_assignment_source = @embedFile("fixtures/tree_sitter_lua_query/dynamic_table_assignment.lua");
const metatable_heavy_source = @embedFile("fixtures/tree_sitter_lua_query/metatable_heavy.lua");
const embedded_dsl_source = @embedFile("fixtures/tree_sitter_lua_query/embedded_dsl.lua");
const generated_source = @embedFile("fixtures/tree_sitter_lua_query/generated.lua");
const invalid_partial_source = @embedFile("fixtures/tree_sitter_lua_query/invalid_partial.lua");
const empty_source = @embedFile("fixtures/tree_sitter_lua_query/empty.lua");
const unsupported_source = @embedFile("fixtures/tree_sitter_lua_query/unsupported.md");

const provider_name = "tree-sitter-lua-query-proof";
const query_version = "lua-symbol-query-v1";
const provider_version = "tree-sitter-core@v0.26.9/tree-sitter-lua@v0.5.0/lua-symbol-query-v1";
const query_fingerprint = "tests/fixtures/tree_sitter_lua_query/lua-symbols.scm:lua-symbol-query-v1";
const expected_capture_names = [_][]const u8{
    "lua.module",
    "lua.definition.name",
    "lua.function.definition",
    "lua.method.definition",
    "lua.variable.definition",
    "lua.table.field.definition",
    "lua.comment",
};

const supported_caveats = [_][]const u8{
    "test-only in-memory Tree-sitter Lua query proof",
    "Lua grammar v0.5.0; query version: " ++ query_version,
    "project-owned query asset: tests/fixtures/tree_sitter_lua_query/lua-symbols.scm",
    "range convention: one-based inclusive line range from the symbol node",
    "ordering convention: deterministic source order by symbol node start byte; the module symbol is first",
    "module names are repo-relative .lua paths; package, require, and runtime module-resolution analysis are out of scope",
    "comments are captured only for count evidence; comment text is not exposed",
    "runtime Lua --symbols output is not implemented by this proof",
    provider.CurrentSymbolEvidence.semantics,
};
const unsupported_caveats = [_][]const u8{
    "unsupported path: only repo-relative .lua files are Lua query candidates",
    "no Lua parser was run for the unsupported path",
};
const failed_caveats = [_][]const u8{
    "parse failed before safe Lua query symbol proof completed",
    "no parser diagnostics or source snippets exposed",
};
const function_caveats = supported_caveats ++ [_][]const u8{
    "function declarations use bare terminal identifiers; qualified Lua names are out of scope",
};
const method_caveats = supported_caveats ++ [_][]const u8{
    "colon method classification is derived from method_index_expression; method names are bare identifiers",
};
const variable_caveats = supported_caveats ++ [_][]const u8{
    "module-level local declarations map to provider SymbolKind.variable",
};
const assigned_function_caveats = supported_caveats ++ [_][]const u8{
    "stable local or global anonymous function assignments map to provider SymbolKind.function by syntactic left-hand identifier only",
};
const constant_caveats = supported_caveats ++ [_][]const u8{
    "constant-like uppercase Lua names map to provider SymbolKind.other because no constant-specific kind exists",
};
const table_field_caveats = supported_caveats ++ [_][]const u8{
    "module-level table constructor fields map to provider SymbolKind.variable unless the value is a function",
};
const table_function_caveats = supported_caveats ++ [_][]const u8{
    "module-level table constructor fields and stable dot table assignments with function values map to provider SymbolKind.function",
};
const generated_caveats = supported_caveats ++ [_][]const u8{
    "generated-file markers are caveated only; generated-source policy is not evaluated by this proof",
};
const dynamic_table_caveats = supported_caveats ++ [_][]const u8{
    "dynamic bracket table assignments are skipped because runtime table keys are not deterministic symbols",
};
const metatable_caveats = supported_caveats ++ [_][]const u8{
    "metatable-heavy Lua is caveated; metamethod fields and runtime metatable behaviour are skipped",
};
const embedded_dsl_caveats = supported_caveats ++ [_][]const u8{
    "embedded DSL strings are caveated only; string contents are not parsed as Lua symbols",
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

pub const SymbolExtractionResult = struct {
    provider: provider.ProviderEvidence,
    failure: provider.Failure,
    symbols: []provider.CurrentSymbolEvidence,
    caveats: []const []const u8,
    comment_capture_count: usize = 0,
    dynamic_table_assignment_skip_count: usize = 0,
    metatable_skip_count: usize = 0,
    embedded_dsl_caveated: bool = false,

    pub fn deinit(self: *SymbolExtractionResult, allocator: std.mem.Allocator) void {
        if (self.symbols.len > 0) allocator.free(self.symbols);
        self.* = undefined;
    }
};

pub fn extractLuaQuerySymbols(
    allocator: std.mem.Allocator,
    repo_relative_path: []const u8,
    source: []const u8,
) !SymbolExtractionResult {
    return extractLuaQuerySymbolsWithProvider(allocator, provider_name, repo_relative_path, source);
}

pub fn extractLuaQuerySymbolsWithProvider(
    allocator: std.mem.Allocator,
    proof_provider_name: []const u8,
    repo_relative_path: []const u8,
    source: []const u8,
) !SymbolExtractionResult {
    try provider.validateRepoRelativePath(repo_relative_path);

    if (!std.mem.endsWith(u8, repo_relative_path, ".lua")) {
        return extractionResult(proof_provider_name, repo_relative_path, .unsupported, .unknown, .unknown, &unsupported_caveats, &.{});
    }

    const parser = c.ts_parser_new() orelse return failedResult(proof_provider_name, repo_relative_path);
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_lua())) return failedResult(proof_provider_name, repo_relative_path);

    const source_len = std.math.cast(u32, source.len) orelse return failedResult(proof_provider_name, repo_relative_path);
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return failedResult(proof_provider_name, repo_relative_path);
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return failedResult(proof_provider_name, repo_relative_path);

    const query = try compileLuaQuery();
    defer c.ts_query_delete(query);

    const cursor = c.ts_query_cursor_new() orelse return failedResult(proof_provider_name, repo_relative_path);
    defer c.ts_query_cursor_delete(cursor);

    var candidates: std.ArrayList(SymbolCandidate) = .empty;
    defer candidates.deinit(allocator);

    const profile = sourceProfile(source, root);
    var comment_capture_count: usize = 0;

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
                    proof_provider_name,
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
            } else if (std.mem.eql(u8, name, "lua.comment")) {
                comment_capture_count += 1;
            }
        }

        if (definition_kind) |kind| {
            if (!has_name) continue;
            try appendDefinitionCandidate(allocator, &candidates, proof_provider_name, repo_relative_path, source, definition_node, name_node, kind, profile);
        }
    }

    std.mem.sort(SymbolCandidate, candidates.items, {}, lessCandidate);

    var symbols: std.ArrayList(provider.CurrentSymbolEvidence) = .empty;
    errdefer symbols.deinit(allocator);
    for (candidates.items) |candidate| try symbols.append(allocator, candidate.symbol);

    var extracted = extractionResult(proof_provider_name, repo_relative_path, .ok, .fresh, .high, caveatsForModule(profile), try symbols.toOwnedSlice(allocator));
    extracted.comment_capture_count = comment_capture_count;
    extracted.dynamic_table_assignment_skip_count = profile.dynamic_table_assignment_skip_count;
    extracted.metatable_skip_count = profile.metatable_skip_count;
    extracted.embedded_dsl_caveated = profile.embedded_dsl;
    return extracted;
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

fn extractionResult(
    proof_provider_name: []const u8,
    repo_relative_path: []const u8,
    failure: provider.Failure,
    freshness: provider.Freshness,
    confidence: provider.Confidence,
    caveats: []const []const u8,
    symbols: []provider.CurrentSymbolEvidence,
) SymbolExtractionResult {
    return .{
        .provider = .{
            .name = proof_provider_name,
            .kind = .symbol,
            .version = provider_version,
            .config_fingerprint = query_fingerprint,
            .input = .{ .identity = repo_relative_path },
            .freshness = freshness,
            .failure = failure,
            .confidence = confidence,
            .caveats = caveats,
            .provenance = .{ .provider_name = proof_provider_name, .input_identity = repo_relative_path },
        },
        .failure = failure,
        .symbols = symbols,
        .caveats = caveats,
    };
}

fn failedResult(proof_provider_name: []const u8, repo_relative_path: []const u8) SymbolExtractionResult {
    return extractionResult(proof_provider_name, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
}

fn appendDefinitionCandidate(
    allocator: std.mem.Allocator,
    candidates: *std.ArrayList(SymbolCandidate),
    proof_provider_name: []const u8,
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
        .function => try appendCandidate(allocator, candidates, proof_provider_name, path, symbol_name, .function, name_node, definition_node, caveatsForDefinition(.function, profile)),
        .method => try appendCandidate(allocator, candidates, proof_provider_name, path, symbol_name, .method, name_node, definition_node, caveatsForDefinition(.method, profile)),
        .variable => {
            if (nodeTypeIs(definition_node, "assignment_statement") and nodeTypeIs(c.ts_node_parent(definition_node), "variable_declaration")) return;
            const assigned_value = assignedSingleValueNode(definition_node);
            const symbol_kind: provider.SymbolKind = if (assigned_value) |value|
                if (nodeTypeIs(value, "function_definition")) .function else if (isConstantLikeName(symbol_name)) .other else .variable
            else if (isConstantLikeName(symbol_name)) .other else .variable;
            const caveat_kind: CaveatKind = if (symbol_kind == .function) .assigned_function else if (symbol_kind == .other) .constant else .variable;
            try appendCandidate(allocator, candidates, proof_provider_name, path, symbol_name, symbol_kind, name_node, definition_node, caveatsForDefinition(caveat_kind, profile));
        },
        .table_field => {
            if (!isModuleLevelStableTableDefinition(definition_node)) return;
            if (std.mem.startsWith(u8, symbol_name, "__")) return;
            const value = tableDefinitionValueNode(definition_node);
            const symbol_kind: provider.SymbolKind = if (nodeTypeIs(value, "function_definition")) .function else if (isConstantLikeName(symbol_name)) .other else .variable;
            const caveat_kind: CaveatKind = if (symbol_kind == .function) .table_function else if (symbol_kind == .other) .constant else .table_field;
            try appendCandidate(allocator, candidates, proof_provider_name, path, symbol_name, symbol_kind, name_node, definition_node, caveatsForDefinition(caveat_kind, profile));
        },
    }
}

fn appendCandidate(
    allocator: std.mem.Allocator,
    candidates: *std.ArrayList(SymbolCandidate),
    proof_provider_name: []const u8,
    path: []const u8,
    symbol_name: []const u8,
    kind: provider.SymbolKind,
    order_node: c.TSNode,
    symbol_range_node: c.TSNode,
    caveats: []const []const u8,
) !void {
    try candidates.append(allocator, .{
        .start_byte = c.ts_node_start_byte(order_node),
        .end_byte = c.ts_node_end_byte(order_node),
        .symbol = .{
            .path = path,
            .name = symbol_name,
            .kind = kind,
            .current_range = .{ .lines = nodeLineRange(symbol_range_node) },
            .provider_name = proof_provider_name,
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
    return &supported_caveats;
}

fn caveatsForDefinition(kind: CaveatKind, profile: SourceProfile) []const []const u8 {
    if (profile.generated) return &generated_caveats;
    if (profile.metatable_skip_count > 0) return &metatable_caveats;
    if (profile.dynamic_table_assignment_skip_count > 0) return &dynamic_table_caveats;
    if (profile.embedded_dsl) return &embedded_dsl_caveats;
    return switch (kind) {
        .module => &supported_caveats,
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

fn expectSymbol(symbol: provider.CurrentSymbolEvidence, name: []const u8, kind: provider.SymbolKind, start: u32, end: u32) !void {
    try std.testing.expectEqualStrings(name, symbol.name);
    try std.testing.expectEqual(kind, symbol.kind);
    try std.testing.expectEqualStrings(provider_name, symbol.provider_name);
    try std.testing.expectEqual(provider.Confidence.high, symbol.confidence);
    switch (symbol.current_range) {
        .lines => |range| {
            try std.testing.expectEqual(start, range.start);
            try std.testing.expectEqual(end, range.end);
        },
        .bytes => return error.ExpectedLineRange,
    }
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

fn expectProviderEvidence(
    evidence: provider.ProviderEvidence,
    expected_provider_name: []const u8,
    expected_input_identity: []const u8,
    expected_failure: provider.Failure,
    expected_freshness: provider.Freshness,
    expected_confidence: provider.Confidence,
) !void {
    try std.testing.expectEqualStrings(expected_provider_name, evidence.name);
    try std.testing.expectEqual(provider.ProviderKind.symbol, evidence.kind);
    try std.testing.expectEqualStrings(provider_version, evidence.version);
    try std.testing.expectEqualStrings(provider.contract_version, evidence.contract_version);
    try std.testing.expectEqualStrings(query_fingerprint, evidence.config_fingerprint.?);
    try std.testing.expectEqualStrings(expected_input_identity, evidence.input.identity);
    try std.testing.expectEqual(expected_freshness, evidence.freshness);
    try std.testing.expectEqual(expected_failure, evidence.failure);
    try std.testing.expectEqual(expected_confidence, evidence.confidence);
    try std.testing.expectEqualStrings(expected_provider_name, evidence.provenance.provider_name);
    try std.testing.expectEqualStrings(expected_input_identity, evidence.provenance.input_identity);
}

test "Lua query contract exposes expected capture names" {
    const query = try compileLuaQuery();
    defer c.ts_query_delete(query);

    try std.testing.expectEqual(@as(u32, expected_capture_names.len), c.ts_query_capture_count(query));
    for (expected_capture_names) |expected| {
        var found = false;
        var capture_index: u32 = 0;
        while (capture_index < c.ts_query_capture_count(query)) : (capture_index += 1) {
            if (std.mem.eql(u8, expected, queryCaptureName(query, capture_index))) found = true;
        }
        try std.testing.expect(found);
    }
}

test "extracts supported Lua query symbols in deterministic source order" {
    var result = try extractLuaQuerySymbols(std.testing.allocator, "lua/supported_subset.lua", supported_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try expectProviderEvidence(result.provider, provider_name, "lua/supported_subset.lua", .ok, .fresh, .high);
    try std.testing.expectEqual(@as(usize, 10), result.symbols.len);
    try std.testing.expectEqual(@as(usize, 1), result.comment_capture_count);
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
    try expectCaveat(result.caveats, "comments are captured only for count evidence; comment text is not exposed");
}

test "Lua assignment fixture proves bare global and stable anonymous functions" {
    var result = try extractLuaQuerySymbols(std.testing.allocator, "packages/plugin/lua/assignments.lua", assignments_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 4), result.symbols.len);
    try expectSymbol(result.symbols[0], "packages/plugin/lua/assignments.lua", .module, 1, 12);
    try expectSymbol(result.symbols[1], "bare_global", .function, 1, 3);
    try expectSymbol(result.symbols[2], "local_assigned", .function, 5, 7);
    try expectSymbol(result.symbols[3], "global_assigned", .function, 9, 11);
    try expectCaveat(result.symbols[1].caveats, "function declarations use bare terminal identifiers; qualified Lua names are out of scope");
    try expectCaveat(result.symbols[2].caveats, "stable local or global anonymous function assignments map to provider SymbolKind.function by syntactic left-hand identifier only");
    try expectCaveat(result.symbols[3].caveats, "stable local or global anonymous function assignments map to provider SymbolKind.function by syntactic left-hand identifier only");
}

test "Lua dynamic table assignment fixture skips runtime-keyed symbols" {
    var result = try extractLuaQuerySymbols(std.testing.allocator, "lua/dynamic_table_assignment.lua", dynamic_table_assignment_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 4), result.symbols.len);
    try std.testing.expectEqual(@as(usize, 1), result.dynamic_table_assignment_skip_count);
    try expectSymbol(result.symbols[0], "lua/dynamic_table_assignment.lua", .module, 1, 10);
    try expectSymbol(result.symbols[1], "exports", .variable, 1, 1);
    try expectSymbol(result.symbols[2], "dynamic_name", .variable, 2, 2);
    try expectSymbol(result.symbols[3], "static", .function, 6, 8);
    try expectNoSymbol(result.symbols, "run");
    try expectCaveat(result.caveats, "dynamic bracket table assignments are skipped because runtime table keys are not deterministic symbols");
}

test "Lua metatable-heavy fixture caveats runtime behaviour and skips metamethod fields" {
    var result = try extractLuaQuerySymbols(std.testing.allocator, "lua/metatable_heavy.lua", metatable_heavy_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 4), result.symbols.len);
    try std.testing.expectEqual(@as(usize, 4), result.metatable_skip_count);
    try expectSymbol(result.symbols[0], "lua/metatable_heavy.lua", .module, 1, 17);
    try expectSymbol(result.symbols[1], "Thing", .variable, 1, 1);
    try expectSymbol(result.symbols[2], "mt", .variable, 2, 9);
    try expectSymbol(result.symbols[3], "new", .method, 12, 14);
    try expectNoSymbol(result.symbols, "__index");
    try expectNoSymbol(result.symbols, "__call");
    try expectCaveat(result.caveats, "metatable-heavy Lua is caveated; metamethod fields and runtime metatable behaviour are skipped");
}

test "Lua embedded DSL fixture caveats strings without parsing them as symbols" {
    var result = try extractLuaQuerySymbols(std.testing.allocator, "lua/embedded_dsl.lua", embedded_dsl_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 3), result.symbols.len);
    try std.testing.expectEqual(@as(usize, 1), result.comment_capture_count);
    try std.testing.expect(result.embedded_dsl_caveated);
    try expectSymbol(result.symbols[0], "lua/embedded_dsl.lua", .module, 1, 12);
    try expectSymbol(result.symbols[1], "query", .variable, 2, 5);
    try expectSymbol(result.symbols[2], "template", .variable, 7, 9);
    try expectNoSymbol(result.symbols, "function_not_lua");
    try expectNoSymbol(result.symbols, "fake");
    try expectNoSymbol(result.symbols, "also_not_lua");
    try expectCaveat(result.caveats, "embedded DSL strings are caveated only; string contents are not parsed as Lua symbols");
}

test "empty Lua fixture returns a module symbol only" {
    var result = try extractLuaQuerySymbols(std.testing.allocator, "lua/empty.lua", empty_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 1), result.symbols.len);
    try std.testing.expectEqual(@as(usize, 0), result.comment_capture_count);
    try expectSymbol(result.symbols[0], "lua/empty.lua", .module, 1, 1);
}

test "invalid partial Lua fixture fails safely without diagnostics" {
    var result = try extractLuaQuerySymbols(std.testing.allocator, "lua/invalid_partial.lua", invalid_partial_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.failed, result.failure);
    try expectProviderEvidence(result.provider, provider_name, "lua/invalid_partial.lua", .failed, .unknown, .low);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try expectCaveat(result.caveats, "no parser diagnostics or source snippets exposed");
}

test "generated Lua fixture is parsed with generated caveats only" {
    var result = try extractLuaQuerySymbols(std.testing.allocator, "lua/generated.lua", generated_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 4), result.symbols.len);
    try std.testing.expectEqual(@as(usize, 1), result.comment_capture_count);
    try expectSymbol(result.symbols[0], "lua/generated.lua", .module, 1, 8);
    try expectSymbol(result.symbols[1], "AUTO_VALUE", .other, 2, 2);
    try expectSymbol(result.symbols[2], "generated", .variable, 3, 7);
    try expectSymbol(result.symbols[3], "make", .function, 4, 6);
    try expectCaveat(result.symbols[3].caveats, "generated-file markers are caveated only; generated-source policy is not evaluated by this proof");
}

test "unsupported and unsafe Lua query paths fail closed" {
    var result = try extractLuaQuerySymbols(std.testing.allocator, "docs/unsupported.md", unsupported_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.unsupported, result.failure);
    try expectProviderEvidence(result.provider, provider_name, "docs/unsupported.md", .unsupported, .unknown, .unknown);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try expectCaveat(result.caveats, "no Lua parser was run for the unsupported path");

    try std.testing.expectError(error.InvalidRepoRelativePath, extractLuaQuerySymbols(std.testing.allocator, "../private/source.lua", "local hidden = true\n"));
}
