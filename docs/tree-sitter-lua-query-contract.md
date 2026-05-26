# Tree-sitter Lua query contract and fixtures

This is a non-product, test-only contract for a future Lua Tree-sitter symbol
provider. It adds a project-owned query asset, fixture corpus, and proof target
without exposing Lua symbols through the CLI, reports, provider registry,
scoring, cache, or runtime defaults.

## Scope and protected surfaces

Changed implementation surfaces are limited to:

- `tests/fixtures/tree_sitter_lua_query/lua-symbols.scm`: the project-owned Lua
  symbol candidate query.
- `tests/fixtures/tree_sitter_lua_query/*.lua` and
  `tests/fixtures/tree_sitter_lua_query/unsupported.md`: local proof fixtures.
- `tests/tree_sitter_lua_query_proof.zig`: test-only query contract proof.
- `build.zig`: the explicit `tree-sitter-lua-query-proof` build step.
- `docs/tree-sitter-lua-query-contract.md`: this evidence record.

The contract does not change `src/`, fixture expected product outputs, CLI
flags, report schemas, scoring, cache behavior, provider registration, runtime
Lua symbol output, CI/release/package behavior, LSP behavior, package or
`require` analysis, network access, telemetry, uploads, remote enrichment,
parser generation, system package use, or custom user query execution.

## Query identity

| Field | Value |
| --- | --- |
| Query version | `lua-symbol-query-v1` |
| Provider proof name | `tree-sitter-lua-query-proof` |
| Grammar input | vendored `third_party/tree-sitter-lua/v0.5.0` |
| Query asset | `tests/fixtures/tree_sitter_lua_query/lua-symbols.scm` |
| Proof command | `zig build tree-sitter-lua-query-proof` |

The query is project-owned. It is not an upstream highlight, tags, or user query
import.

## Capture contract

The supported capture names are:

| Capture | Meaning |
| --- | --- |
| `@lua.module` | Lua chunk root candidate. |
| `@lua.function.definition` | Module-level function declaration node, including dotted table function declarations after proof-side filtering. |
| `@lua.method.definition` | Colon-method function declaration node after proof-side filtering. |
| `@lua.variable.definition` | Local declaration or stable global anonymous function assignment node after proof-side filtering. |
| `@lua.table.field.definition` | Named table constructor field or stable dot table assignment node after proof-side filtering. |
| `@lua.definition.name` | Identifier paired with a function, method, local declaration, stable assignment, or table field candidate. |
| `@lua.comment` | Comment node counted for proof coverage only; comment text is not exposed. |

Future runtime work must stop for planning if it needs new capture names,
custom user queries, `require` or package discovery, module path resolution,
metatable analysis, dependency graphs, LSP, or runtime provider registry wiring.

## Symbol-kind and range mapping

The proof maps query candidates into the existing
`provider.CurrentSymbolEvidence` shape only inside tests:

| Query candidate | Proof mapping |
| --- | --- |
| Chunk root | `SymbolKind.module`; symbol name is the repo-relative `.lua` path. |
| Function declaration | `SymbolKind.function`; qualified names use the bare terminal identifier. |
| Colon-method declaration | `SymbolKind.method`; method names are bare identifiers. |
| Module-level uppercase local declaration | `SymbolKind.other`, because there is no constant-specific kind. |
| Other module-level local declaration | `SymbolKind.variable`. |
| Stable local or global anonymous function assignment | `SymbolKind.function` when the left side is a single syntactic identifier. |
| Module-level table field with a function value | `SymbolKind.function`. |
| Stable dot table assignment with a function value | `SymbolKind.function` using the bare terminal field name. |
| Other module-level named table field | `SymbolKind.variable` or `other` for constant-like uppercase names. |

Ranges are one-based inclusive line ranges from the symbol definition node. The
module range is the Tree-sitter chunk node range. Ordering is deterministic
source order by symbol node start byte, with the module symbol first. Comments
are counted to prove coverage but are not emitted as symbols.

## Supported and caveated subset

The proof-covered subset includes `.lua` modules, empty chunks, local module
variables, constant-like uppercase locals, bare global functions, module-level
local functions, stable local and global anonymous function assignments, dotted
table functions, colon methods, module-level named table constructor fields,
stable dot table assignments with function values, table fields with function
values, comments, generated-file markers, dynamic table assignment skips,
metatable-heavy caveats, embedded DSL caveats, invalid/partial files,
unsupported paths, unsafe paths, monorepo-style paths, and Markdown-sensitive
fixture text.

The contract intentionally excludes runtime Lua `--symbols` output, provider
registration, custom user queries, package or `require` discovery, qualified
name construction, module path resolution, metatables, dependency graphs,
generated-source policy, parser diagnostics, source snippets in failures, LSP
data, lineage, ownership, people metrics, scoring, and bug prediction.

Unsupported non-`.lua` paths return `unsupported` without parsing. Unsafe paths
are rejected before parsing. Invalid or partial Lua source returns `failed` with
caveats only; raw parser diagnostics and source snippets are not exposed.
Generated-file markers are caveated only and do not change scoring or runtime
behavior. Dynamic bracket table assignments are skipped because runtime keys
are not deterministic symbols. Metatable-heavy source is caveated and
metamethod fields are skipped because runtime metatable behavior is outside the
query contract. Embedded DSL strings are caveated and their contents are not
parsed as Lua.

## Fixture corpus

| Fixture | Coverage |
| --- | --- |
| `tests/fixtures/tree_sitter_lua_query/supported_subset.lua` | Module comment, module locals, constant-like local, table variable, module-level table fields, table field function, skipped nested table field, local function, skipped nested local, dotted table function, colon method, and Markdown-sensitive string text. |
| `tests/fixtures/tree_sitter_lua_query/assignments.lua` | Bare global function, stable local anonymous function assignment, stable global anonymous function assignment, and monorepo-style repo-relative path proof. |
| `tests/fixtures/tree_sitter_lua_query/dynamic_table_assignment.lua` | Dynamic bracket table assignment skipped with caveat plus stable dot table assignment function proof. |
| `tests/fixtures/tree_sitter_lua_query/metatable_heavy.lua` | Metatable-heavy source caveat, skipped metamethod fields, setmetatable use counted as skipped runtime behavior, and retained colon-method syntax proof. |
| `tests/fixtures/tree_sitter_lua_query/embedded_dsl.lua` | Embedded SQL/template-like DSL strings caveated without parsing string contents as Lua symbols. |
| `tests/fixtures/tree_sitter_lua_query/generated.lua` | Generated marker comment, module-level constant, table local, and table field function with generated caveat. |
| `tests/fixtures/tree_sitter_lua_query/invalid_partial.lua` | Invalid/partial Lua failure without diagnostics or snippets. |
| `tests/fixtures/tree_sitter_lua_query/empty.lua` | Empty chunk symbol only. |
| `tests/fixtures/tree_sitter_lua_query/unsupported.md` | Unsupported path that contains Lua-looking Markdown but is not parsed. |

All fixture paths are project-relative. No private paths, raw private reports,
remote URLs, authors, email addresses, commit messages, or source from sibling
repositories are recorded.

## Validation evidence

Fresh local validation on 2026-05-26:

| Command | Exit status | Privacy-safe observation |
| --- | --- | --- |
| `zig build tree-sitter-lua-query-proof` | `0` | Query compiled, expected capture names were present, and all local fixtures passed. |
| `zig build tree-sitter-lua-build-proof` | `0` | Existing Lua parser/scanner build proof still compiled, linked, and ran. |
| `zig build validate` | `0` | Product validation passed without Lua runtime provider output. |
| `zig build validate -Dcloseout -Dsmoke-label=sibling-local-repo -Dsmoke-repo=<local-path>` | `0` | Privacy-safe sibling-local-repo smoke passed with labels and bounded counts only. |
| Fixture coverage proof | `0` | Test source and docs enumerate supported, degraded, unsupported, dynamic, metatable, embedded DSL, and monorepo-style Lua fixtures. |
| Query-proof-only and no-runtime-output scans | `0` | Changed paths stayed in proof/docs/build surfaces and runtime provider/help output remained without Lua provider claims. |
| `git diff --check` | `0` | No whitespace errors were reported. |

The proof uses only repository-local vendored Tree-sitter core and Lua parser
sources plus local fixtures. It performs no network access, package-manager
resolution, parser generation, telemetry, upload, remote enrichment, background
analysis, provider runtime registration, Lua package discovery, or module-path
analysis.
