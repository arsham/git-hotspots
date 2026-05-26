const std = @import("std");
const provider = @import("provider");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_rust() *const c.TSLanguage;

const query_source = @embedFile("fixtures/tree_sitter_rust_query/rust-symbols.scm");
const supported_source = @embedFile("fixtures/tree_sitter_rust_query/supported_subset.rs");
const generated_source = @embedFile("fixtures/tree_sitter_rust_query/generated.rs");
const macro_cfg_source = @embedFile("fixtures/tree_sitter_rust_query/macro_cfg.rs");
const invalid_partial_source = @embedFile("fixtures/tree_sitter_rust_query/invalid_partial.rs");
const empty_source = @embedFile("fixtures/tree_sitter_rust_query/empty.rs");
const unsupported_source = @embedFile("fixtures/tree_sitter_rust_query/unsupported.md");

const provider_name = "tree-sitter-rust-query-proof";
const query_version = "rust-symbol-query-v1";
const provider_version = "tree-sitter-core@v0.26.9/tree-sitter-rust@v0.24.2/rust-symbol-query-v1";
const query_fingerprint = "tests/fixtures/tree_sitter_rust_query/rust-symbols.scm:rust-symbol-query-v1";
const expected_capture_names = [_][]const u8{
    "rust.file",
    "rust.definition.name",
    "rust.function.definition",
    "rust.trait.method.definition",
    "rust.trait.definition",
    "rust.impl.block",
    "rust.module.definition",
    "rust.struct.definition",
    "rust.enum.definition",
    "rust.enum.variant.definition",
    "rust.const.definition",
    "rust.static.definition",
    "rust.macro.definition",
    "rust.macro.name",
    "rust.macro.invocation",
    "rust.attribute",
    "rust.comment",
};

const base_caveats = [_][]const u8{
    "test-only in-memory Tree-sitter Rust query proof",
    "Rust grammar v0.24.2; query version: " ++ query_version,
    "project-owned query asset: tests/fixtures/tree_sitter_rust_query/rust-symbols.scm",
    "range convention: one-based inclusive line range from the symbol node",
    "ordering convention: deterministic source order by symbol node start byte; the file symbol is first",
    "file symbols use repo-relative .rs paths; mod item symbols use bare syntactic identifiers",
    "runtime Rust --symbols output is not implemented by this proof",
    "no Cargo, crate graph, module resolution, macro expansion, type checking, cfg evaluation, LSP, parser generation, or network analysis is performed",
    provider.CurrentSymbolEvidence.semantics,
};
const unsupported_caveats = [_][]const u8{
    "unsupported path: only repo-relative .rs files are Rust query candidates",
    "no Rust parser was run for the unsupported path",
};
const failed_caveats = [_][]const u8{
    "parse failed before safe Rust query symbol proof completed",
    "no parser diagnostics or source snippets exposed",
};
const function_caveats = base_caveats ++ [_][]const u8{
    "freestanding functions are emitted only from source-file or inline-module item scopes; block-local items are skipped",
};
const method_caveats = base_caveats ++ [_][]const u8{
    "method classification is derived from direct impl or trait declaration-list syntax; trait and type resolution are out of scope",
};
const type_caveats = base_caveats ++ [_][]const u8{
    "structs, tuple structs, unit structs, enums, and traits map to provider SymbolKind.type; no public schema expansion is made",
};
const const_static_caveats = base_caveats ++ [_][]const u8{
    "const and static items map to provider SymbolKind.other because no constant- or static-specific kind exists",
};
const enum_variant_caveats = base_caveats ++ [_][]const u8{
    "enum variants map to provider SymbolKind.other; tuple and field payloads are not interpreted semantically",
};
const external_mod_caveats = base_caveats ++ [_][]const u8{
    "external mod declarations are emitted by syntactic name only; no file-system or crate module resolution is performed",
};
const generated_caveats = base_caveats ++ [_][]const u8{
    "generated-file markers are caveated only; generated-source policy is not evaluated by this proof",
};
const macro_caveats = base_caveats ++ [_][]const u8{
    "macro definitions and invocations are counted only; macro expansion output is not inferred as symbols",
};
const cfg_caveats = base_caveats ++ [_][]const u8{
    "conditional compilation attributes are caveated only; no cfg or feature evaluation is performed",
};
const macro_cfg_caveats = base_caveats ++ [_][]const u8{
    "macro definitions and invocations are counted only; macro expansion output is not inferred as symbols",
    "conditional compilation attributes are caveated only; no cfg or feature evaluation is performed",
};

const DefinitionKind = enum {
    function,
    trait_method_signature,
    trait_definition,
    module,
    struct_definition,
    enum_definition,
    enum_variant,
    const_item,
    static_item,
};

const CaveatKind = enum {
    module,
    function,
    method,
    type_like,
    const_static,
    enum_variant,
    external_module,
};

const ItemContext = enum {
    source_file,
    module,
    impl_block,
    trait_block,
    enum_body,
    unsupported,
};

const SourceProfile = struct {
    generated: bool,
    macro_syntax: bool,
    cfg_attributes: bool,
};

const SymbolCandidate = struct {
    start_byte: u32,
    end_byte: u32,
    symbol: provider.CurrentSymbolEvidence,
};

const SymbolExtractionResult = struct {
    provider: provider.ProviderEvidence,
    failure: provider.Failure,
    symbols: []provider.CurrentSymbolEvidence,
    caveats: []const []const u8,
    comment_capture_count: usize = 0,
    attribute_capture_count: usize = 0,
    impl_block_capture_count: usize = 0,
    macro_definition_capture_count: usize = 0,
    macro_invocation_capture_count: usize = 0,

    fn deinit(self: *SymbolExtractionResult, allocator: std.mem.Allocator) void {
        if (self.symbols.len > 0) allocator.free(self.symbols);
        self.* = undefined;
    }
};

fn extractRustQuerySymbols(
    allocator: std.mem.Allocator,
    repo_relative_path: []const u8,
    source: []const u8,
) !SymbolExtractionResult {
    try provider.validateRepoRelativePath(repo_relative_path);

    if (!std.mem.endsWith(u8, repo_relative_path, ".rs")) {
        return extractionResult(repo_relative_path, .unsupported, .unknown, .unknown, &unsupported_caveats, &.{});
    }

    const parser = c.ts_parser_new() orelse return failedResult(repo_relative_path);
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_rust())) return failedResult(repo_relative_path);

    const source_len = std.math.cast(u32, source.len) orelse return failedResult(repo_relative_path);
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return failedResult(repo_relative_path);
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return failedResult(repo_relative_path);

    const query = try compileRustQuery();
    defer c.ts_query_delete(query);

    const cursor = c.ts_query_cursor_new() orelse return failedResult(repo_relative_path);
    defer c.ts_query_cursor_delete(cursor);

    var candidates: std.ArrayList(SymbolCandidate) = .empty;
    defer candidates.deinit(allocator);

    const profile = sourceProfile(source);
    var comment_capture_count: usize = 0;
    var attribute_capture_count: usize = 0;
    var impl_block_capture_count: usize = 0;
    var macro_definition_capture_count: usize = 0;
    var macro_invocation_capture_count: usize = 0;

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
            if (std.mem.eql(u8, name, "rust.file")) {
                try appendCandidate(
                    allocator,
                    &candidates,
                    repo_relative_path,
                    repo_relative_path,
                    .module,
                    capture.node,
                    capture.node,
                    caveatsForDefinition(.module, profile),
                );
            } else if (std.mem.eql(u8, name, "rust.function.definition")) {
                definition_node = capture.node;
                definition_kind = .function;
            } else if (std.mem.eql(u8, name, "rust.trait.method.definition")) {
                definition_node = capture.node;
                definition_kind = .trait_method_signature;
            } else if (std.mem.eql(u8, name, "rust.trait.definition")) {
                definition_node = capture.node;
                definition_kind = .trait_definition;
            } else if (std.mem.eql(u8, name, "rust.module.definition")) {
                definition_node = capture.node;
                definition_kind = .module;
            } else if (std.mem.eql(u8, name, "rust.struct.definition")) {
                definition_node = capture.node;
                definition_kind = .struct_definition;
            } else if (std.mem.eql(u8, name, "rust.enum.definition")) {
                definition_node = capture.node;
                definition_kind = .enum_definition;
            } else if (std.mem.eql(u8, name, "rust.enum.variant.definition")) {
                definition_node = capture.node;
                definition_kind = .enum_variant;
            } else if (std.mem.eql(u8, name, "rust.const.definition")) {
                definition_node = capture.node;
                definition_kind = .const_item;
            } else if (std.mem.eql(u8, name, "rust.static.definition")) {
                definition_node = capture.node;
                definition_kind = .static_item;
            } else if (std.mem.eql(u8, name, "rust.definition.name")) {
                name_node = capture.node;
                has_name = true;
            } else if (std.mem.eql(u8, name, "rust.impl.block")) {
                impl_block_capture_count += 1;
            } else if (std.mem.eql(u8, name, "rust.macro.definition")) {
                macro_definition_capture_count += 1;
            } else if (std.mem.eql(u8, name, "rust.macro.invocation")) {
                macro_invocation_capture_count += 1;
            } else if (std.mem.eql(u8, name, "rust.attribute")) {
                attribute_capture_count += 1;
            } else if (std.mem.eql(u8, name, "rust.comment")) {
                comment_capture_count += 1;
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

    var extracted = extractionResult(repo_relative_path, .ok, .fresh, .high, caveatsForDefinition(.module, profile), try symbols.toOwnedSlice(allocator));
    extracted.comment_capture_count = comment_capture_count;
    extracted.attribute_capture_count = attribute_capture_count;
    extracted.impl_block_capture_count = impl_block_capture_count;
    extracted.macro_definition_capture_count = macro_definition_capture_count;
    extracted.macro_invocation_capture_count = macro_invocation_capture_count;
    return extracted;
}

fn compileRustQuery() !*c.TSQuery {
    var error_offset: u32 = 0;
    var error_type: c.TSQueryError = c.TSQueryErrorNone;
    return c.ts_query_new(
        tree_sitter_rust(),
        query_source.ptr,
        @intCast(query_source.len),
        &error_offset,
        &error_type,
    ) orelse error.QueryCompileFailed;
}

fn extractionResult(
    repo_relative_path: []const u8,
    failure: provider.Failure,
    freshness: provider.Freshness,
    confidence: provider.Confidence,
    caveats: []const []const u8,
    symbols: []provider.CurrentSymbolEvidence,
) SymbolExtractionResult {
    return .{
        .provider = .{
            .name = provider_name,
            .kind = .symbol,
            .version = provider_version,
            .config_fingerprint = query_fingerprint,
            .input = .{ .identity = repo_relative_path },
            .freshness = freshness,
            .failure = failure,
            .confidence = confidence,
            .caveats = caveats,
            .provenance = .{ .provider_name = provider_name, .input_identity = repo_relative_path },
        },
        .failure = failure,
        .symbols = symbols,
        .caveats = caveats,
    };
}

fn failedResult(repo_relative_path: []const u8) SymbolExtractionResult {
    return extractionResult(repo_relative_path, .failed, .unknown, .low, &failed_caveats, &.{});
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
    const context = itemContext(definition_node);

    switch (kind) {
        .function => switch (context) {
            .source_file, .module => try appendCandidate(allocator, candidates, path, symbol_name, .function, name_node, definition_node, caveatsForDefinition(.function, profile)),
            .impl_block, .trait_block => try appendCandidate(allocator, candidates, path, symbol_name, .method, name_node, definition_node, caveatsForDefinition(.method, profile)),
            else => return,
        },
        .trait_method_signature => switch (context) {
            .trait_block => try appendCandidate(allocator, candidates, path, symbol_name, .method, name_node, definition_node, caveatsForDefinition(.method, profile)),
            else => return,
        },
        .trait_definition, .struct_definition, .enum_definition => switch (context) {
            .source_file, .module => try appendCandidate(allocator, candidates, path, symbol_name, .type, name_node, definition_node, caveatsForDefinition(.type_like, profile)),
            else => return,
        },
        .module => switch (context) {
            .source_file, .module => {
                const module_caveat: CaveatKind = if (hasBody(definition_node)) .module else .external_module;
                try appendCandidate(allocator, candidates, path, symbol_name, .module, name_node, definition_node, caveatsForDefinition(module_caveat, profile));
            },
            else => return,
        },
        .enum_variant => switch (context) {
            .enum_body => try appendCandidate(allocator, candidates, path, symbol_name, .other, name_node, definition_node, caveatsForDefinition(.enum_variant, profile)),
            else => return,
        },
        .const_item, .static_item => switch (context) {
            .source_file, .module, .impl_block, .trait_block => try appendCandidate(allocator, candidates, path, symbol_name, .other, name_node, definition_node, caveatsForDefinition(.const_static, profile)),
            else => return,
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

fn caveatsForDefinition(kind: CaveatKind, profile: SourceProfile) []const []const u8 {
    if (profile.generated) return &generated_caveats;
    if (profile.macro_syntax and profile.cfg_attributes) return &macro_cfg_caveats;
    if (profile.macro_syntax) return &macro_caveats;
    if (profile.cfg_attributes) return &cfg_caveats;
    return switch (kind) {
        .module => &base_caveats,
        .function => &function_caveats,
        .method => &method_caveats,
        .type_like => &type_caveats,
        .const_static => &const_static_caveats,
        .enum_variant => &enum_variant_caveats,
        .external_module => &external_mod_caveats,
    };
}

fn sourceProfile(source: []const u8) SourceProfile {
    return .{
        .generated = hasGeneratedMarker(source),
        .macro_syntax = std.mem.indexOf(u8, source, "macro_rules!") != null or std.mem.indexOf(u8, source, "!(") != null,
        .cfg_attributes = std.mem.indexOf(u8, source, "#[cfg") != null or std.mem.indexOf(u8, source, "#![cfg") != null,
    };
}

fn hasGeneratedMarker(source: []const u8) bool {
    const scan_len = @min(source.len, 2048);
    const prefix = source[0..scan_len];
    return std.mem.indexOf(u8, prefix, "Code generated") != null or std.mem.indexOf(u8, prefix, "DO NOT EDIT") != null;
}

fn itemContext(node: c.TSNode) ItemContext {
    var current = node;
    while (true) {
        const parent = c.ts_node_parent(current);
        if (c.ts_node_is_null(parent)) return .unsupported;
        if (nodeTypeIs(parent, "source_file")) return .source_file;
        if (nodeTypeIs(parent, "enum_variant_list")) {
            const owner = c.ts_node_parent(parent);
            return if (!c.ts_node_is_null(owner) and nodeTypeIs(owner, "enum_item")) .enum_body else .unsupported;
        }
        if (nodeTypeIs(parent, "declaration_list")) {
            const owner = c.ts_node_parent(parent);
            if (c.ts_node_is_null(owner)) return .unsupported;
            if (nodeTypeIs(owner, "mod_item")) return .module;
            if (nodeTypeIs(owner, "impl_item")) return .impl_block;
            if (nodeTypeIs(owner, "trait_item")) return .trait_block;
            return .unsupported;
        }
        if (nodeTypeIs(parent, "block") or nodeTypeIs(parent, "function_item") or nodeTypeIs(parent, "function_signature_item") or nodeTypeIs(parent, "macro_definition") or nodeTypeIs(parent, "macro_invocation")) return .unsupported;
        current = parent;
    }
}

fn hasBody(node: c.TSNode) bool {
    return !c.ts_node_is_null(childByFieldName(node, "body"));
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

test "Rust query contract exposes expected capture names" {
    const query = try compileRustQuery();
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

test "extracts supported Rust query symbols in deterministic source order" {
    var result = try extractRustQuerySymbols(std.testing.allocator, "crates/demo/src/supported_subset.rs", supported_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqualStrings(provider_name, result.provider.name);
    try std.testing.expectEqualStrings(provider_version, result.provider.version);
    try std.testing.expectEqualStrings(query_fingerprint, result.provider.config_fingerprint.?);
    try std.testing.expectEqual(@as(usize, 21), result.symbols.len);
    try std.testing.expectEqual(@as(usize, 1), result.comment_capture_count);
    try std.testing.expectEqual(@as(usize, 1), result.impl_block_capture_count);
    try expectSymbol(result.symbols[0], "crates/demo/src/supported_subset.rs", .module, 1, 46);
    try expectSymbol(result.symbols[1], "LIMIT", .other, 3, 3);
    try expectSymbol(result.symbols[2], "NAME", .other, 4, 4);
    try expectSymbol(result.symbols[3], "nested", .module, 6, 37);
    try expectSymbol(result.symbols[4], "Unit", .type, 7, 7);
    try expectSymbol(result.symbols[5], "Tuple", .type, 8, 8);
    try expectSymbol(result.symbols[6], "Record", .type, 9, 11);
    try expectSymbol(result.symbols[7], "Choice", .type, 13, 17);
    try expectSymbol(result.symbols[8], "First", .other, 14, 14);
    try expectSymbol(result.symbols[9], "Second", .other, 15, 15);
    try expectSymbol(result.symbols[10], "Third", .other, 16, 16);
    try expectSymbol(result.symbols[11], "Render", .type, 19, 24);
    try expectSymbol(result.symbols[12], "render", .method, 20, 20);
    try expectSymbol(result.symbols[13], "label", .method, 21, 23);
    try expectSymbol(result.symbols[14], "new", .method, 27, 29);
    try expectSymbol(result.symbols[15], "value", .method, 31, 33);
    try expectSymbol(result.symbols[16], "helper", .function, 36, 36);
    try expectSymbol(result.symbols[17], "top_function", .function, 39, 39);
    try expectSymbol(result.symbols[18], "external", .module, 41, 41);
    try expectSymbol(result.symbols[19], "r#async", .function, 43, 43);
    try expectSymbol(result.symbols[20], "MARKDOWN_NAME", .other, 45, 45);
    try expectCaveat(result.symbols[1].caveats, "const and static items map to provider SymbolKind.other because no constant- or static-specific kind exists");
    try expectCaveat(result.symbols[8].caveats, "enum variants map to provider SymbolKind.other; tuple and field payloads are not interpreted semantically");
    try expectCaveat(result.symbols[12].caveats, "method classification is derived from direct impl or trait declaration-list syntax; trait and type resolution are out of scope");
    try expectCaveat(result.symbols[18].caveats, "external mod declarations are emitted by syntactic name only; no file-system or crate module resolution is performed");
}

test "empty Rust fixture returns a file module symbol only" {
    var result = try extractRustQuerySymbols(std.testing.allocator, "crates/demo/src/empty.rs", empty_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 1), result.symbols.len);
    try expectSymbol(result.symbols[0], "crates/demo/src/empty.rs", .module, 1, 1);
}

test "generated Rust fixture is parsed with generated caveats only" {
    var result = try extractRustQuerySymbols(std.testing.allocator, "crates/demo/src/generated.rs", generated_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 3), result.symbols.len);
    try expectSymbol(result.symbols[0], "crates/demo/src/generated.rs", .module, 1, 5);
    try expectSymbol(result.symbols[1], "Generated", .type, 3, 3);
    try expectSymbol(result.symbols[2], "generated_function", .function, 4, 4);
    try expectCaveat(result.symbols[2].caveats, "generated-file markers are caveated only; generated-source policy is not evaluated by this proof");
}

test "macro and cfg Rust fixture is caveated without macro expansion or cfg evaluation" {
    var result = try extractRustQuerySymbols(std.testing.allocator, "crates/demo/src/macro_cfg.rs", macro_cfg_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 4), result.symbols.len);
    try std.testing.expectEqual(@as(usize, 1), result.attribute_capture_count);
    try std.testing.expectEqual(@as(usize, 1), result.macro_definition_capture_count);
    try std.testing.expectEqual(@as(usize, 1), result.macro_invocation_capture_count);
    try expectSymbol(result.symbols[0], "crates/demo/src/macro_cfg.rs", .module, 1, 15);
    try expectSymbol(result.symbols[1], "cfg_only", .function, 2, 2);
    try expectSymbol(result.symbols[2], "DynTrait", .type, 12, 14);
    try expectSymbol(result.symbols[3], "from_trait", .method, 13, 13);
    try expectNoSymbol(result.symbols, "from_macro");
    try expectNoSymbol(result.symbols, "make_item");
    try expectCaveat(result.symbols[1].caveats, "macro definitions and invocations are counted only; macro expansion output is not inferred as symbols");
    try expectCaveat(result.symbols[1].caveats, "conditional compilation attributes are caveated only; no cfg or feature evaluation is performed");
}

test "invalid partial Rust fixture fails safely without diagnostics" {
    var result = try extractRustQuerySymbols(std.testing.allocator, "crates/demo/src/invalid_partial.rs", invalid_partial_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.failed, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try expectCaveat(result.caveats, "no parser diagnostics or source snippets exposed");
}

test "unsupported and unsafe Rust query paths fail closed" {
    var result = try extractRustQuerySymbols(std.testing.allocator, "docs/unsupported.md", unsupported_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.unsupported, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try expectCaveat(result.caveats, "no Rust parser was run for the unsupported path");

    try std.testing.expectError(error.InvalidRepoRelativePath, extractRustQuerySymbols(std.testing.allocator, "../private/source.rs", "pub fn hidden() {}\n"));
}
