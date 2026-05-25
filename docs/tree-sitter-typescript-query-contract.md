# Tree-sitter TypeScript and TSX query contract and fixtures

This is a non-product, test-only contract for future TypeScript and TSX
Tree-sitter symbol providers. It adds project-owned query assets, fixture
corpora, and proof targets without exposing TypeScript or TSX symbols through
the CLI, reports, provider registry, scoring, cache, or runtime defaults.

## Scope and protected surfaces

Changed implementation surfaces are limited to:

- `tests/fixtures/tree_sitter_typescript_query/typescript-symbols.scm`
- `tests/fixtures/tree_sitter_tsx_query/tsx-symbols.scm`
- `tests/fixtures/tree_sitter_typescript_query/*`
- `tests/fixtures/tree_sitter_tsx_query/*`
- `tests/tree_sitter_typescript_query_common.zig`
- `tests/tree_sitter_typescript_query_proof.zig`
- `tests/tree_sitter_tsx_query_proof.zig`
- `build.zig`
- `docs/tree-sitter-typescript-query-contract.md`

The contract does not change `src/`, CLI flags, report schemas, scoring, cache
behavior, provider registration, runtime TypeScript or TSX symbol output,
CI/release/package behavior, LSP behavior, Node/package/workspace/module
analysis, network access, telemetry, uploads, remote enrichment, parser
generation, system package use, or custom user query execution.

## Query identities

| Field | TypeScript | TSX |
| --- | --- | --- |
| Query version | `typescript-symbol-query-v1` | `tsx-symbol-query-v1` |
| Provider proof name | `tree-sitter-typescript-query-proof` | `tree-sitter-tsx-query-proof` |
| Grammar input | vendored `third_party/tree-sitter-typescript/v0.23.2/typescript` | vendored `third_party/tree-sitter-typescript/v0.23.2/tsx` |
| Query asset | `tests/fixtures/tree_sitter_typescript_query/typescript-symbols.scm` | `tests/fixtures/tree_sitter_tsx_query/tsx-symbols.scm` |
| Proof command | `zig build tree-sitter-typescript-query-proof` | `zig build tree-sitter-tsx-query-proof` |

The queries are project-owned. They are not upstream highlight, tags, or user
query imports.

## Capture contract

The TypeScript query supports these capture names:

- `@typescript.module`
- `@typescript.class.definition`
- `@typescript.function.definition`
- `@typescript.method.definition`
- `@typescript.interface.definition`
- `@typescript.type.definition`
- `@typescript.enum.definition`
- `@typescript.namespace.definition`
- `@typescript.variable.definition`
- `@typescript.import.statement`
- `@typescript.export.statement`
- `@typescript.definition.name`

The TSX query mirrors the TypeScript symbol captures with the `tsx` prefix and
adds `@tsx.jsx.syntax` for JSX syntax coverage.

Future runtime work must stop for planning if it needs new public symbol kinds,
custom user queries, package discovery, workspace analysis, Node/module
resolution, tsconfig interpretation, dependency graphs, LSP, type-checker data,
React framework semantics, or runtime provider registry wiring.

## Symbol-kind and range mapping

The proofs map query candidates into the existing
`provider.CurrentSymbolEvidence` shape only inside tests:

| Query candidate | Proof mapping |
| --- | --- |
| Program root | `SymbolKind.module`; symbol name is the repo-relative `.ts`, `.mts`, `.cts`, or `.tsx` path. |
| Class declaration | `SymbolKind.class`; symbol name is the captured type identifier. |
| Function declaration | `SymbolKind.function`; nested functions use bare names. |
| Direct class-body method | `SymbolKind.method`; method names are bare property identifiers. |
| Interface, type alias, enum, namespace | `SymbolKind.type`; no public schema expansion is made. |
| Module-level uppercase simple binding | `SymbolKind.other`, because there is no constant-specific kind. |
| Module-level simple binding | `SymbolKind.variable`. |
| Module-level function-valued binding | `SymbolKind.function` when the initializer is a direct function or arrow function. |
| Import/export statements | Query-covered fixture evidence only; no standalone symbols are emitted. |
| TSX JSX syntax | Query-covered structural evidence only; no React, DOM, package, type-checker, or framework analysis is performed. |

Ranges are one-based inclusive line ranges from the symbol definition node. The
module range is the Tree-sitter program node range. Ordering is deterministic
source order by symbol node start byte, with the module symbol first.

## Supported and caveated subset

The TypeScript proof-covered subset includes `.ts`, `.mts`, `.cts`,
program/module roots, empty files, named functions, nested functions, named
classes, direct class-body methods, interfaces, type aliases, enums, namespaces,
module-level variables and constants, function-valued variables, import/export
statements as non-emitted query evidence, generated/minified caveats,
invalid/partial files, unsupported non-TypeScript paths, unsafe paths, and
monorepo-style repo-relative paths.

The TSX proof-covered subset includes `.tsx`, the TypeScript symbol subset used
by local fixtures, JSX syntax and component-shaped functions/function-valued
bindings, generated caveats, invalid/partial files, unsupported plain
TypeScript paths, unsafe paths, and monorepo-style repo-relative paths.

Unsupported paths return `unsupported` without parsing. Unsafe paths are
rejected before parsing. Invalid or partial source returns `failed` with caveats
only; raw parser diagnostics and source snippets are not exposed. Generated-file
markers and minified one-line source are caveated only and do not change scoring
or runtime behavior.

## Fixture corpus

| Fixture | Coverage |
| --- | --- |
| `tests/fixtures/tree_sitter_typescript_query/supported_subset.ts` | Monorepo-style `.ts` path, imports, exports, constants, variables, functions, nested functions, class, method, interface, type alias, enum, namespace, and export specifier caveat. |
| `tests/fixtures/tree_sitter_typescript_query/module_case.mts` | `.mts` supported extension and ESM function export. |
| `tests/fixtures/tree_sitter_typescript_query/common_case.cts` | `.cts` supported extension and deterministic module-level binding. |
| `tests/fixtures/tree_sitter_typescript_query/generated.min.ts` | Generated marker and compact source with caveats only. |
| `tests/fixtures/tree_sitter_typescript_query/invalid_partial.ts` | Invalid/partial TypeScript failure without diagnostics or snippets. |
| `tests/fixtures/tree_sitter_typescript_query/empty.ts` | Empty TypeScript module symbol only. |
| `tests/fixtures/tree_sitter_typescript_query/unsupported.js` | Unsupported non-TypeScript path that is not parsed. |
| `tests/fixtures/tree_sitter_tsx_query/component.tsx` | TSX imports, interface, function component, function-valued component binding, class method, type alias, enum, and JSX syntax capture. |
| `tests/fixtures/tree_sitter_tsx_query/generated.tsx` | Generated marker with TSX caveats only. |
| `tests/fixtures/tree_sitter_tsx_query/invalid_partial.tsx` | Invalid/partial TSX failure without diagnostics or snippets. |
| `tests/fixtures/tree_sitter_tsx_query/empty.tsx` | Empty TSX module symbol only. |
| `tests/fixtures/tree_sitter_tsx_query/unsupported.ts` | Unsupported plain TypeScript path for the TSX proof. |

All fixture paths are project-relative. No private paths, raw private reports,
remote URLs, authors, email addresses, commit messages, or source from sibling
repositories are recorded.

## Validation evidence

Fresh local validation on 2026-05-25:

| Command | Exit status | Privacy-safe observation |
| --- | --- | --- |
| `zig build tree-sitter-typescript-query-proof` | `0` | TypeScript query compiled, expected capture names were present, and all local fixtures passed. |
| `zig build tree-sitter-tsx-query-proof` | `0` | TSX query compiled, expected capture names were present, JSX syntax was covered structurally, and all local fixtures passed. |
| `zig build tree-sitter-typescript-build-proof` | `0` | Existing TypeScript parser/scanner build proof still compiled, linked, and ran. |
| `zig build tree-sitter-tsx-build-proof` | `0` | Existing TSX parser/scanner build proof still compiled, linked, and ran. |
| `zig build validate` | `0` | Product validation passed without TypeScript or TSX runtime provider output. |
| `git diff --check` | `0` | No whitespace errors were reported. |

The proofs use only repository-local vendored Tree-sitter core and
Tree-sitter TypeScript parser sources plus local fixtures. They perform no
network access, package-manager resolution, parser generation, telemetry,
upload, remote enrichment, background analysis, provider runtime registration,
TypeScript/TSX runtime analysis, Node execution, package/workspace scanning,
tsconfig interpretation, type-checker analysis, React analysis, or
module-resolution analysis.
