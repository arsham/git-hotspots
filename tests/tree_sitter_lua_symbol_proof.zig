const std = @import("std");
const provider = @import("provider");
const lua_query_proof = @import("tree_sitter_lua_query_proof.zig");

const supported_source = @embedFile("fixtures/tree_sitter_lua_query/supported_subset.lua");
const invalid_partial_source = @embedFile("fixtures/tree_sitter_lua_query/invalid_partial.lua");
const empty_source = @embedFile("fixtures/tree_sitter_lua_query/empty.lua");
const unsupported_source = @embedFile("fixtures/tree_sitter_lua_query/unsupported.md");

const provider_name = "tree-sitter-lua-symbol-proof";
const provider_version = "tree-sitter-core@v0.26.9/tree-sitter-lua@v0.5.0/lua-symbol-query-v1";
const query_fingerprint = "tests/fixtures/tree_sitter_lua_query/lua-symbols.scm:lua-symbol-query-v1";

fn expectProviderEvidence(
    evidence: provider.ProviderEvidence,
    expected_input_identity: []const u8,
    expected_failure: provider.Failure,
    expected_freshness: provider.Freshness,
    expected_confidence: provider.Confidence,
) !void {
    try std.testing.expectEqualStrings(provider_name, evidence.name);
    try std.testing.expectEqual(provider.ProviderKind.symbol, evidence.kind);
    try std.testing.expectEqualStrings(provider_version, evidence.version);
    try std.testing.expectEqualStrings(provider.contract_version, evidence.contract_version);
    try std.testing.expectEqualStrings(query_fingerprint, evidence.config_fingerprint.?);
    try std.testing.expectEqualStrings(expected_input_identity, evidence.input.identity);
    try std.testing.expectEqual(expected_freshness, evidence.freshness);
    try std.testing.expectEqual(expected_failure, evidence.failure);
    try std.testing.expectEqual(expected_confidence, evidence.confidence);
    try std.testing.expectEqualStrings(provider_name, evidence.provenance.provider_name);
    try std.testing.expectEqualStrings(expected_input_identity, evidence.provenance.input_identity);
}

fn expectSymbol(symbol: provider.CurrentSymbolEvidence, name: []const u8, kind: provider.SymbolKind, start: u32, end: u32) !void {
    try std.testing.expectEqualStrings(name, symbol.name);
    try std.testing.expectEqual(kind, symbol.kind);
    try std.testing.expectEqualStrings(provider_name, symbol.provider_name);
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

test "Lua symbol proof maps query captures into current symbol evidence metadata" {
    var result = try lua_query_proof.extractLuaQuerySymbolsWithProvider(std.testing.allocator, provider_name, "lua/supported_subset.lua", supported_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try expectProviderEvidence(result.provider, "lua/supported_subset.lua", .ok, .fresh, .high);
    try std.testing.expectEqual(@as(usize, 10), result.symbols.len);
    try expectSymbol(result.symbols[0], "lua/supported_subset.lua", .module, 1, 33);
    try expectSymbol(result.symbols[1], "CONFIG", .other, 2, 2);
    try expectSymbol(result.symbols[3], "exports", .variable, 4, 15);
    try expectSymbol(result.symbols[5], "build", .function, 6, 9);
    try expectSymbol(result.symbols[9], "run", .method, 28, 30);
    try expectNoSymbol(result.symbols, "ignored_inner");
    try expectNoSymbol(result.symbols, "inside");
    try expectNoSymbol(result.symbols, "skipped");
    try expectCaveat(result.provider.caveats, "runtime Lua --symbols output is not implemented by this proof");
    try expectCaveat(result.symbols[1].caveats, "constant-like uppercase Lua names map to provider SymbolKind.other because no constant-specific kind exists");
    try expectCaveat(result.symbols[9].caveats, "colon method classification is derived from method_index_expression; method names are bare identifiers");
}

test "Lua symbol proof keeps duplicate names as deterministic current rows" {
    const duplicate_source =
        \\local duplicate = 1
        \\local duplicate = 2
        \\function duplicate()
        \\  return duplicate
        \\end
    ;

    var result = try lua_query_proof.extractLuaQuerySymbolsWithProvider(std.testing.allocator, provider_name, "lua/duplicate_names.lua", duplicate_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try expectProviderEvidence(result.provider, "lua/duplicate_names.lua", .ok, .fresh, .high);
    try std.testing.expectEqual(@as(usize, 4), result.symbols.len);
    try expectSymbol(result.symbols[1], "duplicate", .variable, 1, 1);
    try expectSymbol(result.symbols[2], "duplicate", .variable, 2, 2);
    try expectSymbol(result.symbols[3], "duplicate", .function, 3, 5);
}

test "Lua symbol proof covers empty unsupported and failed states" {
    var empty = try lua_query_proof.extractLuaQuerySymbolsWithProvider(std.testing.allocator, provider_name, "lua/empty.lua", empty_source);
    defer empty.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, empty.failure);
    try expectProviderEvidence(empty.provider, "lua/empty.lua", .ok, .fresh, .high);
    try std.testing.expectEqual(@as(usize, 1), empty.symbols.len);
    try expectSymbol(empty.symbols[0], "lua/empty.lua", .module, 1, 1);

    var invalid = try lua_query_proof.extractLuaQuerySymbolsWithProvider(std.testing.allocator, provider_name, "lua/invalid_partial.lua", invalid_partial_source);
    defer invalid.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.failed, invalid.failure);
    try expectProviderEvidence(invalid.provider, "lua/invalid_partial.lua", .failed, .unknown, .low);
    try std.testing.expectEqual(@as(usize, 0), invalid.symbols.len);
    try expectCaveat(invalid.caveats, "no parser diagnostics or source snippets exposed");

    var unsupported = try lua_query_proof.extractLuaQuerySymbolsWithProvider(std.testing.allocator, provider_name, "docs/unsupported.md", unsupported_source);
    defer unsupported.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unsupported, unsupported.failure);
    try expectProviderEvidence(unsupported.provider, "docs/unsupported.md", .unsupported, .unknown, .unknown);
    try std.testing.expectEqual(@as(usize, 0), unsupported.symbols.len);
    try expectCaveat(unsupported.caveats, "no Lua parser was run for the unsupported path");

    try std.testing.expectError(error.InvalidRepoRelativePath, lua_query_proof.extractLuaQuerySymbolsWithProvider(std.testing.allocator, provider_name, "../private/source.lua", "local hidden = true\n"));
}
