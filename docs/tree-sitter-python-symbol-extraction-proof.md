# Tree-sitter Python symbol extraction proof

This is an internal, non-product proof. It does not add runtime Python
`--symbols` output, a Python provider registry entry, CLI flags, report schema
fields, scoring, cache behaviour, telemetry, network access, parser generation,
or package-manager analysis.

## Proof target

- Target: `zig build tree-sitter-python-symbol-proof`
- Source: `tests/tree_sitter_python_symbol_proof.zig`, which imports
  `tests/tree_sitter_python_query_proof.zig`
- Query contract: `docs/tree-sitter-python-query-contract.md`
- Query asset: `tests/fixtures/tree_sitter_python_query/python-symbols.scm`
- Parser inputs: vendored `third_party/tree-sitter-core/v0.26.9/lib/src/lib.c`,
  `third_party/tree-sitter-python/v0.25.0/src/parser.c`, and
  `third_party/tree-sitter-python/v0.25.0/src/scanner.c` only
- CI: the target is included after the existing Tree-sitter Python build proof
  and remains local after checkout and Zig setup.

## Supported subset

The proof maps the project-owned Python query captures into the existing
`provider.CurrentSymbolEvidence` shape:

- module roots as `SymbolKind.module`, named by the repo-relative `.py` path
- class definitions as `SymbolKind.class`
- function definitions in a direct class body as `SymbolKind.method`
- other function definitions as `SymbolKind.function`
- module-level uppercase simple assignments as `SymbolKind.other`
- other module-level simple assignments as `SymbolKind.variable`

The proof-covered subset includes empty modules, top-level and nested classes,
top-level and nested functions, direct class-body methods, decorators,
module-level simple assignments, constant-like assignments, Unicode identifiers,
generated-file markers, invalid or partial files, unsupported non-Python paths,
and Markdown-sensitive fixture text.

## Ranges, ordering, and caveats

Ranges are deterministic one-based inclusive line ranges. Class and function
ranges come from the symbol definition node; decorated class and function ranges
use the enclosing `decorated_definition` so decorators are included. Module
ranges come from the Tree-sitter module node.

Symbol order is deterministic source order by symbol-node start byte, with the
module symbol first. The proof records caveats for bare nested names, bare
method names, constant-like assignments mapping to `SymbolKind.other`, generated
markers, local-only fixture scope, and `provider.CurrentSymbolEvidence`
`current-only` semantics.

Unsupported non-`.py` paths return provider `unsupported` without parsing.
Unsafe paths are rejected before parsing. Invalid or partial Python source
returns provider `failed` with caveats only; raw parser diagnostics and source
snippets are not exposed.

## Deferred runtime boundary

Python runtime `--symbols` output is not implemented yet. This proof adds no
provider registry wiring, CLI/report/schema/scoring/cache changes, line-history
integration, custom query execution, package/import/virtualenv/notebook/LSP
analysis, repo-wide scanning, snippets, author data, ownership metrics, quality
scoring, or bug prediction.

## Validation evidence

Fresh local validation on 2026-05-24:

| Command | Exit status | Privacy-safe observation |
| --- | --- | --- |
| `zig build validate` | `0` | Product validation passed without Python runtime provider output. |
| `zig build tree-sitter-python-build-proof` | `0` | Existing Python parser/scanner build proof compiled, linked, and ran. |
| `zig build tree-sitter-python-symbol-proof` | `0` | Query-backed Python symbol extraction fixtures mapped into current symbol evidence. |
| `zig build tree-sitter-build-proof` | `0` | Existing Zig parser proof still compiled, linked, and ran. |
| `zig build tree-sitter-symbol-proof` | `0` | Existing Zig symbol proof still passed. |
| `zig build tree-sitter-go-build-proof` | `0` | Existing Go parser proof still compiled, linked, and ran. |
| `zig build tree-sitter-go-symbol-proof` | `0` | Existing Go symbol proof still passed. |
| `git diff --check` | `0` | No whitespace errors were reported. |

The proof uses only repository-local vendored Tree-sitter core and Python parser
sources plus local fixtures. It performs no network access, package-manager
resolution, parser generation, telemetry, upload, remote enrichment, background
analysis, or provider runtime registration.
