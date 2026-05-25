const std = @import("std");
const provider = @import("provider");

pub const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

pub const QueryContract = struct {
    language: *const c.TSLanguage,
    query_source: []const u8,
    capture_prefix: []const u8,
    provider_name: []const u8,
    supported_extensions: []const []const u8,
    unsupported_path_caveats: []const []const u8,
    is_tsx: bool,
};

pub const DefinitionKind = enum {
    class,
    function,
    method,
    variable,
    interface,
    type_alias,
    enum_definition,
    namespace,
};

const CaveatKind = enum {
    module,
    class,
    function,
    method,
    constant,
    variable,
    function_variable,
    type_like,
    namespace,
};

const SourceProfile = struct {
    generated_or_minified: bool,
    tsx: bool,
    jsx_syntax: bool,
};

const SymbolCandidate = struct {
    start_byte: u32,
    end_byte: u32,
    symbol: provider.CurrentSymbolEvidence,
};

pub const SymbolExtractionResult = struct {
    failure: provider.Failure,
    symbols: []provider.CurrentSymbolEvidence,
    caveats: []const []const u8,

    pub fn deinit(self: *SymbolExtractionResult, allocator: std.mem.Allocator) void {
        if (self.symbols.len > 0) allocator.free(self.symbols);
        self.* = undefined;
    }
};

const base_caveats = [_][]const u8{
    "test-only in-memory Tree-sitter TypeScript/TSX query proof",
    "project-owned TypeScript and TSX query assets; not upstream highlight, tags, or user queries",
    "range convention: one-based inclusive line range from the symbol node",
    "ordering convention: deterministic source order by symbol node start byte; the module symbol is first",
    "imports and exports are query-covered for fixture proof but do not emit standalone symbols",
    "runtime TypeScript/TSX --symbols output is not implemented by this proof",
    "no Node, package, workspace, tsconfig, module-resolution, LSP, parser-generation, or network analysis is performed",
    provider.CurrentSymbolEvidence.semantics,
};
const failed_caveats = [_][]const u8{
    "parse failed before safe TypeScript/TSX query symbol proof completed",
    "no parser diagnostics or source snippets exposed",
};
const generated_minified_caveats = base_caveats ++ [_][]const u8{
    "generated-file markers and minified one-line source are caveated only; generated/minified policy is not evaluated by this proof",
};
const tsx_caveats = base_caveats ++ [_][]const u8{
    "TSX JSX syntax and JSX components are query-covered structurally without React, DOM, package, or type analysis",
};
const method_caveats = base_caveats ++ [_][]const u8{
    "method classification is derived from a direct class body; method names are bare property identifiers",
};
const constant_caveats = base_caveats ++ [_][]const u8{
    "constant-like uppercase module bindings map to provider SymbolKind.other because no constant-specific kind exists",
};
const variable_caveats = base_caveats ++ [_][]const u8{
    "module-level simple bindings map to provider SymbolKind.variable",
};
const function_variable_caveats = base_caveats ++ [_][]const u8{
    "module-level function-valued bindings map to provider SymbolKind.function when the initializer is a direct function or arrow function",
};
const type_like_caveats = base_caveats ++ [_][]const u8{
    "interfaces, type aliases, enums, and namespaces map to provider SymbolKind.type; no public schema expansion is made",
};
const namespace_caveats = type_like_caveats ++ [_][]const u8{
    "namespace/internal_module names are emitted only when Tree-sitter exposes deterministic identifier or nested_identifier names",
};

pub fn expectCaptureNames(contract: QueryContract, expected_capture_names: []const []const u8) !void {
    const query = try compileQuery(contract);
    defer c.ts_query_delete(query);

    try std.testing.expectEqual(@as(u32, @intCast(expected_capture_names.len)), c.ts_query_capture_count(query));
    for (expected_capture_names) |expected| {
        var found = false;
        var capture_index: u32 = 0;
        while (capture_index < c.ts_query_capture_count(query)) : (capture_index += 1) {
            if (std.mem.eql(u8, expected, queryCaptureName(query, capture_index))) found = true;
        }
        try std.testing.expect(found);
    }
}

pub fn extractQuerySymbols(
    allocator: std.mem.Allocator,
    contract: QueryContract,
    repo_relative_path: []const u8,
    source: []const u8,
) !SymbolExtractionResult {
    try provider.validateRepoRelativePath(repo_relative_path);

    if (!isSupportedPath(contract, repo_relative_path)) {
        return .{
            .failure = .unsupported,
            .symbols = &.{},
            .caveats = contract.unsupported_path_caveats,
        };
    }

    const parser = c.ts_parser_new() orelse return failedResult();
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, contract.language)) return failedResult();

    const source_len = std.math.cast(u32, source.len) orelse return failedResult();
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return failedResult();
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return failedResult();

    const query = try compileQuery(contract);
    defer c.ts_query_delete(query);

    const cursor = c.ts_query_cursor_new() orelse return failedResult();
    defer c.ts_query_cursor_delete(cursor);

    var candidates: std.ArrayList(SymbolCandidate) = .empty;
    defer candidates.deinit(allocator);

    const profile = sourceProfile(contract, source);

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
            if (captureNameIs(contract, name, "module")) {
                try appendCandidate(
                    allocator,
                    &candidates,
                    contract.provider_name,
                    repo_relative_path,
                    repo_relative_path,
                    .module,
                    capture.node,
                    capture.node,
                    caveatsForModule(profile),
                );
            } else if (captureNameIs(contract, name, "class.definition")) {
                definition_node = capture.node;
                definition_kind = .class;
            } else if (captureNameIs(contract, name, "function.definition")) {
                definition_node = capture.node;
                definition_kind = .function;
            } else if (captureNameIs(contract, name, "method.definition")) {
                definition_node = capture.node;
                definition_kind = .method;
            } else if (captureNameIs(contract, name, "interface.definition")) {
                definition_node = capture.node;
                definition_kind = .interface;
            } else if (captureNameIs(contract, name, "type.definition")) {
                definition_node = capture.node;
                definition_kind = .type_alias;
            } else if (captureNameIs(contract, name, "enum.definition")) {
                definition_node = capture.node;
                definition_kind = .enum_definition;
            } else if (captureNameIs(contract, name, "namespace.definition")) {
                definition_node = capture.node;
                definition_kind = .namespace;
            } else if (captureNameIs(contract, name, "variable.definition")) {
                definition_node = capture.node;
                definition_kind = .variable;
            } else if (captureNameIs(contract, name, "definition.name")) {
                name_node = capture.node;
                has_name = true;
            }
        }

        if (definition_kind) |kind| {
            if (!has_name) continue;
            try appendDefinitionCandidate(allocator, contract, &candidates, repo_relative_path, source, definition_node, name_node, kind, profile);
        }
    }

    std.mem.sort(SymbolCandidate, candidates.items, {}, lessCandidate);

    var symbols: std.ArrayList(provider.CurrentSymbolEvidence) = .empty;
    errdefer symbols.deinit(allocator);
    for (candidates.items) |candidate| try symbols.append(allocator, candidate.symbol);

    return .{
        .failure = .ok,
        .symbols = try symbols.toOwnedSlice(allocator),
        .caveats = caveatsForModule(profile),
    };
}

fn compileQuery(contract: QueryContract) !*c.TSQuery {
    var error_offset: u32 = 0;
    var error_type: c.TSQueryError = c.TSQueryErrorNone;
    return c.ts_query_new(
        contract.language,
        contract.query_source.ptr,
        @intCast(contract.query_source.len),
        &error_offset,
        &error_type,
    ) orelse error.QueryCompileFailed;
}

fn failedResult() SymbolExtractionResult {
    return .{
        .failure = .failed,
        .symbols = &.{},
        .caveats = &failed_caveats,
    };
}

fn appendDefinitionCandidate(
    allocator: std.mem.Allocator,
    contract: QueryContract,
    candidates: *std.ArrayList(SymbolCandidate),
    path: []const u8,
    source: []const u8,
    definition_node: c.TSNode,
    name_node: c.TSNode,
    kind: DefinitionKind,
    profile: SourceProfile,
) !void {
    const symbol_name = nodeSourceSlice(source, name_node) orelse return;
    if (symbol_name.len == 0 or symbol_name[0] == '"' or symbol_name[0] == '\'') return;

    switch (kind) {
        .class => try appendCandidate(allocator, candidates, contract.provider_name, path, symbol_name, .class, name_node, definition_node, caveatsForDefinition(.class, profile, false)),
        .function => try appendCandidate(allocator, candidates, contract.provider_name, path, symbol_name, .function, name_node, definition_node, caveatsForDefinition(.function, profile, false)),
        .method => {
            if (!isDirectClassBodyMethod(definition_node)) return;
            try appendCandidate(allocator, candidates, contract.provider_name, path, symbol_name, .method, name_node, definition_node, caveatsForDefinition(.method, profile, false));
        },
        .variable => {
            if (!isModuleLevelDefinition(definition_node)) return;
            const value_node = childByFieldName(definition_node, "value");
            const function_valued = isFunctionValued(value_node);
            const symbol_kind: provider.SymbolKind = if (function_valued) .function else if (isConstantLikeName(symbol_name)) .other else .variable;
            const caveat_kind: CaveatKind = if (function_valued) .function_variable else if (symbol_kind == .other) .constant else .variable;
            try appendCandidate(allocator, candidates, contract.provider_name, path, symbol_name, symbol_kind, name_node, definition_node, caveatsForDefinition(caveat_kind, profile, function_valued));
        },
        .interface, .type_alias, .enum_definition => try appendCandidate(allocator, candidates, contract.provider_name, path, symbol_name, .type, name_node, definition_node, caveatsForDefinition(.type_like, profile, false)),
        .namespace => try appendCandidate(allocator, candidates, contract.provider_name, path, symbol_name, .type, name_node, definition_node, caveatsForDefinition(.namespace, profile, false)),
    }
}

fn appendCandidate(
    allocator: std.mem.Allocator,
    candidates: *std.ArrayList(SymbolCandidate),
    provider_name: []const u8,
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
            .provider_name = provider_name,
            .confidence = .high,
            .caveats = caveats,
        },
    });
}

fn caveatsForModule(profile: SourceProfile) []const []const u8 {
    if (profile.generated_or_minified) return &generated_minified_caveats;
    if (profile.tsx and profile.jsx_syntax) return &tsx_caveats;
    return &base_caveats;
}

fn caveatsForDefinition(kind: CaveatKind, profile: SourceProfile, function_valued: bool) []const []const u8 {
    if (profile.generated_or_minified) return &generated_minified_caveats;
    if (profile.tsx and profile.jsx_syntax and function_valued) return &tsx_caveats;
    return switch (kind) {
        .module, .class, .function => &base_caveats,
        .method => &method_caveats,
        .constant => &constant_caveats,
        .variable => &variable_caveats,
        .function_variable => &function_variable_caveats,
        .type_like => &type_like_caveats,
        .namespace => &namespace_caveats,
    };
}

fn sourceProfile(contract: QueryContract, source: []const u8) SourceProfile {
    return .{
        .generated_or_minified = hasGeneratedMarker(source) or looksMinified(source),
        .tsx = contract.is_tsx,
        .jsx_syntax = std.mem.indexOf(u8, source, "<") != null and std.mem.indexOf(u8, source, ">") != null,
    };
}

fn hasGeneratedMarker(source: []const u8) bool {
    const scan_len = @min(source.len, 2048);
    const prefix = source[0..scan_len];
    return std.mem.indexOf(u8, prefix, "Code generated") != null or std.mem.indexOf(u8, prefix, "DO NOT EDIT") != null;
}

fn looksMinified(source: []const u8) bool {
    if (source.len < 80) return false;
    return std.mem.indexOfScalar(u8, source[0 .. source.len - 1], '\n') == null;
}

fn isSupportedPath(contract: QueryContract, path: []const u8) bool {
    for (contract.supported_extensions) |extension| {
        if (std.mem.endsWith(u8, path, extension)) return true;
    }
    return false;
}

fn captureNameIs(contract: QueryContract, capture_name: []const u8, suffix: []const u8) bool {
    if (!std.mem.startsWith(u8, capture_name, contract.capture_prefix)) return false;
    if (capture_name.len != contract.capture_prefix.len + 1 + suffix.len) return false;
    if (capture_name[contract.capture_prefix.len] != '.') return false;
    return std.mem.eql(u8, capture_name[contract.capture_prefix.len + 1 ..], suffix);
}

fn isFunctionValued(node: c.TSNode) bool {
    if (c.ts_node_is_null(node)) return false;
    return nodeTypeIs(node, "function_expression") or nodeTypeIs(node, "arrow_function");
}

fn isDirectClassBodyMethod(node: c.TSNode) bool {
    const parent = c.ts_node_parent(node);
    if (c.ts_node_is_null(parent) or !nodeTypeIs(parent, "class_body")) return false;

    const grandparent = c.ts_node_parent(parent);
    return !c.ts_node_is_null(grandparent) and (nodeTypeIs(grandparent, "class_declaration") or nodeTypeIs(grandparent, "abstract_class_declaration") or nodeTypeIs(grandparent, "class"));
}

fn isModuleLevelDefinition(node: c.TSNode) bool {
    var current = node;
    while (true) {
        const parent = c.ts_node_parent(current);
        if (c.ts_node_is_null(parent)) return false;
        if (nodeTypeIs(parent, "program")) return true;
        if (nodeTypeIs(parent, "export_statement") or nodeTypeIs(parent, "lexical_declaration") or nodeTypeIs(parent, "variable_declaration")) {
            current = parent;
            continue;
        }
        if (nodeTypeIs(parent, "statement_block") or nodeTypeIs(parent, "class_body") or nodeTypeIs(parent, "function_declaration") or nodeTypeIs(parent, "function_expression") or nodeTypeIs(parent, "arrow_function") or nodeTypeIs(parent, "method_definition") or nodeTypeIs(parent, "class_declaration") or nodeTypeIs(parent, "abstract_class_declaration") or nodeTypeIs(parent, "internal_module")) return false;
        current = parent;
    }
}

fn isConstantLikeName(name: []const u8) bool {
    var saw_alpha = false;
    for (name) |char| {
        if (std.ascii.isAlphabetic(char)) {
            saw_alpha = true;
            if (std.ascii.isLower(char)) return false;
        } else if (std.ascii.isDigit(char) or char == '_' or char == '$') {
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

pub fn expectSymbol(symbol: provider.CurrentSymbolEvidence, provider_name: []const u8, name: []const u8, kind: provider.SymbolKind, start: u32, end: u32) !void {
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

pub fn expectNoSymbol(symbols: []const provider.CurrentSymbolEvidence, name: []const u8) !void {
    for (symbols) |symbol| {
        if (std.mem.eql(u8, symbol.name, name)) return error.UnexpectedSymbol;
    }
}

pub fn expectCaveat(caveats: []const []const u8, expected: []const u8) !void {
    for (caveats) |caveat| {
        if (std.mem.eql(u8, caveat, expected)) return;
    }
    return error.ExpectedCaveat;
}
