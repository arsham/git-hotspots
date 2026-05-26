# Lua query contract and fixtures

## Problem

A Lua parser build proof does not define which Lua constructs become current
symbols, how query captures map to provider evidence, or which fixtures prove
deterministic Lua semantics. Without a query contract, user-facing Lua symbols
would combine grammar, query design, extraction semantics, dynamic Lua caveats,
and output risk in one step.

## Outcome

A project-owned Lua symbol query contract and fixture corpus define the
supported subset, capture names, mapping, ranges, ordering, caveats, and
validation evidence. Lua runtime symbol output remains absent after this
feature.

## Requirements

### R1 Query contract scope

- Define built-in Lua symbol query captures for stable inspect-oriented syntax.
- Cover local functions, global functions, table-field functions, colon-method
  definitions, anonymous functions assigned to stable local/global/table names,
  and module-table patterns only when represented syntactically.
- Define symbol-kind mapping, range semantics, deterministic ordering, provider
  version metadata, query version metadata, and unsupported-case caveats.
- Keep query assets project-owned; do not blindly import upstream highlight
  queries.
- Do not add runtime provider output, provider registry entries, CLI flags,
  report schema fields, scoring changes, cache changes, custom user query
  execution, LuaRocks/package/module analysis, LSP, network, telemetry, upload,
  or remote enrichment.

### R2 Fixture coverage

Fixture coverage must include:

- `.lua` path examples;
- local function declarations;
- global function declarations;
- table-field function declarations;
- colon-method function declarations;
- anonymous functions assigned to stable local, global, or table-field names;
- module-like tables represented as syntax rather than runtime meaning;
- comments and strings that look like code and must not emit symbols;
- dynamic table assignment that should be caveated or skipped deterministically;
- metatable-heavy examples that should be caveated or skipped deterministically;
- generated Lua files;
- embedded DSL examples;
- empty files;
- invalid or partial files;
- unsupported paths and skipped-provider states; and
- monorepo-style project-relative paths.

### R3 Evidence document

Add a concise public evidence document, expected path:

```text
docs/tree-sitter-lua-query-contract.md
```

It must record query asset identities, query versions, proof target names,
supported subsets, capture names, range and ordering semantics, symbol-kind
mapping, fixture coverage, caveats, validation commands, local/offline proof
boundary, and explicit statement that Lua runtime `--symbols` output is not
implemented yet.

### R4 Existing behaviour preservation

Existing proof targets and product validation must continue to pass. No-provider
table, JSON, Markdown, inspect, and existing Zig, Go, Python, JavaScript,
TypeScript, and TSX symbol outputs must remain byte-stable unless a separate
feature explicitly changes them.

## Acceptance criteria

- A project-owned Lua query contract exists and is covered by deterministic
  fixture/proof targets.
- Supported syntax, skipped syntax, caveats, capture names, symbol kinds,
  ranges, ordering, provider/query versions, and fixture coverage are explicit.
- The evidence document exists at `docs/tree-sitter-lua-query-contract.md`.
- Lua runtime symbol output, provider registry wiring, custom user queries,
  package/module analysis, report schemas, scoring, cache, CI, network,
  telemetry, upload, and remote enrichment remain absent.
- Existing language provider outputs and no-provider outputs remain stable.

## Edge cases

- If a Lua construct cannot be named deterministically, skip or caveat it rather
  than inventing runtime meaning.
- If module-table patterns require `require`, package path, or runtime
  interpretation, keep them out of the supported subset.
- If symbol kinds require public schema expansion, stop for planning rather
  than expanding the schema locally.
- If fixtures expose Markdown-sensitive names or paths, human output evidence
  must prove escaping before runtime output is later added.
- If query proof needs generated files not imported by Feature 0065, stop and
  reshape instead of silently expanding the BOM.

## Verification

Close-out must include evidence for:

```sh
git diff --check
zig build validate
zig build tree-sitter-lua-build-proof
zig build tree-sitter-lua-query-proof
fixture coverage proof
unsupported and degraded case proof
changed-path scan for query-proof-only scope
no-runtime-output scan
no-provider output stability check
privacy-safe this-repo smoke
privacy-safe sibling-local-repo smoke or bounded no-safe-file finding
```
