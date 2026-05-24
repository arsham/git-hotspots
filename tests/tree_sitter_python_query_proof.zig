const std = @import("std");
const provider = @import("provider");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_python() *const c.TSLanguage;

const query_source = @embedFile("fixtures/tree_sitter_python_query/python-symbols.scm");
const supported_source = @embedFile("fixtures/tree_sitter_python_query/supported_subset.py");
const generated_source = @embedFile("fixtures/tree_sitter_python_query/generated.py");
const invalid_partial_source = @embedFile("fixtures/tree_sitter_python_query/invalid_partial.py");
const empty_source = @embedFile("fixtures/tree_sitter_python_query/empty.py");
const unsupported_source = @embedFile("fixtures/tree_sitter_python_query/unsupported.md");

const provider_name = "tree-sitter-python-query-proof";
const query_version = "python-symbol-query-v1";
const expected_capture_names = [_][]const u8{
    "python.module",
    "python.definition.name",
    "python.class.definition",
    "python.function.definition",
    "python.assignment.definition",
    "python.decorator",
};

const supported_caveats = [_][]const u8{
    "test-only in-memory Tree-sitter Python query proof",
    "Python grammar v0.25.0; query version: " ++ query_version,
    "project-owned query asset: tests/fixtures/tree_sitter_python_query/python-symbols.scm",
    "range convention: one-based inclusive line range from the symbol node; decorated definitions include decorators",
    "ordering convention: deterministic source order by symbol node start byte; the module symbol is first",
    "module names are repo-relative .py paths; qualified Python names are out of scope",
    "nested definitions are emitted with bare names only",
    "dynamic assignments, tuple/list destructuring, imports, package discovery, venvs, notebooks, and LSP analysis are out of scope",
    provider.CurrentSymbolEvidence.semantics,
};
const unsupported_caveats = [_][]const u8{
    "unsupported path: only repo-relative .py files are Python query candidates",
    "no Python parser was run for the unsupported path",
};
const failed_caveats = [_][]const u8{
    "parse failed before safe Python query symbol proof completed",
    "no parser diagnostics or source snippets exposed",
};
const method_caveats = supported_caveats ++ [_][]const u8{
    "method classification is derived from a direct enclosing class block; method names are bare identifiers",
};
const constant_caveats = supported_caveats ++ [_][]const u8{
    "constant-like uppercase module assignments map to provider SymbolKind.other because no constant-specific kind exists",
};
const variable_caveats = supported_caveats ++ [_][]const u8{
    "module-level simple assignments map to provider SymbolKind.variable",
};
const generated_caveats = supported_caveats ++ [_][]const u8{
    "generated-file markers are caveated only; generated-source policy is not evaluated by this proof",
};

const DefinitionKind = enum {
    class,
    function,
    assignment,
};

const SymbolCandidate = struct {
    start_byte: u32,
    end_byte: u32,
    symbol: provider.CurrentSymbolEvidence,
};

const SymbolExtractionResult = struct {
    failure: provider.Failure,
    symbols: []provider.CurrentSymbolEvidence,
    caveats: []const []const u8,
    decorator_capture_count: usize = 0,

    fn deinit(self: *SymbolExtractionResult, allocator: std.mem.Allocator) void {
        if (self.symbols.len > 0) allocator.free(self.symbols);
        self.* = undefined;
    }
};

fn extractPythonQuerySymbols(
    allocator: std.mem.Allocator,
    repo_relative_path: []const u8,
    source: []const u8,
) !SymbolExtractionResult {
    try provider.validateRepoRelativePath(repo_relative_path);

    if (!std.mem.endsWith(u8, repo_relative_path, ".py")) {
        return .{
            .failure = .unsupported,
            .symbols = &.{},
            .caveats = &unsupported_caveats,
        };
    }

    const parser = c.ts_parser_new() orelse return failedResult();
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_python())) return failedResult();

    const source_len = std.math.cast(u32, source.len) orelse return failedResult();
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return failedResult();
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return failedResult();

    const query = try compilePythonQuery();
    defer c.ts_query_delete(query);

    const cursor = c.ts_query_cursor_new() orelse return failedResult();
    defer c.ts_query_cursor_delete(cursor);

    var candidates: std.ArrayList(SymbolCandidate) = .empty;
    defer candidates.deinit(allocator);

    var decorator_capture_count: usize = 0;
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
            } else if (std.mem.eql(u8, name, "python.decorator")) {
                decorator_capture_count += 1;
            }
        }

        if (definition_kind) |kind| {
            if (!has_name) continue;
            try appendDefinitionCandidate(allocator, &candidates, repo_relative_path, source, definition_node, name_node, kind, generated);
        }
    }

    std.mem.sort(SymbolCandidate, candidates.items, {}, lessCandidate);

    var symbols: std.ArrayList(provider.CurrentSymbolEvidence) = .empty;
    errdefer symbols.deinit(allocator);
    for (candidates.items) |candidate| try symbols.append(allocator, candidate.symbol);

    return .{
        .failure = .ok,
        .symbols = try symbols.toOwnedSlice(allocator),
        .caveats = caveatsForModule(generated),
        .decorator_capture_count = decorator_capture_count,
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

fn failedResult() SymbolExtractionResult {
    return .{
        .failure = .failed,
        .symbols = &.{},
        .caveats = &failed_caveats,
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
    generated: bool,
) !void {
    const symbol_name = nodeSourceSlice(source, name_node) orelse return;
    switch (kind) {
        .class => try appendCandidate(allocator, candidates, path, symbol_name, .class, name_node, rangeNode(definition_node), caveatsForDefinition(.class, symbol_name, generated)),
        .function => {
            const symbol_kind: provider.SymbolKind = if (isDirectClassBodyDefinition(definition_node)) .method else .function;
            try appendCandidate(allocator, candidates, path, symbol_name, symbol_kind, name_node, rangeNode(definition_node), caveatsForDefinition(if (symbol_kind == .method) .method else .function, symbol_name, generated));
        },
        .assignment => {
            if (!isModuleLevelDefinition(definition_node)) return;
            const symbol_kind: provider.SymbolKind = if (isConstantLikeName(symbol_name)) .other else .variable;
            try appendCandidate(allocator, candidates, path, symbol_name, symbol_kind, name_node, definition_node, caveatsForDefinition(if (symbol_kind == .other) .constant else .variable, symbol_name, generated));
        },
    }
}

const CaveatKind = enum {
    module,
    class,
    function,
    method,
    constant,
    variable,
};

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

fn caveatsForModule(generated: bool) []const []const u8 {
    return if (generated) &generated_caveats else &supported_caveats;
}

fn caveatsForDefinition(kind: CaveatKind, _: []const u8, generated: bool) []const []const u8 {
    if (generated) return &generated_caveats;
    return switch (kind) {
        .module, .class, .function => &supported_caveats,
        .method => &method_caveats,
        .constant => &constant_caveats,
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

test "Python query contract exposes expected capture names" {
    const query = try compilePythonQuery();
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

test "extracts supported Python query symbols in deterministic source order" {
    var result = try extractPythonQuerySymbols(std.testing.allocator, "pkg/supported_subset.py", supported_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 11), result.symbols.len);
    try std.testing.expectEqual(@as(usize, 3), result.decorator_capture_count);
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

test "empty Python fixture returns a module symbol only" {
    var result = try extractPythonQuerySymbols(std.testing.allocator, "pkg/empty.py", empty_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 1), result.symbols.len);
    try expectSymbol(result.symbols[0], "pkg/empty.py", .module, 1, 1);
}

test "invalid partial Python fixture fails safely without diagnostics" {
    var result = try extractPythonQuerySymbols(std.testing.allocator, "pkg/invalid_partial.py", invalid_partial_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.failed, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try expectCaveat(result.caveats, "no parser diagnostics or source snippets exposed");
}

test "generated Python fixture is parsed with generated caveats only" {
    var result = try extractPythonQuerySymbols(std.testing.allocator, "pkg/generated.py", generated_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 3), result.symbols.len);
    try expectSymbol(result.symbols[0], "pkg/generated.py", .module, 1, 7);
    try expectSymbol(result.symbols[1], "AUTO_CONSTANT", .other, 3, 3);
    try expectSymbol(result.symbols[2], "generated_function", .function, 5, 6);
    try expectCaveat(result.symbols[2].caveats, "generated-file markers are caveated only; generated-source policy is not evaluated by this proof");
}

test "unsupported and unsafe Python query paths fail closed" {
    var result = try extractPythonQuerySymbols(std.testing.allocator, "docs/unsupported.md", unsupported_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.unsupported, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try expectCaveat(result.caveats, "no Python parser was run for the unsupported path");

    try std.testing.expectError(error.InvalidRepoRelativePath, extractPythonQuerySymbols(std.testing.allocator, "../private/source.py", "def hidden():\n    return 1\n"));
}
