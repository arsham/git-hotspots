# Tree-sitter Lua offline build proof

This is the Feature 0066 evidence for a non-product Lua parser and scanner
build proof. It compiles only repository-local vendored Tree-sitter core
sources plus vendored `tree-sitter-lua` parser/scanner sources, parses tiny
in-memory Lua snippets, and does not add Lua runtime provider behaviour.

## Proof target

- Dedicated command: `zig build tree-sitter-lua-build-proof`.
- Build target kind: `build.zig` non-installed executable proof target.
- Proof source: `tests/tree_sitter_lua_build_proof.zig`.
- Vendored source revision: upstream tag `v0.5.0`, lightweight tag commit
  `10fe0054734eec83049514ea2e718b2a56acd0c9`.
- Vendored source path: `third_party/tree-sitter-lua/v0.5.0`.

The target is not added to `addTreeSitterProviders`, the product executable,
the provider registry, CLI/report/schema code, scoring, cache, fixtures, CI,
release, package, or runtime output paths.

## Local source inputs

Tree-sitter core input:

- `third_party/tree-sitter-core/v0.26.9/lib/include`
- `third_party/tree-sitter-core/v0.26.9/lib/src/lib.c`

Lua grammar input:

- Include path: `third_party/tree-sitter-lua/v0.5.0/src`
- Parser source: `third_party/tree-sitter-lua/v0.5.0/src/parser.c`
- Scanner source: `third_party/tree-sitter-lua/v0.5.0/src/scanner.c`
- Scanner helper headers:
  - `third_party/tree-sitter-lua/v0.5.0/src/tree_sitter/alloc.h`
  - `third_party/tree-sitter-lua/v0.5.0/src/tree_sitter/parser.h`

The Lua parser declares language version `15`, matching the existing vendored
Tree-sitter core range `13..15`. No Tree-sitter core update, parser
generation, Lua, LuaRocks, package manager, network access, telemetry, upload,
or remote enrichment is used.

The Lua parser declares external scanner entry points and
`EXTERNAL_TOKEN_COUNT 6`, so this proof compiles `src/scanner.c` beside
`src/parser.c` with the narrow local include path above. No scanner source is
regenerated, fetched, or supplied by a system package.

## Parse evidence

The proof creates a Tree-sitter parser, assigns `tree_sitter_lua()`, and parses
two in-memory Lua snippets:

- `function proof() return 1 end` parses with root `chunk`, no parse errors,
  one named child, and child kind `function_declaration`.
- A block-comment and long-bracket-string snippet parses with root `chunk` and
  no parse errors, exercising the linked external scanner path.

These are compile/link and tiny parse smokes only. They do not expose Lua
runtime provider behaviour.

## Validation evidence

Observed commands and outcomes for this packet:

| Command | Outcome | Notes |
| --- | --- | --- |
| `zig build tree-sitter-lua-build-proof` | PASS | Lua parser and scanner compiled and linked with the existing Tree-sitter core, then the tiny parse smokes passed. |
| `git diff --check` | PASS | No whitespace errors. |
| `zig build validate` | PASS | Default validation passed, including deterministic fixture checks, runtime dependency scan, source-install smoke, and real-repo smoke label `this-repo`. |
| `zig build test` | PASS | Unit and integration tests passed. |
| `zig build` | PASS | Product executable built with existing providers only. |
| `zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo` | PASS | Close-out validation passed with labels `this-repo` and `sibling-local-repo`; raw private paths and reports were not printed. |

## Changed-path and protected-surface scan

Changed paths are limited to build-proof-only scope:

- `build.zig`
- `docs/tree-sitter-lua-build-proof.md`
- `tests/tree_sitter_lua_build_proof.zig`

Protected runtime/report scans over `src`, `fixtures`, `tools/validate.sh`,
`build.zig.zon`, `.github`, and provider runtime sources reported no changed
paths. No provider runtime source, CLI, report/schema, scoring, cache, query
fixture, line-history, LuaRocks/package/module analysis, LSP, CI, release,
package, network, telemetry, upload, or remote enrichment change is included.

## No-provider output stability

No Lua provider runtime output is added. The default `zig build validate` run
passed deterministic fixture JSON and Markdown checks, table/JSON/Markdown
smoke checks, inspect checks, privacy assertions, runtime dependency scan, and
real-repository smoke label `this-repo`. The close-out validation run also
passed table, JSON, and Markdown smoke checks for labels `this-repo` and
`sibling-local-repo` using bounded counts only.

## Non-runtime boundary

This proof is intentionally limited to offline compilation and tiny parse
smokes. It does not implement Lua symbol extraction, query contracts or
fixtures, inspect-only Lua output, provider registration, CLI flags,
report/schema changes, scoring, cache changes, LuaRocks/package/module or
package-path analysis, parser generation, LSP, CI, release, package changes,
network access, telemetry, upload, remote enrichment, or background Lua
analysis.
