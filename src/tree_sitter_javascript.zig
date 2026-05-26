const std = @import("std");
const provider = @import("provider.zig");
const tree_sitter_common = @import("tree_sitter_common.zig");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_javascript() *const c.TSLanguage;

pub const provider_name = "tree-sitter-javascript";
pub const provider_version = "tree-sitter-core@v0.26.9/tree-sitter-javascript@v0.25.0/javascript-symbol-query-v1";
const max_file_bytes: u64 = 1024 * 1024;
const query_source = @embedFile("queries/javascript-symbols.scm");

const ok_caveats = [_][]const u8{
    "current working-tree enrichment only; file-level Git evidence remains product truth",
    "supported subset: module roots, class declarations, function declarations, direct class methods, module-level simple bindings, and deterministic named CommonJS exports",
    "range convention: one-based inclusive lines; method names are bare property identifiers",
    "provider order: module symbol first, then deterministic source order by symbol node start byte",
    "module names are repo-relative .js/.mjs/.cjs/.jsx paths; package, workspace, Node, module-resolution, TypeScript, TSX, LSP, and symbol history are out of scope",
    "dynamic property names, imports, dependency graphs, generated-source policy, scoring, and semantic moves are out of scope",
};
const unsupported_caveats = [_][]const u8{
    "provider unsupported: only repo-relative .js, .mjs, .cjs, and admitted .jsx files are parsed",
    "TypeScript and TSX paths are unsupported by this JavaScript provider",
    "no parser diagnostics or source snippets exposed",
};
const unavailable_caveats = [_][]const u8{
    "current working-tree file unavailable or not a regular bounded file",
    "no parser diagnostics, source snippets, absolute paths, remotes, author identities, commit messages, or private repo names exposed",
};
const failed_caveats = [_][]const u8{
    "provider failed to parse supported JavaScript symbol evidence",
    "invalid or partial JavaScript source failed closed without parser diagnostics or source snippets",
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
const commonjs_caveats = ok_caveats ++ [_][]const u8{
    "CommonJS named exports are admitted only for deterministic exports.<name> and module.exports.<name> assignments",
};
const jsx_caveats = ok_caveats ++ [_][]const u8{
    ".jsx parsing is admitted by the JavaScript provider; TSX remains unsupported",
};
const generated_minified_caveats = ok_caveats ++ [_][]const u8{
    "generated-file markers and minified one-line source are caveated only; generated/minified policy is not evaluated by this provider",
};
const anonymous_export_caveats = ok_caveats ++ [_][]const u8{
    "anonymous default or module.exports assignments are skipped because no deterministic public name is available",
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

pub fn isSupportedJavaScriptPath(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".js") or
        std.mem.endsWith(u8, path, ".mjs") or
        std.mem.endsWith(u8, path, ".cjs") or
        std.mem.endsWith(u8, path, ".jsx");
}

pub fn extractPath(allocator: std.mem.Allocator, io: std.Io, repo_root: []const u8, repo_relative_path: []const u8) !Extraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!isSupportedJavaScriptPath(repo_relative_path)) {
        return extraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &unsupported_caveats, &.{});
    }

    const source = try tree_sitter_common.readBoundedFile(allocator, io, repo_root, repo_relative_path, max_file_bytes) orelse return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    defer allocator.free(source);

    return extractSource(allocator, repo_relative_path, source);
}

pub fn extractSource(allocator: std.mem.Allocator, repo_relative_path: []const u8, source: []const u8) !Extraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!isSupportedJavaScriptPath(repo_relative_path)) {
        return extraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &unsupported_caveats, &.{});
    }

    const parser = c.ts_parser_new() orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_javascript())) return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});

    const source_len = std.math.cast(u32, source.len) orelse return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});

    const query = compileJavaScriptQuery() catch return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_query_delete(query);

    const cursor = c.ts_query_cursor_new() orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_query_cursor_delete(cursor);

    var candidates: std.ArrayList(SymbolCandidate) = .empty;
    defer candidates.deinit(allocator);
    errdefer freeCandidateSymbols(allocator, candidates.items);

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

    const symbols = try allocator.alloc(provider.CurrentSymbolEvidence, candidates.items.len);
    errdefer allocator.free(symbols);
    for (candidates.items, 0..) |candidate, i| symbols[i] = candidate.symbol;
    candidates.clearRetainingCapacity();

    return extraction(allocator, repo_relative_path, .ok, .fresh, .high, caveatsForModule(profile), symbols);
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
        .class => try appendCandidate(allocator, candidates, path, symbol_name, .class, name_node, definition_node, caveatsForDefinition(.class, profile)),
        .function => try appendCandidate(allocator, candidates, path, symbol_name, .function, name_node, definition_node, caveatsForDefinition(.function, profile)),
        .method => {
            if (!isDirectClassBodyMethod(definition_node)) return;
            try appendCandidate(allocator, candidates, path, symbol_name, .method, name_node, definition_node, caveatsForDefinition(.method, profile));
        },
        .variable => {
            if (!isModuleLevelJavaScriptDefinition(definition_node)) return;
            const symbol_kind: provider.SymbolKind = if (isConstantLikeName(symbol_name)) .other else .variable;
            try appendCandidate(allocator, candidates, path, symbol_name, symbol_kind, name_node, definition_node, caveatsForDefinition(if (symbol_kind == .other) .constant else .variable, profile));
        },
        .commonjs => {
            if (!isModuleLevelJavaScriptDefinition(definition_node)) return;
            const left = childByFieldName(definition_node, "left");
            if (!isSupportedCommonJsLeft(source, left)) return;
            const right = childByFieldName(definition_node, "right");
            const symbol_kind = commonJsSymbolKind(symbol_name, right);
            try appendCandidate(allocator, candidates, path, symbol_name, symbol_kind, name_node, definition_node, caveatsForDefinition(.commonjs, profile));
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
    if (profile.generated_or_minified) return &generated_minified_caveats;
    if (profile.jsx) return &jsx_caveats;
    if (profile.anonymous_export_skip_count > 0) return &anonymous_export_caveats;
    return &ok_caveats;
}

fn caveatsForDefinition(kind: CaveatKind, profile: SourceProfile) []const []const u8 {
    if (profile.generated_or_minified) return &generated_minified_caveats;
    if (profile.jsx) return &jsx_caveats;
    return switch (kind) {
        .module, .class, .function => &ok_caveats,
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

test "extract source handles supported JavaScript subset in source order" {
    const source =
        \\// Supported JavaScript query subset fixture.
        \\export const EXPORTED_CONSTANT = 1;
        \\let mutableValue = 2;
        \\var legacyValue = 3;
        \\
        \\export function topFunction(input) {
        \\  function innerFunction() {
        \\    return input;
        \\  }
        \\  return innerFunction();
        \\}
        \\
        \\class LocalClass {
        \\  methodOne() {
        \\    function methodInner() {
        \\      return 1;
        \\    }
        \\    return methodInner();
        \\  }
        \\}
        \\
        \\export class ExportedClass {
        \\  render() {
        \\    return "<tag>[safe](link)";
        \\  }
        \\}
        \\
        \\function café() {
        \\  return "unicode";
        \\}
        \\
        \\const ignoredObject = { field: 1 };
        \\({ dynamicName: mutableValue });
        \\
    ;

    var result = try extractSource(std.testing.allocator, "packages/app/src/supported_subset.mjs", source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.provider.failure);
    try std.testing.expectEqual(@as(usize, 13), result.symbols.len);
    try expectSymbol(result.symbols[0], "packages/app/src/supported_subset.mjs", .module, 1, 34);
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
    try expectSymbol(result.symbols[11], "café", .function, 28, 30);
    try expectSymbol(result.symbols[12], "ignoredObject", .variable, 32, 32);
    try expectNoSymbol(result.symbols, "dynamicName");
    try expectCaveat(result.symbols[1].caveats, "constant-like uppercase module bindings map to provider SymbolKind.other because no constant-specific kind exists");
    try expectCaveat(result.symbols[2].caveats, "module-level simple bindings map to provider SymbolKind.variable");
    try expectCaveat(result.symbols[7].caveats, "method classification is derived from a direct class body; method names are bare property identifiers");
}

test "extract source handles CommonJS JSX anonymous empty invalid generated unsupported and unsafe JavaScript inputs" {
    const commonjs_source =
        \\// CommonJS export fixture.
        \\const localOnly = 1;
        \\exports.makeThing = function makeThing() {
        \\  return localOnly;
        \\};
        \\module.exports.Widget = class Widget {
        \\  run() {
        \\    return "ok";
        \\  }
        \\};
        \\exports.ANSWER = 42;
        \\
    ;
    var commonjs = try extractSource(std.testing.allocator, "packages/lib/commonjs.cjs", commonjs_source);
    defer commonjs.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, commonjs.provider.failure);
    try std.testing.expectEqual(@as(usize, 6), commonjs.symbols.len);
    try expectSymbol(commonjs.symbols[0], "packages/lib/commonjs.cjs", .module, 1, 12);
    try expectSymbol(commonjs.symbols[2], "makeThing", .function, 3, 5);
    try expectSymbol(commonjs.symbols[3], "Widget", .class, 6, 10);
    try expectSymbol(commonjs.symbols[5], "ANSWER", .other, 11, 11);
    try expectCaveat(commonjs.symbols[2].caveats, "CommonJS named exports are admitted only for deterministic exports.<name> and module.exports.<name> assignments");

    var jsx = try extractSource(std.testing.allocator, "packages/app/src/jsx_component.jsx", "export function View() {\n  return <main id=\"proof\">ok</main>;\n}\n\nconst element = <View />;\n");
    defer jsx.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, jsx.provider.failure);
    try std.testing.expectEqual(@as(usize, 3), jsx.symbols.len);
    try expectSymbol(jsx.symbols[1], "View", .function, 1, 3);
    try expectSymbol(jsx.symbols[2], "element", .variable, 5, 5);
    try expectCaveat(jsx.provider.caveats, ".jsx parsing is admitted by the JavaScript provider; TSX remains unsupported");

    var anonymous = try extractSource(std.testing.allocator, "src/anonymous_exports.js", "export default function () {\n  return 1;\n}\n\nmodule.exports = function () {\n  return 2;\n};\n");
    defer anonymous.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, anonymous.provider.failure);
    try std.testing.expectEqual(@as(usize, 1), anonymous.symbols.len);
    try expectCaveat(anonymous.provider.caveats, "anonymous default or module.exports assignments are skipped because no deterministic public name is available");

    var empty = try extractSource(std.testing.allocator, "src/empty.js", "");
    defer empty.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, empty.provider.failure);
    try std.testing.expectEqual(@as(usize, 1), empty.symbols.len);
    try expectSymbol(empty.symbols[0], "src/empty.js", .module, 1, 1);

    var broken = try extractSource(std.testing.allocator, "src/invalid_partial.js", "export function broken(\n");
    defer broken.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.failed, broken.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), broken.symbols.len);
    try expectCaveat(broken.provider.caveats, "invalid or partial JavaScript source failed closed without parser diagnostics or source snippets");

    var generated = try extractSource(std.testing.allocator, "src/generated.min.js", "/* Code generated; DO NOT EDIT. */const GENERATED_VALUE=1;function generatedFunction(){return GENERATED_VALUE;}\n");
    defer generated.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, generated.provider.failure);
    try std.testing.expectEqual(@as(usize, 3), generated.symbols.len);
    try expectSymbol(generated.symbols[1], "GENERATED_VALUE", .other, 1, 1);
    try expectSymbol(generated.symbols[2], "generatedFunction", .function, 1, 1);
    try expectCaveat(generated.symbols[2].caveats, "generated-file markers and minified one-line source are caveated only; generated/minified policy is not evaluated by this provider");

    var unsupported = try extractSource(std.testing.allocator, "packages/app/src/unsupported.tsx", "export function hidden() {}\n");
    defer unsupported.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unsupported, unsupported.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), unsupported.symbols.len);

    try std.testing.expectError(error.InvalidRepoRelativePath, extractSource(std.testing.allocator, "../private/source.js", "export function hidden() {}\n"));
}
