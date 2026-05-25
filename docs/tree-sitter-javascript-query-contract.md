# Tree-sitter JavaScript query contract and fixtures

This is a non-product, test-only contract for a future JavaScript Tree-sitter
symbol provider. It adds a project-owned query asset, fixture corpus, and proof
target without exposing JavaScript symbols through the CLI, reports, provider
registry, scoring, cache, or runtime defaults.

## Scope and protected surfaces

Changed implementation surfaces are limited to:

- `tests/fixtures/tree_sitter_javascript_query/javascript-symbols.scm`: the
  project-owned JavaScript symbol candidate query.
- `tests/fixtures/tree_sitter_javascript_query/*`: local proof fixtures for
  `.js`, `.mjs`, `.cjs`, admitted `.jsx`, generated/minified, empty,
  invalid/partial, unsupported TSX, ESM export, CommonJS export, anonymous
  export, and monorepo-style path cases.
- `tests/tree_sitter_javascript_query_proof.zig`: test-only query contract
  proof.
- `build.zig`: the explicit `tree-sitter-javascript-query-proof` build step.
- `docs/tree-sitter-javascript-query-contract.md`: this evidence record.

The contract does not change `src/`, fixture expected product outputs, CLI
flags, report schemas, scoring, cache behavior, provider registration, runtime
JavaScript symbol output, CI/release/package behavior, LSP behavior, TypeScript
or TSX support, Node/package/workspace/module analysis, network access,
telemetry, uploads, remote enrichment, parser generation, system package use,
or custom user query execution.

## Query identity

| Field | Value |
| --- | --- |
| Query version | `javascript-symbol-query-v1` |
| Provider proof name | `tree-sitter-javascript-query-proof` |
| Grammar input | vendored `third_party/tree-sitter-javascript/v0.25.0` |
| Query asset | `tests/fixtures/tree_sitter_javascript_query/javascript-symbols.scm` |
| Proof command | `zig build tree-sitter-javascript-query-proof` |

The query is project-owned. It is not an upstream highlight, tags, or user query
import.

## Capture contract

The supported capture names are:

| Capture | Meaning |
| --- | --- |
| `@javascript.module` | JavaScript program root candidate. |
| `@javascript.class.definition` | Named class declaration node. |
| `@javascript.function.definition` | Named function declaration node. |
| `@javascript.method.definition` | Direct class-body method definition node. |
| `@javascript.variable.definition` | Simple identifier variable declarator node. |
| `@javascript.commonjs.definition` | Named `exports.<name>` or `module.exports.<name>` assignment node after proof-side filtering. |
| `@javascript.definition.name` | Identifier or property identifier paired with a definition candidate. |

Future runtime work must stop for planning if it needs new public symbol kinds,
custom user queries, TypeScript, TSX, package discovery, workspace analysis,
Node/module resolution, dependency graphs, LSP, or runtime provider registry
wiring.

## Symbol-kind and range mapping

The proof maps query candidates into the existing
`provider.CurrentSymbolEvidence` shape only inside tests:

| Query candidate | Proof mapping |
| --- | --- |
| Program root | `SymbolKind.module`; symbol name is the repo-relative `.js`, `.mjs`, `.cjs`, or `.jsx` path. |
| Class declaration | `SymbolKind.class`; symbol name is the captured identifier. |
| Function declaration | `SymbolKind.function`; nested functions use bare names. |
| Direct class-body method | `SymbolKind.method`; method names are bare property identifiers. |
| Module-level uppercase simple binding | `SymbolKind.other`, because there is no constant-specific kind. |
| Other module-level simple binding | `SymbolKind.variable`. |
| CommonJS named export assignment | `SymbolKind.function`, `class`, `other`, or `variable` from the deterministic right-hand expression and exported property name. |

Ranges are one-based inclusive line ranges from the symbol definition node. The
module range is the Tree-sitter program node range. Ordering is deterministic
source order by symbol node start byte, with the module symbol first. When an
export or CommonJS pattern lacks a deterministic name, the proof skips it and
records a caveat instead of inventing a name.

## Supported and caveated subset

The proof-covered subset includes `.js`, `.mjs`, `.cjs`, admitted `.jsx`,
program/module roots, empty files, named functions, nested functions, named
classes, direct class-body methods, module-level constants and variables, ESM
exports, deterministic named CommonJS exports, anonymous export skips,
generated/minified caveats, invalid/partial files, unsupported TSX paths,
unsafe paths, and monorepo-style repo-relative paths.

The contract intentionally excludes runtime JavaScript `--symbols` output,
provider registration, custom user queries, TypeScript, TSX, Node execution,
package-manager resolution, workspace scanning, bundler analysis, module
resolution, dependency graphs, generated-source policy, parser diagnostics,
source snippets in failures, LSP data, lineage, ownership, people metrics,
scoring, and bug prediction.

Unsupported non-JavaScript paths, including `.ts` and `.tsx`, return
`unsupported` without parsing. Unsafe paths are rejected before parsing. Invalid
or partial JavaScript source returns `failed` with caveats only; raw parser
diagnostics and source snippets are not exposed. Generated-file markers and
minified one-line source are caveated only and do not change scoring or runtime
behavior.

## Fixture corpus

| Fixture | Coverage |
| --- | --- |
| `tests/fixtures/tree_sitter_javascript_query/supported_subset.mjs` | Monorepo-style `.mjs` path, ESM constant, variables, exported function, nested function, local class, method, method-local function, exported class, JSX-sensitive string, and ignored dynamic object key. |
| `tests/fixtures/tree_sitter_javascript_query/commonjs.cjs` | `.cjs` CommonJS local binding, deterministic `exports.<name>` function export, deterministic `module.exports.<name>` class export, class method, and uppercase exported constant. |
| `tests/fixtures/tree_sitter_javascript_query/jsx_component.jsx` | Admitted `.jsx` parse, exported function returning JSX, variable initialized with JSX, and explicit TSX unsupported caveat. |
| `tests/fixtures/tree_sitter_javascript_query/anonymous_exports.js` | Anonymous ESM default and anonymous `module.exports` assignment skipped without invented names. |
| `tests/fixtures/tree_sitter_javascript_query/generated.min.js` | Generated marker and minified one-line source with caveats only. |
| `tests/fixtures/tree_sitter_javascript_query/invalid_partial.js` | Invalid/partial JavaScript failure without diagnostics or snippets. |
| `tests/fixtures/tree_sitter_javascript_query/empty.js` | Empty program/module symbol only. |
| `tests/fixtures/tree_sitter_javascript_query/unsupported.tsx` | Unsupported TSX path that is not parsed. |

All fixture paths are project-relative. No private paths, raw private reports,
remote URLs, authors, email addresses, commit messages, or source from sibling
repositories are recorded.

## Validation evidence

Fresh local validation on 2026-05-25:

| Command | Exit status | Privacy-safe observation |
| --- | --- | --- |
| `zig build tree-sitter-javascript-query-proof` | `0` | Query compiled, expected capture names were present, and all local fixtures passed. |
| `zig build tree-sitter-javascript-build-proof` | `0` | Existing JavaScript and JSX parser/scanner build proof still compiled, linked, and ran. |
| `zig build validate` | `0` | Product validation passed without JavaScript runtime provider output. |
| `git diff --check` | `0` | No whitespace errors were reported. |

The proof uses only repository-local vendored Tree-sitter core and JavaScript
parser sources plus local fixtures. It performs no network access,
package-manager resolution, parser generation, telemetry, upload, remote
enrichment, background analysis, provider runtime registration, TypeScript/TSX
analysis, Node execution, package/workspace scanning, or module-resolution
analysis.
