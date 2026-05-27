const std = @import("std");
const tree_sitter_rust = @import("tree_sitter_rust");
const provider = tree_sitter_rust.provider_api;

const supported_source = @embedFile("fixtures/tree_sitter_rust_query/supported_subset.rs");
const invalid_partial_source = @embedFile("fixtures/tree_sitter_rust_query/invalid_partial.rs");
const empty_source = @embedFile("fixtures/tree_sitter_rust_query/empty.rs");
const generated_source = @embedFile("fixtures/tree_sitter_rust_query/generated.rs");
const macro_cfg_source = @embedFile("fixtures/tree_sitter_rust_query/macro_cfg.rs");
const unsupported_source = @embedFile("fixtures/tree_sitter_rust_query/unsupported.md");

const query_fingerprint = "src/queries/rust-symbols.scm:rust-symbol-query-v1";

fn expectProviderEvidence(
    evidence: provider.ProviderEvidence,
    expected_input_identity: []const u8,
    expected_failure: provider.Failure,
    expected_freshness: provider.Freshness,
    expected_confidence: provider.Confidence,
) !void {
    try std.testing.expectEqualStrings(tree_sitter_rust.provider_name, evidence.name);
    try std.testing.expectEqual(provider.ProviderKind.symbol, evidence.kind);
    try std.testing.expectEqualStrings(tree_sitter_rust.provider_version, evidence.version);
    try std.testing.expectEqualStrings(provider.contract_version, evidence.contract_version);
    try std.testing.expectEqualStrings(query_fingerprint, evidence.config_fingerprint.?);
    try std.testing.expectEqualStrings(expected_input_identity, evidence.input.identity);
    try std.testing.expectEqual(expected_freshness, evidence.freshness);
    try std.testing.expectEqual(expected_failure, evidence.failure);
    try std.testing.expectEqual(expected_confidence, evidence.confidence);
    try std.testing.expectEqualStrings(tree_sitter_rust.provider_name, evidence.provenance.provider_name);
    try std.testing.expectEqualStrings(expected_input_identity, evidence.provenance.input_identity);
}

fn expectSymbol(symbol: provider.CurrentSymbolEvidence, name: []const u8, kind: provider.SymbolKind, start: u32, end: u32) !void {
    try std.testing.expectEqualStrings(name, symbol.name);
    try std.testing.expectEqual(kind, symbol.kind);
    try std.testing.expectEqualStrings(tree_sitter_rust.provider_name, symbol.provider_name);
    try std.testing.expectEqual(provider.Confidence.high, symbol.confidence);
    try std.testing.expect(symbol.current_line_history == null);
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

test "Rust symbol proof maps query captures into current symbol evidence metadata" {
    var result = try tree_sitter_rust.extractSource(std.testing.allocator, "crates/demo/src/supported_subset.rs", supported_source);
    defer result.deinit(std.testing.allocator);

    try expectProviderEvidence(result.provider, "working-tree:crates/demo/src/supported_subset.rs", .ok, .fresh, .high);
    try std.testing.expectEqual(@as(usize, 21), result.symbols.len);
    try expectSymbol(result.symbols[0], "crates/demo/src/supported_subset.rs", .module, 1, 46);
    try expectSymbol(result.symbols[1], "LIMIT", .other, 3, 3);
    try expectSymbol(result.symbols[3], "nested", .module, 6, 37);
    try expectSymbol(result.symbols[6], "Record", .type, 9, 11);
    try expectSymbol(result.symbols[12], "render", .method, 20, 20);
    try expectSymbol(result.symbols[17], "top_function", .function, 39, 39);
    try expectSymbol(result.symbols[18], "external", .module, 41, 41);
    try expectNoSymbol(result.symbols, "from_macro");
    try expectCaveat(result.provider.caveats, provider.CurrentSymbolEvidence.semantics);
    try expectCaveat(result.symbols[18].caveats, "external mod declarations are emitted by syntactic name only; no file-system or crate module resolution is performed");
}

test "Rust symbol proof covers duplicate names as deterministic current rows" {
    const duplicate_source =
        \\pub fn duplicate() {}
        \\pub mod nested {
        \\    pub fn duplicate() {}
        \\}
    ;

    var result = try tree_sitter_rust.extractSource(std.testing.allocator, "crates/demo/src/duplicate_names.rs", duplicate_source);
    defer result.deinit(std.testing.allocator);

    try expectProviderEvidence(result.provider, "working-tree:crates/demo/src/duplicate_names.rs", .ok, .fresh, .high);
    try std.testing.expectEqual(@as(usize, 4), result.symbols.len);
    try expectSymbol(result.symbols[1], "duplicate", .function, 1, 1);
    try expectSymbol(result.symbols[2], "nested", .module, 2, 4);
    try expectSymbol(result.symbols[3], "duplicate", .function, 3, 3);
}

test "Rust symbol proof covers empty generated macro cfg unsupported and failed states" {
    var empty = try tree_sitter_rust.extractSource(std.testing.allocator, "crates/demo/src/empty.rs", empty_source);
    defer empty.deinit(std.testing.allocator);
    try expectProviderEvidence(empty.provider, "working-tree:crates/demo/src/empty.rs", .ok, .fresh, .high);
    try std.testing.expectEqual(@as(usize, 1), empty.symbols.len);
    try expectSymbol(empty.symbols[0], "crates/demo/src/empty.rs", .module, 1, 1);

    var generated = try tree_sitter_rust.extractSource(std.testing.allocator, "crates/demo/src/generated.rs", generated_source);
    defer generated.deinit(std.testing.allocator);
    try expectProviderEvidence(generated.provider, "working-tree:crates/demo/src/generated.rs", .ok, .fresh, .high);
    try expectCaveat(generated.provider.caveats, "generated-file markers are caveated only; generated-source policy is not evaluated by this provider");

    var macro_cfg = try tree_sitter_rust.extractSource(std.testing.allocator, "crates/demo/src/macro_cfg.rs", macro_cfg_source);
    defer macro_cfg.deinit(std.testing.allocator);
    try expectProviderEvidence(macro_cfg.provider, "working-tree:crates/demo/src/macro_cfg.rs", .ok, .fresh, .high);
    try expectSymbol(macro_cfg.symbols[1], "cfg_only", .function, 2, 2);
    try expectNoSymbol(macro_cfg.symbols, "from_macro");
    try expectCaveat(macro_cfg.provider.caveats, "macro definitions and invocations are counted only; macro expansion output is not inferred as symbol evidence");
    try expectCaveat(macro_cfg.provider.caveats, "conditional compilation attributes are caveated only; no cfg or feature evaluation is performed");

    var invalid = try tree_sitter_rust.extractSource(std.testing.allocator, "crates/demo/src/invalid_partial.rs", invalid_partial_source);
    defer invalid.deinit(std.testing.allocator);
    try expectProviderEvidence(invalid.provider, "working-tree:crates/demo/src/invalid_partial.rs", .failed, .unknown, .low);
    try std.testing.expectEqual(@as(usize, 0), invalid.symbols.len);
    try expectCaveat(invalid.provider.caveats, "invalid or partial Rust source failed closed without parser diagnostics or source snippets");

    var unsupported = try tree_sitter_rust.extractSource(std.testing.allocator, "docs/unsupported.md", unsupported_source);
    defer unsupported.deinit(std.testing.allocator);
    try expectProviderEvidence(unsupported.provider, "working-tree:docs/unsupported.md", .unsupported, .unknown, .unknown);
    try std.testing.expectEqual(@as(usize, 0), unsupported.symbols.len);

    try std.testing.expectError(error.InvalidRepoRelativePath, tree_sitter_rust.extractSource(std.testing.allocator, "../private/source.rs", "pub fn hidden() {}\n"));
}
