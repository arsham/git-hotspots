# Tree-sitter Lua symbol extraction proof

This is the Feature 0068 evidence for a non-product Lua current-symbol
extraction proof. It maps the approved project-owned Lua query captures into the
existing `provider.CurrentSymbolEvidence` and `provider.ProviderEvidence`
shapes inside proof targets only.

## Scope and protected surfaces

Changed implementation surfaces are limited to:

- `tests/tree_sitter_lua_query_proof.zig`: shared proof extractor now carries
  provider evidence metadata and can be reused with a proof-target provider
  name.
- `tests/tree_sitter_lua_symbol_proof.zig`: dedicated Lua current-symbol
  extraction proof target.
- `build.zig`: explicit `tree-sitter-lua-symbol-proof` build step.
- `docs/tree-sitter-lua-symbol-extraction-proof.md`: this evidence record.

This proof does not add Lua runtime `--symbols` output, provider registration,
CLI flags, report/schema fields, scoring, cache behavior, fixture expected
product output, CI/release/package behavior, Lua package or `require` analysis,
module path resolution, custom user queries, parser generation, network access,
telemetry, upload, or remote enrichment.

## Proof target

| Field | Value |
| --- | --- |
| Command | `zig build tree-sitter-lua-symbol-proof` |
| Proof provider name | `tree-sitter-lua-symbol-proof` |
| Provider version | `tree-sitter-core@v0.26.9/tree-sitter-lua@v0.5.0/lua-symbol-query-v1` |
| Query input | `tests/fixtures/tree_sitter_lua_query/lua-symbols.scm` |
| Query fingerprint | `tests/fixtures/tree_sitter_lua_query/lua-symbols.scm:lua-symbol-query-v1` |
| Runtime provider status | Not registered; proof-only |

The target reuses the project-owned Lua query contract from
`docs/tree-sitter-lua-query-contract.md` and links only vendored Tree-sitter
core plus vendored `tree-sitter-lua` parser/scanner sources.

## Symbol evidence mapping

The proof maps accepted Lua query candidates into current-only symbol evidence:

| Lua query candidate | Symbol evidence mapping |
| --- | --- |
| Chunk root | `SymbolKind.module`; name is the repo-relative `.lua` path. |
| Bare or dotted function declaration | `SymbolKind.function`; name is the bare terminal identifier. |
| Colon-method declaration | `SymbolKind.method`; name is the bare method identifier. |
| Uppercase module local | `SymbolKind.other`, because the public model has no constant kind. |
| Other module local | `SymbolKind.variable`. |
| Stable local/global anonymous function assignment | `SymbolKind.function` when the left side is a single syntactic identifier. |
| Module-level table field with function value | `SymbolKind.function`. |
| Stable dot table assignment with function value | `SymbolKind.function` with the bare terminal field name. |
| Other module-level named table field | `SymbolKind.variable`, or `other` for constant-like uppercase names. |

Ranges are one-based inclusive line ranges from the current syntax node.
Ordering is deterministic source order by symbol node start byte, with the
module symbol first. Duplicate names are retained as separate current rows in
source order; no lineage, ownership, semantic move tracking, dependency graph,
source snippet, author, email, remote, or commit message field is added.

Provider evidence is local-only and current-only: `fresh/ok/high` for successful
proof extraction, `unknown/failed/low` for invalid or partial source, and
`unknown/unsupported/unknown` for unsupported paths. Unsupported non-`.lua`
paths are rejected before parsing. Unsafe paths fail closed through the shared
repo-relative path validator.

## Fixture and case coverage

The symbol proof target imports the Lua query proof fixture suite and adds
symbol-focused assertions for:

- provider name, provider version, contract version, query fingerprint,
  provenance, freshness, failure, and confidence metadata;
- symbol names, kinds, provider names, current-only line ranges, ordering, and
  absence of current-line history;
- duplicate Lua symbol names retained as deterministic separate current rows;
- empty files, invalid partial files, unsupported paths, unsafe paths, and
  parser failure caveats;
- dynamic bracket table assignments skipped with caveats;
- metatable-heavy Lua caveated with metamethod fields skipped;
- embedded DSL strings caveated without parsing string contents as Lua symbols;
- generated-file markers caveated only; and
- comments counted for proof coverage without exposing comment text.

## Validation evidence

Fresh local validation on 2026-05-26:

| Command | Exit status | Privacy-safe observation |
| --- | --- | --- |
| `zig build tree-sitter-lua-query-proof` | `0` | Existing query contract proof still passed with provider evidence metadata. |
| `zig build tree-sitter-lua-symbol-proof` | `0` | Dedicated symbol proof mapped Lua query captures into current symbol and provider evidence. |
| `zig build validate` | `0` | Product validation passed without Lua runtime provider output. |
| `zig build validate -Dcloseout -Dsmoke-label=sibling-local-repo -Dsmoke-repo=<local-path>` | `0` | Close-out smoke passed with privacy-safe sibling-local-repo label only. |
| Runtime help/provider scans | `0` | Help and runtime provider sources remained without Lua runtime `--symbols` claims or registration. |
| `git diff --check` | `0` | No whitespace errors were reported. |

No raw sibling output, private paths, repository names, remotes, authors,
emails, commit messages, or source snippets are recorded here.
