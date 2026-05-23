const std = @import("std");
const provider = @import("provider.zig");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_zig() *const c.TSLanguage;

pub const provider_name = "tree-sitter-zig";
pub const provider_version = "tree-sitter-core@v0.26.9/tree-sitter-zig@v1.1.2";
const max_file_bytes: u64 = 1024 * 1024;

const ok_caveats = [_][]const u8{
    "current working-tree enrichment only; file-level Git evidence remains product truth",
    "supported subset: named Zig function declarations only",
    "range convention: one-based inclusive lines",
};
const unsupported_caveats = [_][]const u8{
    "provider unsupported: only repo-relative .zig files are parsed",
    "no parser diagnostics or source snippets exposed",
};
const unavailable_caveats = [_][]const u8{
    "current working-tree file unavailable or not a regular bounded file",
    "no parser diagnostics, source snippets, absolute paths, remotes, author identities, commit messages, or private repo names exposed",
};
const failed_caveats = [_][]const u8{
    "provider failed to parse supported Zig symbol evidence",
    "no parser diagnostics or source snippets exposed",
};
const partial_caveats = [_][]const u8{
    "partial parse: supported function declarations are low-confidence current evidence",
    "no parser diagnostics or source snippets exposed",
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
    if (!std.mem.endsWith(u8, repo_relative_path, ".zig")) {
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
    if (!std.mem.endsWith(u8, repo_relative_path, ".zig")) {
        return extraction(allocator, repo_relative_path, .unsupported, .unknown, .unknown, &unsupported_caveats, &.{});
    }

    const parser = c.ts_parser_new() orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .unknown, &failed_caveats, &.{});
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_zig())) return extraction(allocator, repo_relative_path, .failed, .unknown, .unknown, &failed_caveats, &.{});

    const source_len = std.math.cast(u32, source.len) orelse return extraction(allocator, repo_relative_path, .unavailable, .unknown, .unknown, &unavailable_caveats, &.{});
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return extraction(allocator, repo_relative_path, .failed, .unknown, .unknown, &failed_caveats, &.{});
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    var symbols: std.ArrayList(provider.CurrentSymbolEvidence) = .empty;
    errdefer {
        for (symbols.items) |symbol| {
            allocator.free(symbol.path);
            allocator.free(symbol.name);
        }
        symbols.deinit(allocator);
    }

    const has_error = c.ts_node_has_error(root);
    try collectFunctionDeclarations(allocator, &symbols, repo_relative_path, source, root, has_error);
    std.mem.sort(provider.CurrentSymbolEvidence, symbols.items, {}, provider.lessSymbol);

    if (has_error and symbols.items.len == 0) {
        return extraction(allocator, repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
    }

    const confidence: provider.Confidence = if (has_error) .low else .high;
    const caveats = if (has_error) &partial_caveats else &ok_caveats;
    return extraction(allocator, repo_relative_path, .ok, .fresh, confidence, caveats, try symbols.toOwnedSlice(allocator));
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

fn collectFunctionDeclarations(
    allocator: std.mem.Allocator,
    symbols: *std.ArrayList(provider.CurrentSymbolEvidence),
    path: []const u8,
    source: []const u8,
    node: c.TSNode,
    low_confidence: bool,
) !void {
    if (c.ts_node_is_null(node)) return;

    const node_type = std.mem.span(c.ts_node_type(node));
    if (std.mem.eql(u8, node_type, "function_declaration")) {
        const name_node = c.ts_node_child_by_field_name(node, "name".ptr, "name".len);
        if (!c.ts_node_is_null(name_node)) {
            if (nodeSourceSlice(source, name_node)) |symbol_name| {
                try symbols.append(allocator, .{
                    .path = try allocator.dupe(u8, path),
                    .name = try allocator.dupe(u8, symbol_name),
                    .kind = .function,
                    .current_range = .{ .lines = nodeLineRange(node) },
                    .provider_name = provider_name,
                    .confidence = if (low_confidence or c.ts_node_has_error(node)) .low else .high,
                    .caveats = if (low_confidence) &partial_caveats else &ok_caveats,
                });
            }
        }
    }

    const child_count = c.ts_node_named_child_count(node);
    var index: u32 = 0;
    while (index < child_count) : (index += 1) {
        try collectFunctionDeclarations(allocator, symbols, path, source, c.ts_node_named_child(node, index), low_confidence);
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
    return .{ .start = start.row + 1, .end = end.row + 1 };
}

test "extract source handles supported, empty, unsupported, and invalid inputs" {
    var ok = try extractSource(std.testing.allocator, "src/example.zig", "pub fn zebra() void {}\nfn alpha() void {}\n");
    defer ok.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, ok.provider.failure);
    try std.testing.expectEqual(@as(usize, 2), ok.symbols.len);
    try std.testing.expectEqualStrings("alpha", ok.symbols[0].name);
    try std.testing.expectEqualStrings("zebra", ok.symbols[1].name);
    switch (ok.symbols[0].current_range) {
        .lines => |range| try std.testing.expectEqual(@as(u32, 2), range.start),
        .bytes => return error.ExpectedLineRange,
    }

    var empty = try extractSource(std.testing.allocator, "empty.zig", "");
    defer empty.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, empty.provider.failure);
    try std.testing.expectEqual(@as(usize, 0), empty.symbols.len);

    var unsupported = try extractSource(std.testing.allocator, "README.md", "pub fn hidden() void {}");
    defer unsupported.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unsupported, unsupported.provider.failure);

    var broken = try extractSource(std.testing.allocator, "broken.zig", "pub fn {");
    defer broken.deinit(std.testing.allocator);
    try std.testing.expect(broken.provider.failure == .failed or broken.provider.confidence == .low);
}
