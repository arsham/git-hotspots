const std = @import("std");
const provider = @import("provider.zig");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_go() *const c.TSLanguage;

pub const provider_name = "tree-sitter-go";
pub const provider_version = "tree-sitter-core@v0.26.9/tree-sitter-go@v0.25.0";
const max_file_bytes: u64 = 1024 * 1024;

const ok_caveats = [_][]const u8{
    "current working-tree enrichment only; file-level Git evidence remains product truth",
    "supported subset: package clauses, top-level functions, methods, struct/interface type specs, and top-level const/var names",
    "range convention: one-based inclusive lines from the enclosing Go declaration",
    "build tags, generated-file markers, package loading, and cgo are not evaluated",
    "method names are bare identifiers; receiver-qualified naming is out of scope",
};
const unsupported_caveats = [_][]const u8{
    "provider unsupported: only repo-relative .go files are parsed",
    "no parser diagnostics or source snippets exposed",
};
const unavailable_caveats = [_][]const u8{
    "current working-tree file unavailable or not a regular bounded file",
    "no parser diagnostics, source snippets, absolute paths, remotes, author identities, commit messages, or private repo names exposed",
};
const failed_caveats = [_][]const u8{
    "provider failed to parse supported Go symbol evidence",
    "no parser diagnostics or source snippets exposed",
};
const const_caveats = ok_caveats ++ [_][]const u8{
    "const names map to provider SymbolKind.other because no constant-specific kind exists",
};
const type_caveats = ok_caveats ++ [_][]const u8{
    "struct and interface type specs map to provider SymbolKind.type",
};

pub const Extraction = struct {
    provider: provider.ProviderEvidence,
    symbols: []provider.CurrentSymbolEvidence,

    pub fn deinit(self: *Extraction, allocator: std.mem.Allocator) void {
        allocator.free(self.provider.input.identity);
        for (self.symbols) |symbol| {
            allocator.free(symbol.path);
            allocator.free(symbol.name);
            if (symbol.current_line_history) |line_history| {
                for (line_history.sample_commits) |commit| allocator.free(commit);
                allocator.free(line_history.sample_commits);
                for (line_history.caveats) |caveat| allocator.free(caveat);
                allocator.free(line_history.caveats);
            }
        }
        allocator.free(self.symbols);
        self.* = undefined;
    }
};

pub fn extractPath(allocator: std.mem.Allocator, io: std.Io, repo_root: []const u8, repo_relative_path: []const u8) !Extraction {
    try provider.validateRepoRelativePath(repo_relative_path);
    if (!std.mem.endsWith(u8, repo_relative_path, ".go")) {
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
    if (!std.mem.endsWith(u8, repo_relative_path, ".go")) {
        return extraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &unsupported_caveats, &.{});
    }

    const parser = c.ts_parser_new() orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_go())) return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});

    const source_len = std.math.cast(u32, source.len) orelse return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});

    var symbols: std.ArrayList(provider.CurrentSymbolEvidence) = .empty;
    errdefer {
        for (symbols.items) |symbol| {
            allocator.free(symbol.path);
            allocator.free(symbol.name);
        }
        symbols.deinit(allocator);
    }

    try collectTopLevelDeclarations(allocator, &symbols, repo_relative_path, source, root);
    std.mem.sort(provider.CurrentSymbolEvidence, symbols.items, {}, provider.lessSymbol);
    return extraction(allocator, repo_relative_path, .ok, .fresh, .high, &ok_caveats, try symbols.toOwnedSlice(allocator));
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

fn collectTopLevelDeclarations(
    allocator: std.mem.Allocator,
    symbols: *std.ArrayList(provider.CurrentSymbolEvidence),
    path: []const u8,
    source: []const u8,
    root: c.TSNode,
) !void {
    if (c.ts_node_is_null(root) or !nodeTypeIs(root, "source_file")) return;

    const child_count = c.ts_node_named_child_count(root);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(root, index);
        if (nodeTypeIs(child, "package_clause")) {
            try appendSymbolFromFirstNamedChild(allocator, symbols, path, source, child, child, .module, &ok_caveats);
        } else if (nodeTypeIs(child, "function_declaration")) {
            try appendSymbolFromField(allocator, symbols, path, source, child, child, "name", .function, &ok_caveats);
        } else if (nodeTypeIs(child, "method_declaration")) {
            try appendSymbolFromField(allocator, symbols, path, source, child, child, "name", .method, &ok_caveats);
        } else if (nodeTypeIs(child, "type_declaration")) {
            try collectTypeSpecs(allocator, symbols, path, source, child);
        } else if (nodeTypeIs(child, "const_declaration")) {
            try collectConstOrVarSpecs(allocator, symbols, path, source, child, "const_spec", .other, &const_caveats);
        } else if (nodeTypeIs(child, "var_declaration")) {
            try collectConstOrVarSpecs(allocator, symbols, path, source, child, "var_spec", .variable, &ok_caveats);
        }
    }
}

fn collectTypeSpecs(allocator: std.mem.Allocator, symbols: *std.ArrayList(provider.CurrentSymbolEvidence), path: []const u8, source: []const u8, declaration: c.TSNode) !void {
    const child_count = c.ts_node_named_child_count(declaration);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(declaration, index);
        if (!nodeTypeIs(child, "type_spec")) continue;
        const type_node = childByField(child, "type");
        if (nodeTypeIs(type_node, "struct_type") or nodeTypeIs(type_node, "interface_type")) {
            try appendSymbolFromField(allocator, symbols, path, source, child, declaration, "name", .type, &type_caveats);
        }
    }
}

fn collectConstOrVarSpecs(allocator: std.mem.Allocator, symbols: *std.ArrayList(provider.CurrentSymbolEvidence), path: []const u8, source: []const u8, declaration: c.TSNode, spec_type: []const u8, kind: provider.SymbolKind, caveats: []const []const u8) !void {
    const child_count = c.ts_node_named_child_count(declaration);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(declaration, index);
        if (nodeTypeIs(child, spec_type)) {
            try collectLeadingIdentifierNames(allocator, symbols, path, source, child, declaration, kind, caveats);
        } else if (nodeTypeIs(child, "var_spec_list") or nodeTypeIs(child, "const_spec_list")) {
            try collectConstOrVarSpecs(allocator, symbols, path, source, child, spec_type, kind, caveats);
        }
    }
}

fn collectLeadingIdentifierNames(allocator: std.mem.Allocator, symbols: *std.ArrayList(provider.CurrentSymbolEvidence), path: []const u8, source: []const u8, spec: c.TSNode, declaration: c.TSNode, kind: provider.SymbolKind, caveats: []const []const u8) !void {
    const child_count = c.ts_node_named_child_count(spec);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        const child = c.ts_node_named_child(spec, index);
        if (!nodeTypeIs(child, "identifier")) break;
        try appendSymbol(allocator, symbols, path, source, child, declaration, kind, caveats);
    }
}

fn appendSymbolFromField(allocator: std.mem.Allocator, symbols: *std.ArrayList(provider.CurrentSymbolEvidence), path: []const u8, source: []const u8, name_owner: c.TSNode, range_node: c.TSNode, field_name: []const u8, kind: provider.SymbolKind, caveats: []const []const u8) !void {
    const name_node = childByField(name_owner, field_name);
    if (!c.ts_node_is_null(name_node)) try appendSymbol(allocator, symbols, path, source, name_node, range_node, kind, caveats);
}

fn appendSymbolFromFirstNamedChild(allocator: std.mem.Allocator, symbols: *std.ArrayList(provider.CurrentSymbolEvidence), path: []const u8, source: []const u8, name_owner: c.TSNode, range_node: c.TSNode, kind: provider.SymbolKind, caveats: []const []const u8) !void {
    const child = c.ts_node_named_child(name_owner, 0);
    if (!c.ts_node_is_null(child)) try appendSymbol(allocator, symbols, path, source, child, range_node, kind, caveats);
}

fn appendSymbol(allocator: std.mem.Allocator, symbols: *std.ArrayList(provider.CurrentSymbolEvidence), path: []const u8, source: []const u8, name_node: c.TSNode, range_node: c.TSNode, kind: provider.SymbolKind, caveats: []const []const u8) !void {
    const symbol_name = nodeSourceSlice(source, name_node) orelse return;
    try symbols.append(allocator, .{
        .path = try allocator.dupe(u8, path),
        .name = try allocator.dupe(u8, symbol_name),
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
    return .{ .start = start.row + 1, .end = end.row + 1 };
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

test "extract source handles supported Go subset" {
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
        \\type Service struct{}
        \\type Runner interface{ Run() }
        \\
        \\func (s Service) Method() {}
        \\
    ;

    var result = try extractSource(std.testing.allocator, "internal/proof.go", source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.provider.failure);
    try std.testing.expectEqual(@as(usize, 8), result.symbols.len);
    try std.testing.expectEqualStrings("Alpha", result.symbols[0].name);
    try std.testing.expectEqualStrings("Beta", result.symbols[1].name);
    try std.testing.expectEqualStrings("Gamma", result.symbols[2].name);
    try std.testing.expectEqualStrings("Method", result.symbols[3].name);
    try std.testing.expectEqualStrings("Runner", result.symbols[4].name);
    try std.testing.expectEqualStrings("Service", result.symbols[5].name);
    try std.testing.expectEqualStrings("Zebra", result.symbols[6].name);
    try std.testing.expectEqualStrings("proof", result.symbols[7].name);
    try std.testing.expectEqual(provider.SymbolKind.other, result.symbols[0].kind);
    try std.testing.expectEqual(provider.SymbolKind.variable, result.symbols[2].kind);
    try std.testing.expectEqual(provider.SymbolKind.method, result.symbols[3].kind);
    try std.testing.expectEqual(provider.SymbolKind.type, result.symbols[4].kind);
    try std.testing.expectEqual(provider.SymbolKind.function, result.symbols[6].kind);
    try std.testing.expectEqual(provider.SymbolKind.module, result.symbols[7].kind);
    try std.testing.expectEqualStrings(provider_name, result.symbols[0].provider_name);
    try expectLineRange(result.symbols[6], 10, 10);
}

test "extract source handles empty unsupported invalid and caveated inputs" {
    var empty = try extractSource(std.testing.allocator, "empty.go", "");
    defer empty.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, empty.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), empty.symbols.len);

    var unsupported = try extractSource(std.testing.allocator, "README.md", "package hidden\nfunc Hidden() {}\n");
    defer unsupported.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unsupported, unsupported.provider.failure);

    var broken = try extractSource(std.testing.allocator, "broken.go", "package proof\nfunc {");
    defer broken.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.failed, broken.provider.failure);

    const caveated_source =
        \\// Code generated by local proof; DO NOT EDIT.
        \\//go:build linux
        \\package proof
        \\
        \\import "C"
        \\
        \\func Visible() {}
        \\
    ;
    var caveated = try extractSource(std.testing.allocator, "caveated.go", caveated_source);
    defer caveated.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, caveated.provider.failure);
    try std.testing.expectEqualStrings("build tags, generated-file markers, package loading, and cgo are not evaluated", caveated.provider.caveats[3]);
}
