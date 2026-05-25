# Tree-sitter TypeScript and TSX symbol extraction proof

This is an internal, non-product proof. It does not add runtime TypeScript or
TSX `--symbols` output, a provider registry entry, CLI flags, report schema
fields, scoring, cache behaviour, telemetry, network access, parser generation,
Node/package/workspace/module-resolution analysis, `tsconfig` interpretation,
type checking, LSP analysis, custom user queries, or symbol history.

## Proof targets

- TypeScript target: `zig build tree-sitter-typescript-symbol-proof`
- TSX target: `zig build tree-sitter-tsx-symbol-proof`
- Sources: `tests/tree_sitter_typescript_symbol_proof.zig`,
  `tests/tree_sitter_tsx_symbol_proof.zig`, and shared test-only extraction in
  `tests/tree_sitter_typescript_query_common.zig`
- Query contract: `docs/tree-sitter-typescript-query-contract.md`
- Query assets:
  `tests/fixtures/tree_sitter_typescript_query/typescript-symbols.scm` and
  `tests/fixtures/tree_sitter_tsx_query/tsx-symbols.scm`
- Parser inputs: vendored `third_party/tree-sitter-core/v0.26.9/lib/src/lib.c`
  plus vendored `third_party/tree-sitter-typescript/v0.23.2/typescript/src/*`
  or `third_party/tree-sitter-typescript/v0.23.2/tsx/src/*` parser/scanner
  sources only
- CI: the two new symbol proof targets are included after the existing
  Tree-sitter proof steps and remain local after checkout and Zig setup.

## Supported subset

The proofs map the Feature 0058 project-owned query captures into the existing
`provider.CurrentSymbolEvidence` shape inside tests only:

- program roots as `SymbolKind.module`, named by repo-relative `.ts`, `.mts`,
  `.cts`, or `.tsx` paths
- class declarations as `SymbolKind.class`
- function declarations, nested functions, and direct function-valued
  module-level bindings as `SymbolKind.function`
- direct class-body methods as `SymbolKind.method`
- module-level uppercase simple bindings as `SymbolKind.other`, because no
  constant-specific public kind exists
- other module-level simple bindings as `SymbolKind.variable`
- interfaces, type aliases, enums, and namespaces as `SymbolKind.type`, with no
  public schema expansion
- import/export statements and TSX JSX syntax as query-covered evidence only;
  they do not emit standalone symbols
- anonymous default exports are skipped instead of inventing unstable names;
  deterministic named TSX component-shaped functions and function-valued
  bindings are emitted

## Ranges, ordering, caveats, and degraded cases

Ranges are deterministic one-based inclusive line ranges from the symbol
definition node. Module ranges come from the Tree-sitter `program` node.
Ordering is deterministic source order by symbol-node start byte, with the
module symbol first.

The proof records caveats for current-only evidence, method names as bare
property identifiers, constant-like bindings mapping to `SymbolKind.other`,
TypeScript type-like declarations mapping to `SymbolKind.type`, generated or
minified files, TSX JSX structural coverage without React/DOM/package/type
analysis, and local/offline proof boundaries.

Unsupported paths return `unsupported` without parsing. Unsafe repo-relative
paths are rejected before parsing. Invalid or partial source returns `failed`
with caveats only; raw parser diagnostics and source snippets are not exposed.
If export, anonymous, namespace, or component naming is not deterministic, the
proof skips or caveats the construct rather than expanding the public schema.

## Deferred runtime boundary

TypeScript and TSX runtime `--symbols` output is not implemented yet. This proof
adds no runtime provider registry wiring, CLI/report/schema/scoring/cache
changes, line-history integration, package metadata handling, Node execution,
workspace scanning, `tsconfig` analysis, type checking, LSP analysis, custom
query execution, snippets, authors, emails, ownership metrics, quality scoring,
developer ranking, or bug prediction.

## Validation evidence

Fresh local validation on 2026-05-25:

| Command | Exit status | Privacy-safe observation |
| --- | --- | --- |
| `zig build validate` | `0` | Product validation passed without TypeScript or TSX runtime provider output. |
| `zig build tree-sitter-typescript-build-proof` | `0` | Existing TypeScript parser/scanner build proof compiled, linked, and ran. |
| `zig build tree-sitter-tsx-build-proof` | `0` | Existing TSX parser/scanner build proof compiled, linked, and ran. |
| `zig build tree-sitter-typescript-query-proof` | `0` | Project-owned TypeScript query contract fixtures passed. |
| `zig build tree-sitter-tsx-query-proof` | `0` | Project-owned TSX query contract fixtures passed with JSX syntax coverage. |
| `zig build tree-sitter-typescript-symbol-proof` | `0` | TypeScript query captures mapped into current symbol evidence with deterministic ordering, ranges, kinds, caveats, and degraded cases. |
| `zig build tree-sitter-tsx-symbol-proof` | `0` | TSX query captures and deterministic component cases mapped into current symbol evidence with caveats and degraded cases. |
| `git diff --check` | `0` | No whitespace errors were reported. |

The proofs use only repository-local vendored Tree-sitter core and
Tree-sitter TypeScript parser/scanner sources plus local fixtures. They perform
no network access, package-manager resolution, parser generation, telemetry,
upload, remote enrichment, background analysis, runtime TypeScript/TSX provider
registration, package/workspace scanning, module-resolution analysis, CI release
automation, cache use, or artifacts.
