const std = @import("std");
const provider = @import("provider.zig");
const tree_sitter_common = @import("tree_sitter_common.zig");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_typescript() *const c.TSLanguage;
extern fn tree_sitter_tsx() *const c.TSLanguage;

pub const typescript_provider_name = "tree-sitter-typescript";
pub const tsx_provider_name = "tree-sitter-tsx";
const typescript_provider_version = "tree-sitter-core@v0.26.9/tree-sitter-typescript@v0.23.2/typescript-symbol-query-v1";
const tsx_provider_version = "tree-sitter-core@v0.26.9/tree-sitter-typescript@v0.23.2/tsx-symbol-query-v1";
const max_file_bytes: u64 = 1024 * 1024;
const typescript_query_source = @embedFile("queries/typescript-symbols.scm");
const tsx_query_source = @embedFile("queries/tsx-symbols.scm");

const ok_caveats = [_][]const u8{
    "current working-tree enrichment only; file-level Git evidence remains product truth",
    "supported subset: module roots, class declarations, function declarations, direct class methods, module-level simple bindings, interfaces, type aliases, enums, namespaces, and deterministic TSX component-shaped bindings",
    "range convention: one-based inclusive lines; method names are bare property identifiers",
    "provider order: module symbol first, then deterministic source order by symbol node start byte",
    "module names are repo-relative .ts/.mts/.cts/.tsx paths; package, workspace, Node, module-resolution, tsconfig, type checking, LSP, and symbol line history are out of scope",
    "imports, exports, dependency graphs, generated-source policy, scoring, semantic moves, custom queries, cache, network, telemetry, and upload are out of scope",
    provider.CurrentSymbolEvidence.semantics,
};
const unsupported_typescript_caveats = [_][]const u8{
    "provider unsupported: only repo-relative .ts, .mts, and .cts files are parsed by the TypeScript provider",
    "TSX paths are handled by the separate TSX provider",
    "no parser diagnostics or source snippets exposed",
};
const unsupported_tsx_caveats = [_][]const u8{
    "provider unsupported: only repo-relative .tsx files are parsed by the TSX provider",
    "plain TypeScript paths are handled by the separate TypeScript provider",
    "no parser diagnostics or source snippets exposed",
};
const unavailable_caveats = [_][]const u8{
    "current working-tree file unavailable or not a regular bounded file",
    "no parser diagnostics, source snippets, absolute paths, remotes, author identities, commit messages, or private repo names exposed",
};
const failed_caveats = [_][]const u8{
    "provider failed to parse supported TypeScript/TSX symbol evidence",
    "invalid or partial TypeScript/TSX source failed closed without parser diagnostics or source snippets",
};
const generated_minified_caveats = ok_caveats ++ [_][]const u8{
    "generated-file markers and minified one-line source are caveated only; generated/minified policy is not evaluated by this provider",
};
const tsx_caveats = ok_caveats ++ [_][]const u8{
    "TSX JSX syntax and JSX components are query-covered structurally without React, DOM, package, or type analysis",
};
const method_caveats = ok_caveats ++ [_][]const u8{
    "method classification is derived from a direct class body; method names are bare property identifiers",
};
const constant_caveats = ok_caveats ++ [_][]const u8{
    "constant-like uppercase module bindings map to provider SymbolKind.other because no constant-specific kind exists",
};
const variable_caveats = ok_caveats ++ [_][]const u8{
    "module-level simple bindings map to provider SymbolKind.variable",
};
const function_variable_caveats = ok_caveats ++ [_][]const u8{
    "module-level function-valued bindings map to provider SymbolKind.function when the initializer is a direct function or arrow function",
};
const type_like_caveats = ok_caveats ++ [_][]const u8{
    "interfaces, type aliases, enums, and namespaces map to provider SymbolKind.type; no public schema expansion is made",
};
const namespace_caveats = type_like_caveats ++ [_][]const u8{
    "namespace/internal_module names are emitted only when Tree-sitter exposes deterministic identifier or nested_identifier names",
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

const Contract = struct {
    language: *const c.TSLanguage,
    query_source: []const u8,
    capture_prefix: []const u8,
    provider_name: []const u8,
    provider_version: []const u8,
    unsupported_caveats: []const []const u8,
    is_tsx: bool,
};

const DefinitionKind = enum {
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

pub fn isSupportedTypeScriptPath(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".ts") or
        std.mem.endsWith(u8, path, ".mts") or
        std.mem.endsWith(u8, path, ".cts");
}

pub fn isSupportedTsxPath(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".tsx");
}

pub fn isSupportedPath(path: []const u8) bool {
    return isSupportedTypeScriptPath(path) or isSupportedTsxPath(path);
}

pub fn extractPath(allocator: std.mem.Allocator, io: std.Io, repo_root: []const u8, repo_relative_path: []const u8) !Extraction {
    const contract = contractForPath(repo_relative_path);
    return extractPathWithContract(allocator, io, repo_root, repo_relative_path, contract);
}

pub fn extractSource(allocator: std.mem.Allocator, repo_relative_path: []const u8, source: []const u8) !Extraction {
    const contract = contractForPath(repo_relative_path);
    return extractSourceWithContract(allocator, contract, repo_relative_path, source);
}

fn contractForPath(path: []const u8) Contract {
    if (isSupportedTsxPath(path)) return tsxContract();
    return typescriptContract();
}

fn typescriptContract() Contract {
    return .{
        .language = tree_sitter_typescript(),
        .query_source = typescript_query_source,
        .capture_prefix = "typescript",
        .provider_name = typescript_provider_name,
        .provider_version = typescript_provider_version,
        .unsupported_caveats = &unsupported_typescript_caveats,
        .is_tsx = false,
    };
}

fn tsxContract() Contract {
    return .{
        .language = tree_sitter_tsx(),
        .query_source = tsx_query_source,
        .capture_prefix = "tsx",
        .provider_name = tsx_provider_name,
        .provider_version = tsx_provider_version,
        .unsupported_caveats = &unsupported_tsx_caveats,
        .is_tsx = true,
    };
}

fn extractPathWithContract(allocator: std.mem.Allocator, io: std.Io, repo_root: []const u8, repo_relative_path: []const u8, contract: Contract) !Extraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!isSupportedContractPath(contract, repo_relative_path)) {
        return extraction(allocator, contract, repo_relative_path, .unsupported, .unknown, .unknown, contract.unsupported_caveats, &.{});
    }

    const source = try tree_sitter_common.readBoundedFile(allocator, io, repo_root, repo_relative_path, max_file_bytes) orelse return extraction(allocator, contract, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    defer allocator.free(source);

    return extractSourceWithContract(allocator, contract, repo_relative_path, source);
}

fn extractSourceWithContract(allocator: std.mem.Allocator, contract: Contract, repo_relative_path: []const u8, source: []const u8) !Extraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!isSupportedContractPath(contract, repo_relative_path)) {
        return extraction(allocator, contract, repo_relative_path, .unsupported, .unknown, .unknown, contract.unsupported_caveats, &.{});
    }

    const parser = c.ts_parser_new() orelse return extraction(allocator, contract, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, contract.language)) return extraction(allocator, contract, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});

    const source_len = std.math.cast(u32, source.len) orelse return extraction(allocator, contract, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return extraction(allocator, contract, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return extraction(allocator, contract, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});

    const query = compileQuery(contract) catch return extraction(allocator, contract, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_query_delete(query);

    const cursor = c.ts_query_cursor_new() orelse return extraction(allocator, contract, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_query_cursor_delete(cursor);

    var candidates: std.ArrayList(SymbolCandidate) = .empty;
    defer candidates.deinit(allocator);
    errdefer freeCandidateSymbols(allocator, candidates.items);

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

    const symbols = try allocator.alloc(provider.CurrentSymbolEvidence, candidates.items.len);
    errdefer allocator.free(symbols);
    for (candidates.items, 0..) |candidate, i| symbols[i] = candidate.symbol;
    candidates.clearRetainingCapacity();

    return extraction(allocator, contract, repo_relative_path, .ok, .fresh, .high, caveatsForModule(profile), symbols);
}

fn extraction(
    allocator: std.mem.Allocator,
    contract: Contract,
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
            .name = contract.provider_name,
            .kind = .symbol,
            .version = contract.provider_version,
            .input = .{ .identity = identity },
            .freshness = freshness,
            .failure = failure,
            .confidence = confidence,
            .caveats = caveats,
            .provenance = .{ .provider_name = contract.provider_name, .input_identity = identity },
        },
        .symbols = symbols,
    };
}

fn compileQuery(contract: Contract) !*c.TSQuery {
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

fn appendDefinitionCandidate(
    allocator: std.mem.Allocator,
    contract: Contract,
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
    if (profile.generated_or_minified) return &generated_minified_caveats;
    if (profile.tsx and profile.jsx_syntax) return &tsx_caveats;
    return &ok_caveats;
}

fn caveatsForDefinition(kind: CaveatKind, profile: SourceProfile, function_valued: bool) []const []const u8 {
    if (profile.generated_or_minified) return &generated_minified_caveats;
    if (profile.tsx and profile.jsx_syntax and function_valued) return &tsx_caveats;
    return switch (kind) {
        .module, .class, .function => &ok_caveats,
        .method => &method_caveats,
        .constant => &constant_caveats,
        .variable => &variable_caveats,
        .function_variable => &function_variable_caveats,
        .type_like => &type_like_caveats,
        .namespace => &namespace_caveats,
    };
}

fn sourceProfile(contract: Contract, source: []const u8) SourceProfile {
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

fn isSupportedContractPath(contract: Contract, path: []const u8) bool {
    return if (contract.is_tsx) isSupportedTsxPath(path) else isSupportedTypeScriptPath(path);
}

fn captureNameIs(contract: Contract, capture_name: []const u8, suffix: []const u8) bool {
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

fn expectSymbol(symbol: provider.CurrentSymbolEvidence, provider_name: []const u8, name: []const u8, kind: provider.SymbolKind, start: u32, end: u32) !void {
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

test "extract source handles supported TypeScript subset in source order" {
    const source =
        \\// Supported TypeScript query subset fixture.
        \\export const EXPORTED_FLAG = true;
        \\let mutableCount = 1;
        \\
        \\export function compute(input: number): number {
        \\  function localHelper(value: number): number {
        \\    return value + input;
        \\  }
        \\  return localHelper(input);
        \\}
        \\
        \\class LocalWorker {
        \\  run(): number {
        \\    function methodHelper(): number { return 1; }
        \\    return methodHelper();
        \\  }
        \\}
        \\
        \\interface UserShape {
        \\  id: UserId;
        \\}
        \\type UserId = string;
        \\enum Mode { One, Two }
        \\namespace Tools {
        \\  export function inside() { return 1; }
        \\}
        \\
        \\function café(): string {
        \\  return "unicode";
        \\}
        \\
    ;

    var result = try extractSource(std.testing.allocator, "packages/app/src/supported_subset.ts", source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.provider.failure);
    try std.testing.expectEqual(@as(usize, 14), result.symbols.len);
    try expectSymbol(result.symbols[0], typescript_provider_name, "packages/app/src/supported_subset.ts", .module, 1, 31);
    try expectSymbol(result.symbols[1], typescript_provider_name, "EXPORTED_FLAG", .other, 2, 2);
    try expectSymbol(result.symbols[2], typescript_provider_name, "mutableCount", .variable, 3, 3);
    try expectSymbol(result.symbols[3], typescript_provider_name, "compute", .function, 5, 10);
    try expectSymbol(result.symbols[4], typescript_provider_name, "localHelper", .function, 6, 8);
    try expectSymbol(result.symbols[5], typescript_provider_name, "LocalWorker", .class, 12, 17);
    try expectSymbol(result.symbols[6], typescript_provider_name, "run", .method, 13, 16);
    try expectSymbol(result.symbols[7], typescript_provider_name, "methodHelper", .function, 14, 14);
    try expectSymbol(result.symbols[8], typescript_provider_name, "UserShape", .type, 19, 21);
    try expectSymbol(result.symbols[9], typescript_provider_name, "UserId", .type, 22, 22);
    try expectSymbol(result.symbols[10], typescript_provider_name, "Mode", .type, 23, 23);
    try expectSymbol(result.symbols[11], typescript_provider_name, "Tools", .type, 24, 26);
    try expectSymbol(result.symbols[12], typescript_provider_name, "inside", .function, 25, 25);
    try expectSymbol(result.symbols[13], typescript_provider_name, "café", .function, 28, 30);
    try std.testing.expect(result.symbols[3].current_line_history == null);
    try expectCaveat(result.provider.caveats, provider.CurrentSymbolEvidence.semantics);
    try expectCaveat(result.symbols[1].caveats, "constant-like uppercase module bindings map to provider SymbolKind.other because no constant-specific kind exists");
    try expectCaveat(result.symbols[6].caveats, "method classification is derived from a direct class body; method names are bare property identifiers");
    try expectCaveat(result.symbols[8].caveats, "interfaces, type aliases, enums, and namespaces map to provider SymbolKind.type; no public schema expansion is made");
}

test "extract source handles TypeScript extensions empty generated invalid unsupported and unsafe inputs" {
    var module_result = try extractSource(std.testing.allocator, "packages/lib/module_case.mts", "export function moduleEntry() {\n  return 1;\n}\n");
    defer module_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, module_result.provider.failure);
    try expectSymbol(module_result.symbols[0], typescript_provider_name, "packages/lib/module_case.mts", .module, 1, 4);
    try expectSymbol(module_result.symbols[1], typescript_provider_name, "moduleEntry", .function, 1, 3);

    var commonjs_result = try extractSource(std.testing.allocator, "packages/lib/common_case.cts", "const legacyValue = require('legacy');\n");
    defer commonjs_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, commonjs_result.provider.failure);
    try expectSymbol(commonjs_result.symbols[0], typescript_provider_name, "packages/lib/common_case.cts", .module, 1, 2);
    try expectSymbol(commonjs_result.symbols[1], typescript_provider_name, "legacyValue", .variable, 1, 1);

    var empty_result = try extractSource(std.testing.allocator, "src/empty.ts", "");
    defer empty_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, empty_result.provider.failure);
    try expectSymbol(empty_result.symbols[0], typescript_provider_name, "src/empty.ts", .module, 1, 1);

    var generated_result = try extractSource(std.testing.allocator, "src/generated.min.ts", "/* Code generated; DO NOT EDIT. */const GENERATED_VALUE=1;function generatedFunction(){return GENERATED_VALUE;}\n");
    defer generated_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, generated_result.provider.failure);
    try expectSymbol(generated_result.symbols[1], typescript_provider_name, "GENERATED_VALUE", .other, 1, 1);
    try expectCaveat(generated_result.symbols[1].caveats, "generated-file markers and minified one-line source are caveated only; generated/minified policy is not evaluated by this provider");

    var invalid_result = try extractSource(std.testing.allocator, "src/invalid_partial.ts", "export function broken(\n");
    defer invalid_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.failed, invalid_result.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), invalid_result.symbols.len);
    try expectCaveat(invalid_result.provider.caveats, "invalid or partial TypeScript/TSX source failed closed without parser diagnostics or source snippets");

    var unsupported_result = try extractSource(std.testing.allocator, "packages/app/src/unsupported.js", "export function hidden() {}\n");
    defer unsupported_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unsupported, unsupported_result.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), unsupported_result.symbols.len);

    const anonymous_source = "export default function () { return 1; }\nexport default class {}\n";
    var anonymous_result = try extractSource(std.testing.allocator, "src/anonymous.ts", anonymous_source);
    defer anonymous_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, anonymous_result.provider.failure);
    try std.testing.expectEqual(@as(usize, 1), anonymous_result.symbols.len);
    try expectSymbol(anonymous_result.symbols[0], typescript_provider_name, "src/anonymous.ts", .module, 1, 3);
    try expectNoSymbol(anonymous_result.symbols, "default");

    try std.testing.expectError(error.InvalidRepoRelativePath, extractSource(std.testing.allocator, "../private/source.ts", "export function hidden() {}\n"));
}

test "extract source handles TSX components and edge cases" {
    const source =
        \\type Props = {
        \\  title: string;
        \\};
        \\
        \\export function Panel(props: Props) {
        \\  return <section>{props.title}</section>;
        \\}
        \\
        \\const InlineWidget = () => <span />;
        \\
        \\class ClassWidget {
        \\  render() {
        \\    return <Panel title="ok" />;
        \\  }
        \\}
        \\
        \\type PanelProps = Props;
        \\enum DisplayMode { Compact, Full }
        \\
    ;

    var result = try extractSource(std.testing.allocator, "packages/app/src/component.tsx", source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.provider.failure);
    try std.testing.expectEqual(@as(usize, 8), result.symbols.len);
    try expectSymbol(result.symbols[0], tsx_provider_name, "packages/app/src/component.tsx", .module, 1, 19);
    try expectSymbol(result.symbols[1], tsx_provider_name, "Props", .type, 1, 3);
    try expectSymbol(result.symbols[2], tsx_provider_name, "Panel", .function, 5, 7);
    try expectSymbol(result.symbols[3], tsx_provider_name, "InlineWidget", .function, 9, 9);
    try expectSymbol(result.symbols[4], tsx_provider_name, "ClassWidget", .class, 11, 15);
    try expectSymbol(result.symbols[5], tsx_provider_name, "render", .method, 12, 14);
    try expectSymbol(result.symbols[6], tsx_provider_name, "PanelProps", .type, 17, 17);
    try expectSymbol(result.symbols[7], tsx_provider_name, "DisplayMode", .type, 18, 18);
    try std.testing.expect(result.symbols[2].current_line_history == null);
    try expectCaveat(result.provider.caveats, "TSX JSX syntax and JSX components are query-covered structurally without React, DOM, package, or type analysis");
    try expectCaveat(result.symbols[3].caveats, "TSX JSX syntax and JSX components are query-covered structurally without React, DOM, package, or type analysis");

    var empty_result = try extractSource(std.testing.allocator, "src/empty.tsx", "");
    defer empty_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, empty_result.provider.failure);
    try expectSymbol(empty_result.symbols[0], tsx_provider_name, "src/empty.tsx", .module, 1, 1);

    var unsupported_result = try extractSource(std.testing.allocator, "packages/app/src/unsupported.ts", "export function hidden() {}\n");
    defer unsupported_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, unsupported_result.provider.failure);
    try std.testing.expectEqualStrings(typescript_provider_name, unsupported_result.provider.name);

    var invalid_result = try extractSource(std.testing.allocator, "src/invalid_partial.tsx", "export function Broken() {\n  return <div>\n}\n");
    defer invalid_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.failed, invalid_result.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), invalid_result.symbols.len);
}
