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

const provider_name = "tree-sitter-tsx-symbol-proof";
const supported_extensions = [_][]const u8{".tsx"};
const unsupported_path_caveats = [_][]const u8{
    "unsupported path: only repo-relative .tsx files are TSX symbol proof candidates",
    "no TSX parser was run for the unsupported path",
    "plain TypeScript paths are handled by the separate TypeScript symbol proof",
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

test "TSX symbol proof maps query captures and components into current symbol evidence" {
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
    try std.testing.expect(result.symbols[2].current_line_history == null);
    try common.expectCaveat(result.caveats, provider.CurrentSymbolEvidence.semantics);
    try common.expectCaveat(result.caveats, "TSX JSX syntax and JSX components are query-covered structurally without React, DOM, package, or type analysis");
    try common.expectCaveat(result.symbols[3].caveats, "TSX JSX syntax and JSX components are query-covered structurally without React, DOM, package, or type analysis");
    try common.expectCaveat(result.symbols[5].caveats, "method classification is derived from a direct class body; method names are bare property identifiers");
}

test "TSX symbol proof supports only TSX paths without TypeScript runtime routing" {
    var empty_result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "src/empty.tsx", empty_source);
    defer empty_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, empty_result.failure);
    try common.expectSymbol(empty_result.symbols[0], provider_name, "src/empty.tsx", .module, 1, 1);

    var unsupported_result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "packages/app/src/unsupported.ts", unsupported_source);
    defer unsupported_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.unsupported, unsupported_result.failure);
    try std.testing.expectEqual(@as(usize, 0), unsupported_result.symbols.len);
    try common.expectCaveat(unsupported_result.caveats, "plain TypeScript paths are handled by the separate TypeScript symbol proof");
}

test "TSX symbol proof handles generated invalid unsafe and anonymous cases deterministically" {
    var generated_result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "src/generated.tsx", generated_source);
    defer generated_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, generated_result.failure);
    try common.expectSymbol(generated_result.symbols[0], provider_name, "src/generated.tsx", .module, 1, 3);
    try common.expectSymbol(generated_result.symbols[1], provider_name, "GeneratedView", .function, 2, 2);
    try common.expectCaveat(generated_result.symbols[1].caveats, "generated-file markers and minified one-line source are caveated only; generated/minified policy is not evaluated by this proof");

    var invalid_result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "src/invalid_partial.tsx", invalid_partial_source);
    defer invalid_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.failed, invalid_result.failure);
    try std.testing.expectEqual(@as(usize, 0), invalid_result.symbols.len);
    try common.expectCaveat(invalid_result.caveats, "no parser diagnostics or source snippets exposed");

    const anonymous_source = "export default function () { return <span />; }\nconst Local = () => <div />;\n";
    var anonymous_result = try common.extractQuerySymbols(std.testing.allocator, queryContract(), "src/anonymous.tsx", anonymous_source);
    defer anonymous_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(provider.Failure.ok, anonymous_result.failure);
    try std.testing.expectEqual(@as(usize, 2), anonymous_result.symbols.len);
    try common.expectSymbol(anonymous_result.symbols[0], provider_name, "src/anonymous.tsx", .module, 1, 3);
    try common.expectSymbol(anonymous_result.symbols[1], provider_name, "Local", .function, 2, 2);
    try common.expectNoSymbol(anonymous_result.symbols, "default");

    try std.testing.expectError(error.InvalidRepoRelativePath, common.extractQuerySymbols(std.testing.allocator, queryContract(), "../private/source.tsx", "export function Hidden() { return <div />; }\n"));
}
