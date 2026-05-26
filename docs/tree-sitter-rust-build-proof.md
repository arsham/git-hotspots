# Tree-sitter Rust offline build proof

This is the Feature 0072 evidence for a non-product Rust parser and scanner
build proof. It compiles only repository-local vendored Tree-sitter core sources
plus vendored `tree-sitter-rust` parser/scanner sources, parses tiny in-memory
Rust snippets, and does not add Rust runtime provider behaviour.

## Proof target

- Dedicated command: `zig build tree-sitter-rust-build-proof`.
- Build target kind: `build.zig` non-installed executable proof target.
- Proof source: `tests/tree_sitter_rust_build_proof.zig`.
- Vendored source revision: upstream tag `v0.24.2`, lightweight tag commit
  `77a3747266f4d621d0757825e6b11edcbf991ca5`.
- Vendored source path: `third_party/tree-sitter-rust/v0.24.2`.

The target is not added to `addTreeSitterProviders`, the product executable, the
provider registry, CLI/report/schema code, scoring, cache, fixtures, CI,
release, package, Cargo, crate graph, module analysis, macro expansion, type
checking, LSP, or runtime output paths.

## Local source inputs

Tree-sitter core input:

- `third_party/tree-sitter-core/v0.26.9/lib/include`
- `third_party/tree-sitter-core/v0.26.9/lib/src/lib.c`

Rust grammar input:

- Include path: `third_party/tree-sitter-rust/v0.24.2/src`
- Parser source: `third_party/tree-sitter-rust/v0.24.2/src/parser.c`
- Scanner source: `third_party/tree-sitter-rust/v0.24.2/src/scanner.c`
- Scanner helper headers:
  - `third_party/tree-sitter-rust/v0.24.2/src/tree_sitter/alloc.h`
  - `third_party/tree-sitter-rust/v0.24.2/src/tree_sitter/parser.h`

The Rust parser declares language version `15`, matching the existing vendored
Tree-sitter core range `13..15`. No Tree-sitter core update, parser generation,
Rust toolchain, Cargo, package manager, network access, telemetry, upload, or
remote enrichment is used.

The Rust parser declares external scanner entry points and
`EXTERNAL_TOKEN_COUNT 11`, so this proof compiles `src/scanner.c` beside
`src/parser.c` with the narrow local include path above. No scanner source is
regenerated, fetched, wrapped as C++, or supplied by a system package.

## Parse evidence

The proof creates a Tree-sitter parser, assigns `tree_sitter_rust()`, and parses
two in-memory Rust snippets:

- `fn proof() -> i32 { 1 }` parses with root `source_file`, no parse errors, one
  named child, and child kind `function_item`.
- A raw-string `const` item parses with root `source_file`, no parse errors, one
  named child, and child kind `const_item`, exercising the linked external
  scanner path.

These are compile/link and tiny parse smokes only. They do not expose Rust
runtime provider behaviour.

## Validation evidence

Before this packet, `build.zig` had no Rust build-proof target, and the Rust
source-import evidence recorded parser compilation as deferred. The pre-change
validation command sequence `git diff --check && zig build validate && zig build
test && zig build` passed locally.

Observed commands and outcomes for this packet:

| Command | Outcome | Notes |
| --- | --- | --- |
| `zig build tree-sitter-rust-build-proof` | PASS | Rust parser and scanner compiled and linked with the existing Tree-sitter core, then the tiny parse smokes passed. |
| `git diff --check` | PASS | No whitespace errors. |
| `zig build validate` | PASS | Default validation passed, including deterministic fixture checks, runtime dependency scan, source-install smoke, and real-repo smoke label `this-repo`. |
| `zig build test` | PASS | Unit and integration tests passed. |
| `zig build` | PASS | Product executable built with existing providers only. |
| No-provider output stability check | PASS | Basic table, JSON, Markdown, and inspect JSON outputs matched expected fixture outputs. |
| `zig build validate -Dcloseout=true -Dsmoke-repo=<operator-provided-local-repo> -Dsmoke-label=sibling-local-repo` | PASS | Close-out validation passed with labels `this-repo` and `sibling-local-repo`; raw private paths and reports were not printed. |

## Changed-path and protected-surface scan

Changed paths are limited to build-proof-only scope:

- `build.zig`
- `docs/tree-sitter-rust-build-proof.md`
- `tests/tree_sitter_rust_build_proof.zig`

Protected runtime/report scans over `src`, `fixtures`, `tools/validate.sh`,
`build.zig.zon`, `.github`, and provider runtime sources reported no changed
paths. No provider runtime source, CLI, report/schema, scoring, cache, query
fixture, line-history, Cargo/crate/module analysis, macro expansion, type
checking, LSP, CI, release, package, network, telemetry, upload, or remote
enrichment change is included.

## No-provider output stability

No Rust provider runtime output is added. The default `zig build validate` run
passed deterministic fixture JSON and Markdown checks, table/JSON/Markdown smoke
checks, inspect checks, privacy assertions, runtime dependency scan, and
real-repository smoke label `this-repo`. The close-out validation run also
passed table, JSON, and Markdown smoke checks for labels `this-repo` and
`sibling-local-repo` using bounded counts only.

## Non-runtime boundary

This proof is intentionally limited to offline compilation and tiny parse
smokes. It does not implement Rust symbol extraction, query contracts or
fixtures, inspect-only Rust output, provider registration, CLI flags,
report/schema changes, scoring, cache changes, Cargo/package/module or crate
analysis, macro expansion, type checking, LSP, CI, release, package changes,
network access, telemetry, upload, remote enrichment, or background Rust
analysis.
