const std = @import("std");
const provider = @import("provider.zig");
const tree_sitter_common = @import("tree_sitter_common.zig");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_python() *const c.TSLanguage;

pub const provider_name = "tree-sitter-python";
pub const provider_version = "tree-sitter-core@v0.26.9/tree-sitter-python@v0.25.0/python-symbol-query-v1";
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
    errdefer freeCandidateSymbols(allocator, candidates.items);

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
    errdefer allocator.free(symbols);
    for (candidates.items, 0..) |candidate, i| symbols[i] = candidate.symbol;
    candidates.clearRetainingCapacity();

    return extraction(allocator, repo_relative_path, .ok, .fresh, .high, caveatsForModule(generated), symbols);
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
