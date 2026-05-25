const std = @import("std");
const provider = @import("provider");
const common = @import("tree_sitter_typescript_query_common.zig");
const c = common.c;

extern fn tree_sitter_typescript() *const c.TSLanguage;

const query_source = @embedFile("fixtures/tree_sitter_typescript_query/typescript-symbols.scm");
const supported_source = @embedFile("fixtures/tree_sitter_typescript_query/supported_subset.ts");
const module_source = @embedFile("fixtures/tree_sitter_typescript_query/module_case.mts");
const commonjs_source = @embedFile("fixtures/tree_sitter_typescript_query/common_case.cts");
const generated_source = @embedFile("fixtures/tree_sitter_typescript_query/generated.min.ts");
const invalid_partial_source = @embedFile("fixtures/tree_sitter_typescript_query/invalid_partial.ts");
const unsupported_source = @embedFile("fixtures/tree_sitter_typescript_query/unsupported.js");
const empty_source = @embedFile("fixtures/tree_sitter_typescript_query/empty.ts");

const provider_name = "tree-sitter-typescript-query-proof";
const expected_capture_names = [_][]const u8{
    "typescript.module",
    "typescript.definition.name",
    "typescript.class.definition",
    "typescript.function.definition",
    "typescript.method.definition",
    "typescript.interface.definition",
    "typescript.type.definition",
    "typescript.enum.definition",
    "typescript.namespace.definition",
    "typescript.variable.definition",
    "typescript.import.statement",
    "typescript.export.statement",
};
const supported_extensions = [_][]const u8{ ".ts", ".mts", ".cts" };
const unsupported_path_caveats = [_][]const u8{
    "unsupported path: only repo-relative .ts, .mts, and .cts files are TypeScript query candidates",
    "no TypeScript parser was run for the unsupported path",
    "TSX paths are handled by the separate TSX query contract",
};
fn queryContract() common.QueryContract {
    return .{
        .language = tree_sitter_typescript(),
        .query_source = query_source,
        .capture_prefix = "typescript",
        .provider_name = provider_name,
        .supported_extensions = &supported_extensions,
        .unsupported_path_caveats = &unsupported_path_caveats,
        .is_tsx = false,
    };
}

test "TypeScript query contract exposes expected capture names" {
    try common.expectCaptureNames(queryContract(), &expected_capture_names);
}

test "extracts supported TypeScript query symbols in deterministic source order" {
    var result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "packages/app/src/supported_subset.ts", supported_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 13), result.symbols.len);
    try common.expectSymbol(result.symbols[0], provider_name, "packages/app/src/supported_subset.ts", .module, 1, 35);
    try common.expectSymbol(result.symbols[1], provider_name, "EXPORTED_FLAG", .other, 3, 3);
    try common.expectSymbol(result.symbols[2], provider_name, "mutableCount", .variable, 4, 4);
    try common.expectSymbol(result.symbols[3], provider_name, "compute", .function, 6, 11);
    try common.expectSymbol(result.symbols[4], provider_name, "localHelper", .function, 7, 9);
    try common.expectSymbol(result.symbols[5], provider_name, "LocalWorker", .class, 13, 18);
    try common.expectSymbol(result.symbols[6], provider_name, "run", .method, 14, 17);
    try common.expectSymbol(result.symbols[7], provider_name, "methodHelper", .function, 15, 15);
    try common.expectSymbol(result.symbols[8], provider_name, "UserShape", .type, 20, 22);
    try common.expectSymbol(result.symbols[9], provider_name, "UserId", .type, 24, 24);
    try common.expectSymbol(result.symbols[10], provider_name, "Mode", .type, 26, 28);
    try common.expectSymbol(result.symbols[11], provider_name, "Tools", .type, 30, 32);
    try common.expectSymbol(result.symbols[12], provider_name, "inside", .function, 31, 31);
    try common.expectNoSymbol(result.symbols, "ExportedWorker");
    try common.expectCaveat(result.symbols[1].caveats, "constant-like uppercase module bindings map to provider SymbolKind.other because no constant-specific kind exists");
    try common.expectCaveat(result.symbols[6].caveats, "method classification is derived from a direct class body; method names are bare property identifiers");
    try common.expectCaveat(result.symbols[8].caveats, "interfaces, type aliases, enums, and namespaces map to provider SymbolKind.type; no public schema expansion is made");
}

test "TypeScript query admits mts and cts paths without workspace analysis" {
    var module_result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "packages/lib/module_case.mts", module_source);
    defer module_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, module_result.failure);
    try common.expectSymbol(module_result.symbols[0], provider_name, "packages/lib/module_case.mts", .module, 1, 4);
    try common.expectSymbol(module_result.symbols[1], provider_name, "moduleEntry", .function, 1, 3);

    var commonjs_result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "packages/lib/common_case.cts", commonjs_source);
    defer commonjs_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, commonjs_result.failure);
    try common.expectSymbol(commonjs_result.symbols[0], provider_name, "packages/lib/common_case.cts", .module, 1, 3);
    try common.expectSymbol(commonjs_result.symbols[1], provider_name, "legacyValue", .variable, 1, 1);
}

test "empty TypeScript fixture returns a module symbol only" {
    var result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "src/empty.ts", empty_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 1), result.symbols.len);
    try common.expectSymbol(result.symbols[0], provider_name, "src/empty.ts", .module, 1, 1);
}

test "invalid partial TypeScript fixture fails safely without diagnostics" {
    var result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "src/invalid_partial.ts", invalid_partial_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.failed, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try common.expectCaveat(result.caveats, "no parser diagnostics or source snippets exposed");
}

test "generated and minified TypeScript fixture is parsed with caveats only" {
    var result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "src/generated.min.ts", generated_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 3), result.symbols.len);
    try common.expectSymbol(result.symbols[0], provider_name, "src/generated.min.ts", .module, 1, 3);
    try common.expectSymbol(result.symbols[1], provider_name, "GENERATED_VALUE", .other, 2, 2);
    try common.expectSymbol(result.symbols[2], provider_name, "generatedFunction", .function, 2, 2);
    try common.expectCaveat(result.symbols[2].caveats, "generated-file markers and minified one-line source are caveated only; generated/minified policy is not evaluated by this proof");
}

test "unsupported and unsafe TypeScript query paths fail closed" {
    var result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "packages/app/src/unsupported.js", unsupported_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.unsupported, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try common.expectCaveat(result.caveats, "TSX paths are handled by the separate TSX query contract");

    try std.testing.expectError(error.InvalidRepoRelativePath, common.extractQuerySymbols(std.testing.allocator, queryContract(), "../private/source.ts", "export function hidden() {}\n"));
}
