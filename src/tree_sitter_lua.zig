const std = @import("std");
const provider = @import("provider.zig");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_lua() *const c.TSLanguage;

pub const provider_name = "tree-sitter-lua";
pub const provider_version = "tree-sitter-core@v0.26.9/tree-sitter-lua@v0.5.0/lua-symbol-query-v1";
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

pub const Extraction = struct {
    provider: provider.ProviderEvidence,
    symbols: []provider.CurrentSymbolEvidence,

    pub fn deinit(self: *Extraction, allocator: std.mem.Allocator) void {
        allocator.free(self.provider.input.identity);
        freeSymbols(allocator, self.symbols);
        self.* = undefined;
    }
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

pub fn isSupportedPath(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".lua");
}

pub fn extractPath(allocator: std.mem.Allocator, io: std.Io, repo_root: []const u8, repo_relative_path: []const u8) !Extraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!isSupportedPath(repo_relative_path)) {
        return extraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &unsupported_caveats, &.{});
    }

    const full_path = try std.fs.path.join(allocator, &.{ repo_root, repo_relative_path });
    defer allocator.free(full_path);

    const link_stat = std.Io.Dir.statFile(.cwd(), io, full_path, .{ .follow_symlinks = false }) catch return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    if (link_stat.kind != .file) return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});

    const file = std.Io.Dir.openFileAbsolute(io, full_path, .{}) catch return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    defer file.close(io);

    const stat = file.stat(io) catch return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    if (stat.kind != .file or stat.size > max_file_bytes) return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});

    const source = allocator.alloc(u8, @intCast(stat.size)) catch return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    defer allocator.free(source);
    const bytes_read = file.readPositionalAll(io, source, 0) catch return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    if (bytes_read != source.len) return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});

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
    errdefer freeCandidateSymbols(allocator, candidates.items);

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
    errdefer allocator.free(symbols);
    for (candidates.items, 0..) |candidate, i| symbols[i] = candidate.symbol;
    candidates.clearRetainingCapacity();

    return extraction(allocator, repo_relative_path, .ok, .fresh, .high, caveatsForModule(profile), symbols);
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
    errdefer freeSymbols(allocator, symbols);
    const identity = try std.fmt.allocPrint(allocator, "working-tree:{s}", .{repo_relative_path});
    return .{
        .provider = .{
            .name = provider_name,
            .kind = .symbol,
            .version = provider_version,
            .config_fingerprint = query_fingerprint,
            .input = .{ .identity = identity },
            .freshness = freshness,
            .failure = failure,
            .confidence = confidence,
            .caveats = caveats,
            .provenance = .{ .provider_name = provider_name, .input_identity = identity },
        },
        .symbols = symbols,
    };
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

fn freeCandidateSymbols(allocator: std.mem.Allocator, candidates: []SymbolCandidate) void {
    for (candidates) |candidate| freeSymbol(allocator, candidate.symbol);
}

fn freeSymbols(allocator: std.mem.Allocator, symbols: []provider.CurrentSymbolEvidence) void {
    for (symbols) |symbol| freeSymbol(allocator, symbol);
    allocator.free(symbols);
}

fn freeSymbol(allocator: std.mem.Allocator, symbol: provider.CurrentSymbolEvidence) void {
    allocator.free(symbol.path);
    allocator.free(symbol.name);
    if (symbol.current_line_history) |line_history| {
        for (line_history.sample_commits) |commit| allocator.free(commit);
        allocator.free(line_history.sample_commits);
        for (line_history.caveats) |caveat| allocator.free(caveat);
        allocator.free(line_history.caveats);
    }
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
