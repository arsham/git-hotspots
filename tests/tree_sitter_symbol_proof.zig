const std = @import("std");
const provider = @import("provider");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_zig() *const c.TSLanguage;

const provider_name = "tree-sitter-zig-proof";
const supported_caveats = [_][]const u8{
    "test-only in-memory Tree-sitter proof",
    "supported subset: named Zig function_declaration descendants only",
    "range convention: one-based inclusive line range from Tree-sitter node points",
    provider.CurrentSymbolEvidence.semantics,
};
const unsupported_caveats = [_][]const u8{
    "unsupported path: only repo-relative .zig files are parsed",
    "no parser diagnostics or source snippets exposed",
};
const failed_caveats = [_][]const u8{
    "parse failed or contained no supported named function declarations",
    "no parser diagnostics or source snippets exposed",
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

/// Test-only extractor proof for the current supported subset:
/// - input is in-memory Zig source plus a repo-relative path;
/// - only named `function_declaration` descendants are emitted;
/// - ranges are one-based, inclusive line ranges from Tree-sitter node points;
/// - unsupported paths and parser failures expose only provider failure/caveats,
///   never raw parser diagnostics, source snippets, or absolute paths.
fn extractZigCurrentSymbols(
    allocator: std.mem.Allocator,
    repo_relative_path: []const u8,
    source: []const u8,
) !SymbolExtractionResult {
    try provider.validateRepoRelativePath(repo_relative_path);

    if (!std.mem.endsWith(u8, repo_relative_path, ".zig")) {
        return .{
            .failure = .unsupported,
            .symbols = &.{},
            .caveats = &unsupported_caveats,
        };
    }

    const parser = c.ts_parser_new() orelse return failedResult();
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_zig())) return failedResult();

    const source_len = std.math.cast(u32, source.len) orelse return failedResult();
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return failedResult();
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    var symbols: std.ArrayList(provider.CurrentSymbolEvidence) = .empty;
    errdefer symbols.deinit(allocator);

    try collectFunctionDeclarations(allocator, &symbols, repo_relative_path, source, root);
    std.mem.sort(provider.CurrentSymbolEvidence, symbols.items, {}, provider.lessSymbol);

    if (symbols.items.len == 0 and c.ts_node_has_error(root)) {
        return .{
            .failure = .failed,
            .symbols = &.{},
            .caveats = &failed_caveats,
        };
    }

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

fn collectFunctionDeclarations(
    allocator: std.mem.Allocator,
    symbols: *std.ArrayList(provider.CurrentSymbolEvidence),
    path: []const u8,
    source: []const u8,
    node: c.TSNode,
) !void {
    if (c.ts_node_is_null(node)) return;

    const node_type = std.mem.span(c.ts_node_type(node));
    if (std.mem.eql(u8, node_type, "function_declaration")) {
        const name_node = c.ts_node_child_by_field_name(node, "name".ptr, "name".len);
        if (!c.ts_node_is_null(name_node)) {
            const name = nodeSourceSlice(source, name_node) orelse null;
            if (name) |symbol_name| {
                try symbols.append(allocator, .{
                    .path = path,
                    .name = symbol_name,
                    .kind = .function,
                    .current_range = .{ .lines = nodeLineRange(node) },
                    .provider_name = provider_name,
                    .confidence = if (c.ts_node_has_error(node)) .low else .high,
                    .caveats = &supported_caveats,
                });
            }
        }
    }

    const child_count = c.ts_node_named_child_count(node);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        try collectFunctionDeclarations(allocator, symbols, path, source, c.ts_node_named_child(node, index));
    }
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

test "extracts named Zig functions with deterministic provider evidence" {
    const source =
        \\pub fn zebra() void {}
        \\fn alpha() void {}
        \\const not_a_function = 1;
        \\
    ;

    var result = try extractZigCurrentSymbols(std.testing.allocator, "src/example.zig", source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 2), result.symbols.len);
    try std.testing.expectEqualStrings("alpha", result.symbols[0].name);
    try std.testing.expectEqualStrings("zebra", result.symbols[1].name);
    try std.testing.expectEqualStrings("src/example.zig", result.symbols[0].path);
    try std.testing.expectEqual(provider.SymbolKind.function, result.symbols[0].kind);
    try std.testing.expectEqualStrings(provider_name, result.symbols[0].provider_name);
    try std.testing.expectEqual(provider.Confidence.high, result.symbols[0].confidence);
    try expectLineRange(result.symbols[0], 2, 2);
    try expectLineRange(result.symbols[1], 1, 1);
    try std.testing.expectEqualStrings(provider.CurrentSymbolEvidence.semantics, result.symbols[0].caveats[3]);
}

test "handles multiline ranges and Markdown-sensitive or unicode names deterministically" {
    const source =
        \\pub fn @"markdown[link]*"() void {
        \\    return;
        \\}
        \\fn @"unicode☃"() void {}
        \\
    ;

    var result = try extractZigCurrentSymbols(std.testing.allocator, "unicode/[safe].zig", source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 2), result.symbols.len);
    try std.testing.expectEqualStrings("@\"markdown[link]*\"", result.symbols[0].name);
    try std.testing.expectEqualStrings("@\"unicode☃\"", result.symbols[1].name);
    try expectLineRange(result.symbols[0], 1, 3);
    try expectLineRange(result.symbols[1], 4, 4);
}

test "empty Zig source returns no symbols without failure" {
    var result = try extractZigCurrentSymbols(std.testing.allocator, "empty.zig", "");
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try std.testing.expectEqualStrings("supported subset: named Zig function_declaration descendants only", result.caveats[1]);
}

test "partial or invalid Zig source fails safely without diagnostics or snippets" {
    var result = try extractZigCurrentSymbols(std.testing.allocator, "broken.zig", "pub fn {");
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.failed, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try std.testing.expectEqualStrings("no parser diagnostics or source snippets exposed", result.caveats[1]);
}

test "unsupported non-Zig paths do not parse" {
    var result = try extractZigCurrentSymbols(std.testing.allocator, "README.md", "pub fn hidden() void {}");
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.unsupported, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try std.testing.expectEqualStrings("unsupported path: only repo-relative .zig files are parsed", result.caveats[0]);
}

test "unsafe paths are rejected before parsing" {
    try std.testing.expectError(error.InvalidRepoRelativePath, extractZigCurrentSymbols(std.testing.allocator, "/private/source.zig", "pub fn hidden() void {}"));
}
