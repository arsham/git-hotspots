const std = @import("std");
const provider = @import("provider");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_javascript() *const c.TSLanguage;

const query_source = @embedFile("fixtures/tree_sitter_javascript_query/javascript-symbols.scm");
const supported_source = @embedFile("fixtures/tree_sitter_javascript_query/supported_subset.mjs");
const commonjs_source = @embedFile("fixtures/tree_sitter_javascript_query/commonjs.cjs");
const jsx_source = @embedFile("fixtures/tree_sitter_javascript_query/jsx_component.jsx");
const anonymous_exports_source = @embedFile("fixtures/tree_sitter_javascript_query/anonymous_exports.js");
const generated_source = @embedFile("fixtures/tree_sitter_javascript_query/generated.min.js");
const invalid_partial_source = @embedFile("fixtures/tree_sitter_javascript_query/invalid_partial.js");
const unsupported_source = @embedFile("fixtures/tree_sitter_javascript_query/unsupported.tsx");
const empty_source = @embedFile("fixtures/tree_sitter_javascript_query/empty.js");

const provider_name = "tree-sitter-javascript-query-proof";
const query_version = "javascript-symbol-query-v1";
const expected_capture_names = [_][]const u8{
    "javascript.module",
    "javascript.definition.name",
    "javascript.class.definition",
    "javascript.function.definition",
    "javascript.method.definition",
    "javascript.variable.definition",
    "javascript.commonjs.definition",
};

const supported_caveats = [_][]const u8{
    "test-only in-memory Tree-sitter JavaScript query proof",
    "JavaScript grammar v0.25.0; query version: " ++ query_version,
    "project-owned query asset: tests/fixtures/tree_sitter_javascript_query/javascript-symbols.scm",
    "range convention: one-based inclusive line range from the symbol node",
    "ordering convention: deterministic source order by symbol node start byte; the module symbol is first",
    "module names are repo-relative .js/.mjs/.cjs/.jsx paths; package, workspace, Node, and module-resolution analysis are out of scope",
    "runtime JavaScript --symbols output is not implemented by this proof",
    "TypeScript and TSX paths are unsupported by this JavaScript query contract",
    provider.CurrentSymbolEvidence.semantics,
};
const unsupported_caveats = [_][]const u8{
    "unsupported path: only repo-relative .js, .mjs, .cjs, and admitted .jsx files are JavaScript query candidates",
    "no JavaScript parser was run for the unsupported path",
    "TypeScript and TSX paths are unsupported by this JavaScript query contract",
};
const failed_caveats = [_][]const u8{
    "parse failed before safe JavaScript query symbol proof completed",
    "no parser diagnostics or source snippets exposed",
};
const method_caveats = supported_caveats ++ [_][]const u8{
    "method classification is derived from a direct class body; method names are bare property identifiers",
};
const constant_caveats = supported_caveats ++ [_][]const u8{
    "constant-like uppercase module bindings map to provider SymbolKind.other because no constant-specific kind exists",
};
const variable_caveats = supported_caveats ++ [_][]const u8{
    "module-level simple bindings map to provider SymbolKind.variable",
};
const commonjs_caveats = supported_caveats ++ [_][]const u8{
    "CommonJS named exports are admitted only for deterministic exports.<name> and module.exports.<name> assignments",
};
const jsx_caveats = supported_caveats ++ [_][]const u8{
    ".jsx parsing is admitted for this JavaScript grammar proof; TSX remains unsupported",
};
const generated_minified_caveats = supported_caveats ++ [_][]const u8{
    "generated-file markers and minified one-line source are caveated only; generated/minified policy is not evaluated by this proof",
};
const anonymous_export_caveats = supported_caveats ++ [_][]const u8{
    "anonymous default or module.exports assignments are skipped because no deterministic public name is available",
};

const DefinitionKind = enum {
    class,
    function,
    method,
    variable,
    commonjs,
};

const CaveatKind = enum {
    module,
    class,
    function,
    method,
    constant,
    variable,
    commonjs,
};

const SourceProfile = struct {
    generated_or_minified: bool,
    jsx: bool,
    anonymous_export_skip_count: usize,
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
    anonymous_export_skip_count: usize = 0,

    fn deinit(self: *SymbolExtractionResult, allocator: std.mem.Allocator) void {
        if (self.symbols.len > 0) allocator.free(self.symbols);
        self.* = undefined;
    }
};

fn extractJavaScriptQuerySymbols(
    allocator: std.mem.Allocator,
    repo_relative_path: []const u8,
    source: []const u8,
) !SymbolExtractionResult {
    try provider.validateRepoRelativePath(repo_relative_path);

    if (!isSupportedJavaScriptPath(repo_relative_path)) {
        return .{
            .failure = .unsupported,
            .symbols = &.{},
            .caveats = &unsupported_caveats,
        };
    }

    const parser = c.ts_parser_new() orelse return failedResult();
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_javascript())) return failedResult();

    const source_len = std.math.cast(u32, source.len) orelse return failedResult();
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return failedResult();
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return failedResult();

    const query = try compileJavaScriptQuery();
    defer c.ts_query_delete(query);

    const cursor = c.ts_query_cursor_new() orelse return failedResult();
    defer c.ts_query_cursor_delete(cursor);

    var candidates: std.ArrayList(SymbolCandidate) = .empty;
    defer candidates.deinit(allocator);

    const profile = sourceProfile(repo_relative_path, source);

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
            if (std.mem.eql(u8, name, "javascript.module")) {
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
            } else if (std.mem.eql(u8, name, "javascript.class.definition")) {
                definition_node = capture.node;
                definition_kind = .class;
            } else if (std.mem.eql(u8, name, "javascript.function.definition")) {
                definition_node = capture.node;
                definition_kind = .function;
            } else if (std.mem.eql(u8, name, "javascript.method.definition")) {
                definition_node = capture.node;
                definition_kind = .method;
            } else if (std.mem.eql(u8, name, "javascript.variable.definition")) {
                definition_node = capture.node;
                definition_kind = .variable;
            } else if (std.mem.eql(u8, name, "javascript.commonjs.definition")) {
                definition_node = capture.node;
                definition_kind = .commonjs;
            } else if (std.mem.eql(u8, name, "javascript.definition.name")) {
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

    var symbols: std.ArrayList(provider.CurrentSymbolEvidence) = .empty;
    errdefer symbols.deinit(allocator);
    for (candidates.items) |candidate| try symbols.append(allocator, candidate.symbol);

    return .{
        .failure = .ok,
        .symbols = try symbols.toOwnedSlice(allocator),
        .caveats = caveatsForModule(profile),
        .anonymous_export_skip_count = profile.anonymous_export_skip_count,
    };
}

fn compileJavaScriptQuery() !*c.TSQuery {
    var error_offset: u32 = 0;
    var error_type: c.TSQueryError = c.TSQueryErrorNone;
    return c.ts_query_new(
        tree_sitter_javascript(),
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
    profile: SourceProfile,
) !void {
    const symbol_name = nodeSourceSlice(source, name_node) orelse return;
    switch (kind) {
        .class => try appendCandidate(allocator, candidates, path, symbol_name, .class, name_node, definition_node, caveatsForDefinition(.class, symbol_name, profile)),
        .function => try appendCandidate(allocator, candidates, path, symbol_name, .function, name_node, definition_node, caveatsForDefinition(.function, symbol_name, profile)),
        .method => {
            if (!isDirectClassBodyMethod(definition_node)) return;
            try appendCandidate(allocator, candidates, path, symbol_name, .method, name_node, definition_node, caveatsForDefinition(.method, symbol_name, profile));
        },
        .variable => {
            if (!isModuleLevelJavaScriptDefinition(definition_node)) return;
            const symbol_kind: provider.SymbolKind = if (isConstantLikeName(symbol_name)) .other else .variable;
            try appendCandidate(allocator, candidates, path, symbol_name, symbol_kind, name_node, definition_node, caveatsForDefinition(if (symbol_kind == .other) .constant else .variable, symbol_name, profile));
        },
        .commonjs => {
            if (!isModuleLevelJavaScriptDefinition(definition_node)) return;
            const left = childByFieldName(definition_node, "left");
            if (!isSupportedCommonJsLeft(source, left)) return;
            const right = childByFieldName(definition_node, "right");
            const symbol_kind = commonJsSymbolKind(symbol_name, right);
            try appendCandidate(allocator, candidates, path, symbol_name, symbol_kind, name_node, definition_node, caveatsForDefinition(.commonjs, symbol_name, profile));
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
    if (profile.jsx) return &jsx_caveats;
    if (profile.anonymous_export_skip_count > 0) return &anonymous_export_caveats;
    return &supported_caveats;
}

fn caveatsForDefinition(kind: CaveatKind, _: []const u8, profile: SourceProfile) []const []const u8 {
    if (profile.generated_or_minified) return &generated_minified_caveats;
    if (profile.jsx) return &jsx_caveats;
    return switch (kind) {
        .module, .class, .function => &supported_caveats,
        .method => &method_caveats,
        .constant => &constant_caveats,
        .variable => &variable_caveats,
        .commonjs => &commonjs_caveats,
    };
}

fn sourceProfile(repo_relative_path: []const u8, source: []const u8) SourceProfile {
    return .{
        .generated_or_minified = hasGeneratedMarker(source) or looksMinified(source),
        .jsx = std.mem.endsWith(u8, repo_relative_path, ".jsx"),
        .anonymous_export_skip_count = anonymousExportSkipCount(source),
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

fn anonymousExportSkipCount(source: []const u8) usize {
    var count: usize = 0;
    if (std.mem.indexOf(u8, source, "export default function (") != null) count += 1;
    if (std.mem.indexOf(u8, source, "module.exports = function (") != null) count += 1;
    return count;
}

fn isSupportedJavaScriptPath(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".js") or
        std.mem.endsWith(u8, path, ".mjs") or
        std.mem.endsWith(u8, path, ".cjs") or
        std.mem.endsWith(u8, path, ".jsx");
}

fn isSupportedCommonJsLeft(source: []const u8, left: c.TSNode) bool {
    const left_source = nodeSourceSlice(source, left) orelse return false;
    if (std.mem.eql(u8, left_source, "module.exports") or std.mem.eql(u8, left_source, "exports")) return false;
    return std.mem.startsWith(u8, left_source, "exports.") or std.mem.startsWith(u8, left_source, "module.exports.");
}

fn commonJsSymbolKind(symbol_name: []const u8, right: c.TSNode) provider.SymbolKind {
    if (!c.ts_node_is_null(right)) {
        const right_type = std.mem.span(c.ts_node_type(right));
        if (std.mem.eql(u8, right_type, "function_expression") or std.mem.eql(u8, right_type, "arrow_function")) return .function;
        if (std.mem.eql(u8, right_type, "class")) return .class;
    }
    return if (isConstantLikeName(symbol_name)) .other else .variable;
}

fn isDirectClassBodyMethod(node: c.TSNode) bool {
    const parent = c.ts_node_parent(node);
    if (c.ts_node_is_null(parent) or !nodeTypeIs(parent, "class_body")) return false;

    const grandparent = c.ts_node_parent(parent);
    return !c.ts_node_is_null(grandparent) and (nodeTypeIs(grandparent, "class_declaration") or nodeTypeIs(grandparent, "class"));
}

fn isModuleLevelJavaScriptDefinition(node: c.TSNode) bool {
    var current = node;
    while (true) {
        const parent = c.ts_node_parent(current);
        if (c.ts_node_is_null(parent)) return false;
        if (nodeTypeIs(parent, "program")) return true;
        if (nodeTypeIs(parent, "export_statement") or nodeTypeIs(parent, "lexical_declaration") or nodeTypeIs(parent, "variable_declaration") or nodeTypeIs(parent, "expression_statement")) {
            current = parent;
            continue;
        }
        if (nodeTypeIs(parent, "statement_block") or nodeTypeIs(parent, "class_body") or nodeTypeIs(parent, "function_declaration") or nodeTypeIs(parent, "function_expression") or nodeTypeIs(parent, "arrow_function") or nodeTypeIs(parent, "method_definition") or nodeTypeIs(parent, "class_declaration") or nodeTypeIs(parent, "class")) return false;
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

test "JavaScript query contract exposes expected capture names" {
    const query = try compileJavaScriptQuery();
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

test "extracts supported JavaScript query symbols in deterministic source order" {
    var result = try extractJavaScriptQuerySymbols(std.testing.allocator, "packages/app/src/supported_subset.mjs", supported_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 12), result.symbols.len);
    try expectSymbol(result.symbols[0], "packages/app/src/supported_subset.mjs", .module, 1, 30);
    try expectSymbol(result.symbols[1], "EXPORTED_CONSTANT", .other, 2, 2);
    try expectSymbol(result.symbols[2], "mutableValue", .variable, 3, 3);
    try expectSymbol(result.symbols[3], "legacyValue", .variable, 4, 4);
    try expectSymbol(result.symbols[4], "topFunction", .function, 6, 11);
    try expectSymbol(result.symbols[5], "innerFunction", .function, 7, 9);
    try expectSymbol(result.symbols[6], "LocalClass", .class, 13, 20);
    try expectSymbol(result.symbols[7], "methodOne", .method, 14, 19);
    try expectSymbol(result.symbols[8], "methodInner", .function, 15, 17);
    try expectSymbol(result.symbols[9], "ExportedClass", .class, 22, 26);
    try expectSymbol(result.symbols[10], "render", .method, 23, 25);
    try expectSymbol(result.symbols[11], "ignoredObject", .variable, 28, 28);
    try expectNoSymbol(result.symbols, "dynamicName");
    try expectCaveat(result.symbols[1].caveats, "constant-like uppercase module bindings map to provider SymbolKind.other because no constant-specific kind exists");
    try expectCaveat(result.symbols[2].caveats, "module-level simple bindings map to provider SymbolKind.variable");
    try expectCaveat(result.symbols[7].caveats, "method classification is derived from a direct class body; method names are bare property identifiers");
}

test "CommonJS fixture admits deterministic named exports only" {
    var result = try extractJavaScriptQuerySymbols(std.testing.allocator, "packages/lib/commonjs.cjs", commonjs_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 6), result.symbols.len);
    try expectSymbol(result.symbols[0], "packages/lib/commonjs.cjs", .module, 1, 12);
    try expectSymbol(result.symbols[1], "localOnly", .variable, 2, 2);
    try expectSymbol(result.symbols[2], "makeThing", .function, 3, 5);
    try expectSymbol(result.symbols[3], "Widget", .class, 6, 10);
    try expectSymbol(result.symbols[4], "run", .method, 7, 9);
    try expectSymbol(result.symbols[5], "ANSWER", .other, 11, 11);
    try expectCaveat(result.symbols[2].caveats, "CommonJS named exports are admitted only for deterministic exports.<name> and module.exports.<name> assignments");
}

test "JSX fixture is admitted while TSX remains unsupported" {
    var result = try extractJavaScriptQuerySymbols(std.testing.allocator, "packages/app/src/jsx_component.jsx", jsx_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 3), result.symbols.len);
    try expectSymbol(result.symbols[0], "packages/app/src/jsx_component.jsx", .module, 1, 6);
    try expectSymbol(result.symbols[1], "View", .function, 1, 3);
    try expectSymbol(result.symbols[2], "element", .variable, 5, 5);
    try expectCaveat(result.caveats, ".jsx parsing is admitted for this JavaScript grammar proof; TSX remains unsupported");
}

test "anonymous exports are skipped instead of invented" {
    var result = try extractJavaScriptQuerySymbols(std.testing.allocator, "src/anonymous_exports.js", anonymous_exports_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 1), result.symbols.len);
    try expectSymbol(result.symbols[0], "src/anonymous_exports.js", .module, 1, 8);
    try std.testing.expectEqual(@as(usize, 2), result.anonymous_export_skip_count);
    try expectCaveat(result.caveats, "anonymous default or module.exports assignments are skipped because no deterministic public name is available");
}

test "empty JavaScript fixture returns a module symbol only" {
    var result = try extractJavaScriptQuerySymbols(std.testing.allocator, "src/empty.js", empty_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 1), result.symbols.len);
    try expectSymbol(result.symbols[0], "src/empty.js", .module, 1, 1);
}

test "invalid partial JavaScript fixture fails safely without diagnostics" {
    var result = try extractJavaScriptQuerySymbols(std.testing.allocator, "src/invalid_partial.js", invalid_partial_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.failed, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try expectCaveat(result.caveats, "no parser diagnostics or source snippets exposed");
}

test "generated and minified JavaScript fixture is parsed with caveats only" {
    var result = try extractJavaScriptQuerySymbols(std.testing.allocator, "src/generated.min.js", generated_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 3), result.symbols.len);
    try expectSymbol(result.symbols[0], "src/generated.min.js", .module, 1, 2);
    try expectSymbol(result.symbols[1], "GENERATED_VALUE", .other, 1, 1);
    try expectSymbol(result.symbols[2], "generatedFunction", .function, 1, 1);
    try expectCaveat(result.symbols[2].caveats, "generated-file markers and minified one-line source are caveated only; generated/minified policy is not evaluated by this proof");
}

test "unsupported and unsafe JavaScript query paths fail closed" {
    var result = try extractJavaScriptQuerySymbols(std.testing.allocator, "packages/app/src/unsupported.tsx", unsupported_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.unsupported, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try expectCaveat(result.caveats, "TypeScript and TSX paths are unsupported by this JavaScript query contract");

    try std.testing.expectError(error.InvalidRepoRelativePath, extractJavaScriptQuerySymbols(std.testing.allocator, "../private/source.js", "export function hidden() {}\n"));
}
