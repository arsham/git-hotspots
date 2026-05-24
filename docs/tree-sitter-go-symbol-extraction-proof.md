# Tree-sitter Go symbol extraction proof

This is an internal, non-product proof. It does not add runtime Go `--symbols`
output, a Go provider registry entry, CLI flags, report schema fields, scoring,
cache behaviour, telemetry, network access, or parser generation.

## Proof target

- Target: `zig build tree-sitter-go-symbol-proof`
- Source: `tests/tree_sitter_go_symbol_proof.zig`
- Parser inputs: vendored `third_party/tree-sitter-core/v0.26.9/lib/src/lib.c`
  and `third_party/tree-sitter-go/v0.25.0/src/parser.c` only
- CI: the target is included after the existing Tree-sitter Go build proof and
  remains local after checkout and Zig setup.

## Supported subset

The proof maps these Go AST cases into the existing
`provider.CurrentSymbolEvidence` shape:

- package clauses as `SymbolKind.module`
- top-level function declarations as `SymbolKind.function`
- method declarations as `SymbolKind.method`
- top-level struct and interface type specs as `SymbolKind.type`
- top-level variable names as `SymbolKind.variable`
- top-level constant names as `SymbolKind.other`

The proof is intentionally bounded. It does not evaluate Go packages, modules,
build tags, cgo, generated-file markers, dependency graphs, LSP data, symbol
history, or receiver-qualified method naming. Method names are bare identifiers
with that caveat recorded in symbol evidence.

## Traversal, ranges, and ordering

The proof uses direct Tree-sitter AST traversal through named children. It does
not add Tree-sitter query files or custom query execution.

Ranges are deterministic one-based inclusive line ranges from the enclosing Go
declaration node. Grouped const and var names share the enclosing declaration
range. Struct and interface type specs use the enclosing type declaration range.

Symbol order is deterministic source order from Tree-sitter named-child
traversal. The proof does not sort symbols by name.

## Mapping caveats

The provider model has no struct-specific, interface-specific, or
constant-specific symbol kind. The proof maps structs and interfaces to
`SymbolKind.type`, maps constants to `SymbolKind.other`, and records caveats on
those symbols.

Unsupported non-Go paths return provider `unsupported` failure. Unsafe paths are
rejected before parsing. Empty Go source returns no symbols without failure.
Invalid Go source returns provider `failed` with caveats only; raw parser
diagnostics and source snippets are not exposed.

## Validation evidence

Fresh local validation on 2026-05-24:

| Command | Exit status |
| --- | --- |
| `zig fmt --check build.zig src tests` | pass |
| `zig build test` | pass |
| `zig build` | pass |
| `zig build validate` | pass |
| `zig build tree-sitter-build-proof` | pass |
| `zig build tree-sitter-symbol-proof` | pass |
| `zig build tree-sitter-go-build-proof` | pass |
| `zig build tree-sitter-go-symbol-proof` | pass |
| `git diff --check` | pass |
| changed-path scan | pass |
| prohibited dependency scan | pass |
| privacy/prohibited-claim scan | pass |
| close-out smoke labelled `sibling-local-repo` | pass |

The close-out smoke used a local sibling repository supplied at execution time.
Only the privacy-safe label `sibling-local-repo` is durable evidence; no private
path, raw report, remote URL, author, email, commit message, source snippet, or
private repository identifier is recorded here.
