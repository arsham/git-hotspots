# Tree-sitter TypeScript/TSX offline build proof evidence

This is the Feature 0057 evidence for non-product TypeScript and TSX parser
build proofs. The proof compiles only repository-local vendored Tree-sitter core
sources plus vendored `tree-sitter-typescript` TypeScript or TSX parser/scanner
sources, parses tiny in-memory snippets, and does not add TypeScript or TSX
runtime provider behaviour.

## Proof targets

- TypeScript command: `zig build tree-sitter-typescript-build-proof`.
- TSX command: `zig build tree-sitter-tsx-build-proof`.
- Zig version observed during proof: `0.16.0`.
- Git version observed during proof: `git version 2.54.0`.
- Build target kind: `build.zig` non-installed executable proof targets.
- TypeScript proof source: `tests/tree_sitter_typescript_build_proof.zig`.
- TSX proof source: `tests/tree_sitter_tsx_build_proof.zig`.

The targets are not added to `addTreeSitterProviders`, the product executable,
the provider registry, CLI/report/schema code, scoring, cache, fixtures, CI, or
runtime output paths.

## Local source inputs

Tree-sitter core input:

- `third_party/tree-sitter-core/v0.26.9/lib/include`
- `third_party/tree-sitter-core/v0.26.9/lib/src/lib.c`

TypeScript grammar input:

- Include path: `third_party/tree-sitter-typescript/v0.23.2/typescript/src`
- Parser source:
  `third_party/tree-sitter-typescript/v0.23.2/typescript/src/parser.c`
- Scanner wrapper:
  `third_party/tree-sitter-typescript/v0.23.2/typescript/src/scanner.c`
- Scanner helper header:
  `third_party/tree-sitter-typescript/v0.23.2/typescript/src/tree_sitter/parser.h`
- Shared scanner source included by the wrapper:
  `third_party/tree-sitter-typescript/v0.23.2/common/scanner.h`

TSX grammar input:

- Include path: `third_party/tree-sitter-typescript/v0.23.2/tsx/src`
- Parser source:
  `third_party/tree-sitter-typescript/v0.23.2/tsx/src/parser.c`
- Scanner wrapper:
  `third_party/tree-sitter-typescript/v0.23.2/tsx/src/scanner.c`
- Scanner helper header:
  `third_party/tree-sitter-typescript/v0.23.2/tsx/src/tree_sitter/parser.h`
- Shared scanner source included by the wrapper:
  `third_party/tree-sitter-typescript/v0.23.2/common/scanner.h`

The vendored source revision is upstream tag `v0.23.2`, commit
`f975a621f4e7f532fe322e13c4f79495e0a7b2e7`, imported under
`third_party/tree-sitter-typescript/v0.23.2`.

Observed vendored source sizes:

| File | Bytes |
| --- | ---: |
| `third_party/tree-sitter-typescript/v0.23.2/typescript/src/parser.c` | 8745894 |
| `third_party/tree-sitter-typescript/v0.23.2/typescript/src/scanner.c` | 573 |
| `third_party/tree-sitter-typescript/v0.23.2/typescript/src/tree_sitter/parser.h` | 7039 |
| `third_party/tree-sitter-typescript/v0.23.2/tsx/src/parser.c` | 8769870 |
| `third_party/tree-sitter-typescript/v0.23.2/tsx/src/scanner.c` | 538 |
| `third_party/tree-sitter-typescript/v0.23.2/tsx/src/tree_sitter/parser.h` | 7039 |
| `third_party/tree-sitter-typescript/v0.23.2/common/scanner.h` | 10097 |

Both proofs use empty C compiler flag lists, the existing vendored Tree-sitter
core, and grammar-specific wrapper files. No parser generation, Node tooling,
package manager, network access, remote enrichment, telemetry, upload, or
Tree-sitter core update is used.

## Parse evidence

The TypeScript proof creates a Tree-sitter parser, assigns
`tree_sitter_typescript()`, parses
`function proof(value: number): number { return value; }`, and asserts root
`program`, no parse errors, one named child, and child kind
`function_declaration`.

The TSX proof creates a Tree-sitter parser, assigns `tree_sitter_tsx()`, parses
`const View = () => <main id="proof">ok</main>;`, and asserts root `program`,
no parse errors, one named child, and child kind `lexical_declaration`.

These are compile/link and tiny parse smokes only. They do not expose
TypeScript or TSX runtime provider behaviour.

## Validation evidence

Before this packet, `build.zig` had no TypeScript or TSX build-proof targets,
and the TypeScript source-import evidence recorded parser compilation as
deferred. After this packet, the following commands were run locally:

| Command | Outcome | Notes |
| --- | --- | --- |
| `git diff --check` | PASS | No whitespace errors. |
| `zig build validate` | PASS | Default validation passed format, tests, build, deterministic fixture JSON/Markdown, JSON validity, privacy assertions, runtime dependency scan, source-install smoke, and real-repo smoke label `this-repo`. |
| `zig build test` | PASS | Unit and integration tests passed. |
| `zig build` | PASS | Product executable built with existing providers only. |
| `zig build tree-sitter-typescript-build-proof` | PASS | TypeScript parser/scanner compiled and linked with existing Tree-sitter core and the tiny TypeScript parse smoke passed. |
| `zig build tree-sitter-tsx-build-proof` | PASS | TSX parser/scanner compiled and linked with existing Tree-sitter core and the tiny TSX parse smoke passed. |
| `zig build validate -Dcloseout=true -Dsmoke-repo=<operator-provided-local-repo> -Dsmoke-label=sibling-local-repo` | PASS | Close-out validation passed with labels `this-repo` and `sibling-local-repo`; raw private paths and reports were not printed. |

Close-out smoke evidence was privacy-safe. The sibling-local-repo candidate was
selected only after finding a TypeScript or TSX file in a local sibling
repository; committed evidence keeps only the label, command shape, pass/fail
status, bounded counts, and categorical observations.

## Changed-path and protected-surface scan

Changed paths are limited to build-proof-only scope:

- `build.zig`
- `docs/tree-sitter-typescript-build-proof-evidence.md`
- `tests/tree_sitter_typescript_build_proof.zig`
- `tests/tree_sitter_tsx_build_proof.zig`

A protected runtime/report scan over `src`, `fixtures`, `tools/validate.sh`,
`build.zig.zon`, `.github`, and provider runtime sources reported no changed
paths. No provider runtime source, CLI, report/schema, scoring, cache, query
fixture, line-history, Node/package/workspace/module/tsconfig, LSP, CI, release,
network, telemetry, upload, or remote enrichment change is included.

## No-provider output stability

No TypeScript or TSX provider runtime output is added. The default
`zig build validate` run passed deterministic fixture JSON and Markdown checks,
table/JSON/Markdown smoke checks, inspect checks, privacy assertions, runtime
dependency scan, and real-repository smoke label `this-repo`. The close-out
validation run also passed table, JSON, and Markdown smoke checks for labels
`this-repo` and `sibling-local-repo` using bounded counts only.

## Non-runtime boundary

This proof is intentionally limited to offline compilation and tiny parse
smokes. It does not implement TypeScript or TSX symbol extraction, query
contracts or fixtures, inspect-only TypeScript/TSX output, provider
registration, CLI flags, report/schema changes, scoring, cache changes,
package/workspace/module or `tsconfig` analysis, parser generation, LSP, CI,
release, network access, telemetry, upload, remote enrichment, or background
TypeScript/TSX analysis.
