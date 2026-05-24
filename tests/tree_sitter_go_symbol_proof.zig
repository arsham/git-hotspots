const std = @import("std");
const provider = @import("provider");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_go() *const c.TSLanguage;

const provider_name = "tree-sitter-go-proof";
const supported_caveats = [_][]const u8{
    "test-only in-memory Tree-sitter Go proof",
    "supported subset: package clauses, top-level functions, methods, struct/interface type specs, and top-level const/var names",
    "direct AST traversal only; no Tree-sitter query files or custom query execution",
    "range convention: one-based inclusive line range from the enclosing Go declaration node",
    "ordering convention: source order from Tree-sitter named-child traversal",
    "build tags, generated-file markers, and cgo-adjacent imports are not evaluated by this proof",
    provider.CurrentSymbolEvidence.semantics,
};
const unsupported_caveats = [_][]const u8{
    "unsupported path: only repo-relative .go files are parsed",
    "no parser diagnostics or source snippets exposed",
};
const failed_caveats = [_][]const u8{
    "parse failed before safe symbol extraction completed",
    "no parser diagnostics or source snippets exposed",
};
const method_caveats = supported_caveats ++ [_][]const u8{
    "method names are bare identifiers; receiver-qualified naming is out of scope for this proof",
};
const struct_caveats = supported_caveats ++ [_][]const u8{
    "struct type specs map to provider SymbolKind.type because no struct-specific kind exists",
};
const interface_caveats = supported_caveats ++ [_][]const u8{
    "interface type specs map to provider SymbolKind.type because no interface-specific kind exists",
};
const const_caveats = supported_caveats ++ [_][]const u8{
    "const names map to provider SymbolKind.other because no constant-specific kind exists",
};

const SymbolExtractionResult = struct {
    failure: provider.Failure,
    symbols: []provider.CurrentSymbolEvidence,
    caveats: []const []const u8,

    fn deinit(self: *SymbolExtractionResult, allocator: std.mem.Allocator) void {
        if (self.symbols.len > 0) allocator.free(self.symbols);
        self.* = undefined;
    }
};

/// Test-only extractor proof for the current supported Go subset:
/// - input is in-memory Go source plus a repo-relative path;
/// - only package clauses, top-level functions, methods, struct/interface type
///   specs, and top-level const/var names are emitted;
/// - traversal is direct Tree-sitter AST walking, not query execution;
/// - ranges are one-based, inclusive line ranges from the enclosing Go
///   declaration node;
/// - unsupported paths and parser failures expose only provider failure/caveats,
///   never raw parser diagnostics, source snippets, or absolute paths.
fn extractGoCurrentSymbols(
    allocator: std.mem.Allocator,
    repo_relative_path: []const u8,
    source: []const u8,
) !SymbolExtractionResult {
    try provider.validateRepoRelativePath(repo_relative_path);

    if (!std.mem.endsWith(u8, repo_relative_path, ".go")) {
        return .{
            .failure = .unsupported,
            .symbols = &.{},
            .caveats = &unsupported_caveats,
        };
    }

    const parser = c.ts_parser_new() orelse return failedResult();
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_go())) return failedResult();

    const source_len = std.math.cast(u32, source.len) orelse return failedResult();
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return failedResult();
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return failedResult();

    var symbols: std.ArrayList(provider.CurrentSymbolEvidence) = .empty;
    errdefer symbols.deinit(allocator);

    try collectTopLevelDeclarations(allocator, &symbols, repo_relative_path, source, root);

    return .{
        .failure = .ok,
        .symbols = try symbols.toOwnedSlice(allocator),
        .caveats = &supported_caveats,
    };
}

fn failedResult() SymbolExtractionResult {
    return .{
        .failure = .failed,
        .symbols = &.{},
        .caveats = &failed_caveats,
    };
}

fn collectTopLevelDeclarations(
    allocator: std.mem.Allocator,
    symbols: *std.ArrayList(provider.CurrentSymbolEvidence),
    path: []const u8,
    source: []const u8,
    root: c.TSNode,
) !void {
    if (c.ts_node_is_null(root)) return;
    if (!nodeTypeIs(root, "source_file")) return;

    const child_count = c.ts_node_named_child_count(root);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(root, index);
        if (nodeTypeIs(child, "package_clause")) {
            try appendSymbolFromFirstNamedChild(allocator, symbols, path, source, child, child, .module, &supported_caveats);
        } else if (nodeTypeIs(child, "function_declaration")) {
            try appendSymbolFromField(allocator, symbols, path, source, child, child, "name", .function, &supported_caveats);
        } else if (nodeTypeIs(child, "method_declaration")) {
            try appendSymbolFromField(allocator, symbols, path, source, child, child, "name", .method, &method_caveats);
        } else if (nodeTypeIs(child, "type_declaration")) {
            try collectTypeSpecs(allocator, symbols, path, source, child);
        } else if (nodeTypeIs(child, "const_declaration")) {
            try collectConstOrVarSpecs(allocator, symbols, path, source, child, "const_spec", .other, &const_caveats);
        } else if (nodeTypeIs(child, "var_declaration")) {
            try collectConstOrVarSpecs(allocator, symbols, path, source, child, "var_spec", .variable, &supported_caveats);
        }
    }
}

fn collectTypeSpecs(
    allocator: std.mem.Allocator,
    symbols: *std.ArrayList(provider.CurrentSymbolEvidence),
    path: []const u8,
    source: []const u8,
    declaration: c.TSNode,
) !void {
    const child_count = c.ts_node_named_child_count(declaration);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(declaration, index);
        if (!nodeTypeIs(child, "type_spec")) continue;

        const type_node = childByField(child, "type");
        if (c.ts_node_is_null(type_node)) continue;

        if (nodeTypeIs(type_node, "struct_type")) {
            try appendSymbolFromField(allocator, symbols, path, source, child, declaration, "name", .type, &struct_caveats);
        } else if (nodeTypeIs(type_node, "interface_type")) {
            try appendSymbolFromField(allocator, symbols, path, source, child, declaration, "name", .type, &interface_caveats);
        }
    }
}

fn collectConstOrVarSpecs(
    allocator: std.mem.Allocator,
    symbols: *std.ArrayList(provider.CurrentSymbolEvidence),
    path: []const u8,
    source: []const u8,
    declaration: c.TSNode,
    spec_type: []const u8,
    kind: provider.SymbolKind,
    caveats: []const []const u8,
) !void {
    const child_count = c.ts_node_named_child_count(declaration);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(declaration, index);
        if (nodeTypeIs(child, spec_type)) {
            try collectLeadingIdentifierNames(allocator, symbols, path, source, child, declaration, kind, caveats);
        } else if (nodeTypeIs(child, "var_spec_list")) {
            try collectConstOrVarSpecs(allocator, symbols, path, source, child, spec_type, kind, caveats);
        }
    }
}

fn collectLeadingIdentifierNames(
    allocator: std.mem.Allocator,
    symbols: *std.ArrayList(provider.CurrentSymbolEvidence),
    path: []const u8,
    source: []const u8,
    spec: c.TSNode,
    declaration: c.TSNode,
    kind: provider.SymbolKind,
    caveats: []const []const u8,
) !void {
    const child_count = c.ts_node_named_child_count(spec);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(spec, index);
        if (!nodeTypeIs(child, "identifier")) break;
        try appendSymbol(allocator, symbols, path, source, child, declaration, kind, caveats);
    }
}

fn appendSymbolFromField(
    allocator: std.mem.Allocator,
    symbols: *std.ArrayList(provider.CurrentSymbolEvidence),
    path: []const u8,
    source: []const u8,
    name_owner: c.TSNode,
    range_node: c.TSNode,
    field_name: []const u8,
    kind: provider.SymbolKind,
    caveats: []const []const u8,
) !void {
    const name_node = childByField(name_owner, field_name);
    if (!c.ts_node_is_null(name_node)) {
        try appendSymbol(allocator, symbols, path, source, name_node, range_node, kind, caveats);
    }
}

fn appendSymbolFromFirstNamedChild(
    allocator: std.mem.Allocator,
    symbols: *std.ArrayList(provider.CurrentSymbolEvidence),
    path: []const u8,
    source: []const u8,
    name_owner: c.TSNode,
    range_node: c.TSNode,
    kind: provider.SymbolKind,
    caveats: []const []const u8,
) !void {
    const child = c.ts_node_named_child(name_owner, 0);
    if (!c.ts_node_is_null(child)) {
        try appendSymbol(allocator, symbols, path, source, child, range_node, kind, caveats);
    }
}

fn appendSymbol(
    allocator: std.mem.Allocator,
    symbols: *std.ArrayList(provider.CurrentSymbolEvidence),
    path: []const u8,
    source: []const u8,
    name_node: c.TSNode,
    range_node: c.TSNode,
    kind: provider.SymbolKind,
    caveats: []const []const u8,
) !void {
    const symbol_name = nodeSourceSlice(source, name_node) orelse return;
    try symbols.append(allocator, .{
        .path = path,
        .name = symbol_name,
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
    return .{
        .start = start.row + 1,
        .end = end.row + 1,
    };
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

test "extracts supported Go symbols in source order with provider evidence" {
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
        \\type Service struct {
        \\    Field int
        \\}
        \\
        \\type Runner interface {
        \\    Run()
        \\}
        \\
        \\func (s Service) Method() {}
        \\
    ;

    var result = try extractGoCurrentSymbols(std.testing.allocator, "internal/proof.go", source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 8), result.symbols.len);
    try std.testing.expectEqualStrings("proof", result.symbols[0].name);
    try std.testing.expectEqualStrings("Alpha", result.symbols[1].name);
    try std.testing.expectEqualStrings("Beta", result.symbols[2].name);
    try std.testing.expectEqualStrings("Gamma", result.symbols[3].name);
    try std.testing.expectEqualStrings("Zebra", result.symbols[4].name);
    try std.testing.expectEqualStrings("Service", result.symbols[5].name);
    try std.testing.expectEqualStrings("Runner", result.symbols[6].name);
    try std.testing.expectEqualStrings("Method", result.symbols[7].name);
    try std.testing.expectEqual(provider.SymbolKind.module, result.symbols[0].kind);
    try std.testing.expectEqual(provider.SymbolKind.other, result.symbols[1].kind);
    try std.testing.expectEqual(provider.SymbolKind.variable, result.symbols[3].kind);
    try std.testing.expectEqual(provider.SymbolKind.function, result.symbols[4].kind);
    try std.testing.expectEqual(provider.SymbolKind.type, result.symbols[5].kind);
    try std.testing.expectEqual(provider.SymbolKind.method, result.symbols[7].kind);
    try std.testing.expectEqualStrings("internal/proof.go", result.symbols[0].path);
    try std.testing.expectEqualStrings(provider_name, result.symbols[0].provider_name);
    try std.testing.expectEqual(provider.Confidence.high, result.symbols[0].confidence);
    try std.testing.expectEqualStrings(provider.CurrentSymbolEvidence.semantics, result.symbols[0].caveats[6]);
    try std.testing.expectEqualStrings("const names map to provider SymbolKind.other because no constant-specific kind exists", result.symbols[1].caveats[7]);
    try std.testing.expectEqualStrings("struct type specs map to provider SymbolKind.type because no struct-specific kind exists", result.symbols[5].caveats[7]);
    try expectLineRange(result.symbols[0], 1, 1);
    try expectLineRange(result.symbols[1], 3, 6);
    try expectLineRange(result.symbols[2], 3, 6);
    try expectLineRange(result.symbols[3], 8, 8);
    try expectLineRange(result.symbols[4], 10, 10);
    try expectLineRange(result.symbols[5], 12, 14);
    try expectLineRange(result.symbols[6], 16, 18);
    try expectLineRange(result.symbols[7], 20, 20);
}

test "extracts bare Go methods with caveated method naming" {
    const source =
        \\package proof
        \\
        \\type Service struct{}
        \\func (s Service) Serve() {}
        \\
    ;

    var result = try extractGoCurrentSymbols(std.testing.allocator, "method.go", source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 3), result.symbols.len);
    try std.testing.expectEqualStrings("Serve", result.symbols[2].name);
    try std.testing.expectEqual(provider.SymbolKind.method, result.symbols[2].kind);
    try std.testing.expectEqualStrings("method names are bare identifiers; receiver-qualified naming is out of scope for this proof", result.symbols[2].caveats[7]);
    try expectLineRange(result.symbols[2], 4, 4);
}

test "empty Go source returns no symbols without failure" {
    var result = try extractGoCurrentSymbols(std.testing.allocator, "empty.go", "");
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try std.testing.expectEqualStrings("direct AST traversal only; no Tree-sitter query files or custom query execution", result.caveats[2]);
}

test "invalid Go source fails safely without diagnostics or snippets" {
    var result = try extractGoCurrentSymbols(std.testing.allocator, "broken.go", "package proof\nfunc {");
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.failed, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try std.testing.expectEqualStrings("no parser diagnostics or source snippets exposed", result.caveats[1]);
}

test "unsupported non-Go paths do not parse" {
    var result = try extractGoCurrentSymbols(std.testing.allocator, "README.md", "package hidden\nfunc Hidden() {}\n");
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.unsupported, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try std.testing.expectEqualStrings("unsupported path: only repo-relative .go files are parsed", result.caveats[0]);
}

test "unsafe paths are rejected before parsing" {
    try std.testing.expectError(error.InvalidRepoRelativePath, extractGoCurrentSymbols(std.testing.allocator, "../private/source.go", "package hidden\n"));
}

test "generated markers, build tags, and cgo adjacency are caveated only" {
    const source =
        \\// Code generated by local proof; DO NOT EDIT.
        \\//go:build linux
        \\package proof
        \\
        \\import "C"
        \\
        \\func Visible() {}
        \\
    ;

    var result = try extractGoCurrentSymbols(std.testing.allocator, "caveated.go", source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 2), result.symbols.len);
    try std.testing.expectEqualStrings("proof", result.symbols[0].name);
    try std.testing.expectEqualStrings("Visible", result.symbols[1].name);
    try std.testing.expectEqualStrings("build tags, generated-file markers, and cgo-adjacent imports are not evaluated by this proof", result.symbols[1].caveats[5]);
}
