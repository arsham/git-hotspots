const std = @import("std");
const provider = @import("provider");
const common = @import("tree_sitter_typescript_query_common.zig");
const c = common.c;

extern fn tree_sitter_tsx() *const c.TSLanguage;

const query_source = @embedFile("fixtures/tree_sitter_tsx_query/tsx-symbols.scm");
const component_source = @embedFile("fixtures/tree_sitter_tsx_query/component.tsx");
const generated_source = @embedFile("fixtures/tree_sitter_tsx_query/generated.tsx");
const invalid_partial_source = @embedFile("fixtures/tree_sitter_tsx_query/invalid_partial.tsx");
const unsupported_source = @embedFile("fixtures/tree_sitter_tsx_query/unsupported.ts");
const empty_source = @embedFile("fixtures/tree_sitter_tsx_query/empty.tsx");

const provider_name = "tree-sitter-tsx-query-proof";
const expected_capture_names = [_][]const u8{
    "tsx.module",
    "tsx.definition.name",
    "tsx.class.definition",
    "tsx.function.definition",
    "tsx.method.definition",
    "tsx.interface.definition",
    "tsx.type.definition",
    "tsx.enum.definition",
    "tsx.namespace.definition",
    "tsx.variable.definition",
    "tsx.import.statement",
    "tsx.export.statement",
    "tsx.jsx.syntax",
};
const supported_extensions = [_][]const u8{".tsx"};
const unsupported_path_caveats = [_][]const u8{
    "unsupported path: only repo-relative .tsx files are TSX query candidates",
    "no TSX parser was run for the unsupported path",
    "plain TypeScript paths are handled by the separate TypeScript query contract",
};
fn queryContract() common.QueryContract {
    return .{
        .language = tree_sitter_tsx(),
        .query_source = query_source,
        .capture_prefix = "tsx",
        .provider_name = provider_name,
        .supported_extensions = &supported_extensions,
        .unsupported_path_caveats = &unsupported_path_caveats,
        .is_tsx = true,
    };
}

test "TSX query contract exposes expected capture names" {
    try common.expectCaptureNames(queryContract(), &expected_capture_names);
}

test "extracts supported TSX query symbols and JSX components in deterministic source order" {
    var result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "packages/app/src/component.tsx", component_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 8), result.symbols.len);
    try common.expectSymbol(result.symbols[0], provider_name, "packages/app/src/component.tsx", .module, 1, 24);
    try common.expectSymbol(result.symbols[1], provider_name, "Props", .type, 2, 5);
    try common.expectSymbol(result.symbols[2], provider_name, "Panel", .function, 7, 9);
    try common.expectSymbol(result.symbols[3], provider_name, "InlineWidget", .function, 11, 11);
    try common.expectSymbol(result.symbols[4], provider_name, "ClassWidget", .class, 13, 17);
    try common.expectSymbol(result.symbols[5], provider_name, "render", .method, 14, 16);
    try common.expectSymbol(result.symbols[6], provider_name, "PanelProps", .type, 19, 19);
    try common.expectSymbol(result.symbols[7], provider_name, "DisplayMode", .type, 21, 23);
    try common.expectNoSymbol(result.symbols, "ReactNode");
    try common.expectCaveat(result.caveats, "TSX JSX syntax and JSX components are query-covered structurally without React, DOM, package, or type analysis");
    try common.expectCaveat(result.symbols[3].caveats, "TSX JSX syntax and JSX components are query-covered structurally without React, DOM, package, or type analysis");
}

test "empty TSX fixture returns a module symbol only" {
    var result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "src/empty.tsx", empty_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 1), result.symbols.len);
    try common.expectSymbol(result.symbols[0], provider_name, "src/empty.tsx", .module, 1, 1);
}

test "invalid partial TSX fixture fails safely without diagnostics" {
    var result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "src/invalid_partial.tsx", invalid_partial_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.failed, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try common.expectCaveat(result.caveats, "no parser diagnostics or source snippets exposed");
}

test "generated TSX fixture is parsed with caveats only" {
    var result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "src/generated.tsx", generated_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.ok, result.failure);
    try std.testing.expectEqual(@as(usize, 2), result.symbols.len);
    try common.expectSymbol(result.symbols[0], provider_name, "src/generated.tsx", .module, 1, 3);
    try common.expectSymbol(result.symbols[1], provider_name, "GeneratedView", .function, 2, 2);
    try common.expectCaveat(result.symbols[1].caveats, "generated-file markers and minified one-line source are caveated only; generated/minified policy is not evaluated by this proof");
}

test "unsupported and unsafe TSX query paths fail closed" {
    var result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "packages/app/src/unsupported.ts", unsupported_source);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(provider.Failure.unsupported, result.failure);
    try std.testing.expectEqual(@as(usize, 0), result.symbols.len);
    try common.expectCaveat(result.caveats, "plain TypeScript paths are handled by the separate TypeScript query contract");

    try std.testing.expectError(error.InvalidRepoRelativePath, common.extractQuerySymbols(std.testing.allocator, queryContract(), "../private/source.tsx", "export function Hidden() { return <div />; }\n"));
}
