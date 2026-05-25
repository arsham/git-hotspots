# Tree-sitter JavaScript symbol extraction proof

This is an internal, non-product proof. It does not add runtime JavaScript
`--symbols` output, a JavaScript provider registry entry, CLI flags, report
schema fields, scoring, cache behaviour, telemetry, network access, parser
generation, package-manager resolution, Node analysis, TypeScript/TSX support,
or workspace/module analysis.

## Proof target

- Target: `zig build tree-sitter-javascript-symbol-proof`
- Source: `tests/tree_sitter_javascript_symbol_proof.zig`, which imports the
  query-backed fixture suite in `tests/tree_sitter_javascript_query_proof.zig`
- Query contract: `docs/tree-sitter-javascript-query-contract.md`
- Query asset:
  `tests/fixtures/tree_sitter_javascript_query/javascript-symbols.scm`
- Parser inputs: vendored `third_party/tree-sitter-core/v0.26.9/lib/src/lib.c`,
  `third_party/tree-sitter-javascript/v0.25.0/src/parser.c`, and
  `third_party/tree-sitter-javascript/v0.25.0/src/scanner.c` only
- CI: the target is included after the existing Tree-sitter JavaScript build
  proof and remains local after checkout and Zig setup.

## Supported subset

The proof maps the project-owned JavaScript query captures into the existing
`provider.CurrentSymbolEvidence` shape:

- program roots as `SymbolKind.module`, named by the repo-relative `.js`,
  `.mjs`, `.cjs`, or admitted `.jsx` path
- class declarations as `SymbolKind.class`
- function declarations as `SymbolKind.function`
- direct class-body methods as `SymbolKind.method`
- module-level uppercase simple bindings as `SymbolKind.other`
- other module-level simple bindings as `SymbolKind.variable`
- deterministic named `exports.<name>` or `module.exports.<name>` assignments
  as the kind derived from the right-hand expression, or `SymbolKind.other` for
  constant-like names without a more specific public kind

The proof-covered subset includes empty files, named functions, nested
functions, named classes, direct class-body methods, module-level constants and
variables, ESM exports, deterministic named CommonJS exports, anonymous export
skips, generated/minified caveats, invalid or partial JavaScript files,
unsupported TypeScript and TSX paths, unsafe paths, monorepo-style
repo-relative paths, and admitted `.jsx` parsing.

## Ranges, ordering, and caveats

Ranges are deterministic one-based inclusive line ranges from the symbol
definition node. Module ranges come from the Tree-sitter `program` node.

Symbol order is deterministic source order by symbol-node start byte, with the
module symbol first. The proof records caveats for bare method names,
constant-like bindings mapping to `SymbolKind.other`, module-level variable
bindings, deterministic CommonJS limits, admitted `.jsx`, generated/minified
source, anonymous export skips, local-only fixture scope, and
`provider.CurrentSymbolEvidence` `current-only` semantics.

Unsupported non-JavaScript paths, including `.ts` and `.tsx`, return provider
`unsupported` without parsing. Unsafe paths are rejected before parsing. Invalid
or partial JavaScript source returns provider `failed` with caveats only; raw
parser diagnostics and source snippets are not exposed. If an export or
CommonJS pattern lacks a deterministic name, the proof skips it and records a
caveat instead of inventing one.

## Deferred runtime boundary

JavaScript runtime `--symbols` output is not implemented yet. This proof adds
no provider registry wiring, CLI/report/schema/scoring/cache changes,
line-history integration, custom query execution, TypeScript/TSX support,
package.json, workspace, bundler, dependency graph, Node/module-resolution or
LSP analysis, repo-wide scanning, snippets, author data, ownership metrics,
quality scoring, or bug prediction.

## Validation ladder and byte-stability evidence

Fresh local validation on 2026-05-25 covered the close-out ladder:

- V2 atomic commit: format, unit/integration, build, JavaScript proof targets,
  existing proof targets, and whitespace checks passed before the evidence
  repair commit.
- V3 final packet: the full proof target sweep and product validation passed
  with the JavaScript proof target present.
- V4 close-out: `zig build validate -Dcloseout=true` passed with a
  privacy-safe local sibling smoke labelled `sibling-local-repo`; the raw
  sibling path and raw reports are not recorded.

| Command | Exit status | Privacy-safe observation |
| --- | --- | --- |
| `zig fmt --check build.zig src tests` | `0` | Zig sources and tests were formatted. |
| `zig build test` | `0` | Unit and integration tests passed. |
| `zig build` | `0` | The executable built successfully. |
| `zig build validate` | `0` | Product validation passed without JavaScript runtime provider output. |
| `zig build tree-sitter-build-proof` | `0` | Existing Zig parser build proof still compiled, linked, and ran. |
| `zig build tree-sitter-symbol-proof` | `0` | Existing Zig symbol proof still passed. |
| `zig build tree-sitter-go-build-proof` | `0` | Existing Go parser build proof still compiled, linked, and ran. |
| `zig build tree-sitter-go-symbol-proof` | `0` | Existing Go symbol proof still passed. |
| `zig build tree-sitter-python-build-proof` | `0` | Existing Python parser/scanner build proof still compiled, linked, and ran. |
| `zig build tree-sitter-python-symbol-proof` | `0` | Existing Python symbol proof still passed. |
| `zig build tree-sitter-javascript-build-proof` | `0` | Existing JavaScript parser/scanner build proof still compiled, linked, and ran. |
| `zig build tree-sitter-javascript-query-proof` | `0` | Project-owned JavaScript query contract fixtures still passed. |
| `zig build tree-sitter-javascript-symbol-proof` | `0` | Query-backed JavaScript symbol extraction fixtures mapped into current symbol evidence. |
| `git diff --check` | `0` | No whitespace errors were reported. |
| `zig build validate -Dcloseout=true -Dsmoke-repo=<privacy-safe local sibling> -Dsmoke-label=sibling-local-repo` | `0` | Close-out validation passed for this repo and sibling label without committing private paths or reports. |

Explicit byte-stability checks also passed with generated outputs compared to
committed fixtures or byte-identical repeats:

| Surface | Check | Exit status |
| --- | --- | --- |
| No-provider JSON | `fixtures/basic` JSON diffed against `fixtures/expected/basic.json` | `0` |
| No-provider Markdown | `fixtures/basic` Markdown diffed against `fixtures/expected/basic.md` | `0` |
| No-provider table | Two fresh `fixtures/basic` table renders were byte-identical | `0` |
| Inspect JSON/Markdown/table | `fixtures/basic --inspect src/app.txt` diffed against committed inspect fixtures | `0` |
| Zig symbols JSON/Markdown/table | `fixtures/symbols --inspect src/example.zig --symbols` diffed against committed Zig symbol fixtures | `0` |
| Go symbols JSON/Markdown/table | `fixtures/go-symbols --inspect src/example.go --symbols` diffed against committed Go symbol fixtures | `0` |
| Python symbols JSON/Markdown/table | `fixtures/python-symbols --inspect src/example.py --symbols` diffed against committed Python symbol fixtures | `0` |

The proof uses only repository-local vendored Tree-sitter core and JavaScript
parser sources plus local fixtures. It performs no network access,
package-manager resolution, parser generation, telemetry, upload, remote
enrichment, background analysis, runtime provider registration, TypeScript/TSX
analysis, Node execution, package/workspace scanning, module-resolution
analysis, CI release automation, cache use, or artifacts.
