# Feature 0038: Tree-sitter Go symbol extraction proof

## Summary

Add an internal, non-product proof that the vendored Tree-sitter Go parser can
extract current Go symbols into the existing provider symbol evidence shape.

This feature proves Go symbol semantics only. It does not expose Go symbols in
CLI output, add a provider registry entry, change report schemas, change
scoring, or alter no-provider behaviour.

## Problem

Feature 0036 imported pinned `tree-sitter-go` sources and Feature 0037 proved
that the parser compiles, links, and parses a tiny Go snippet with the existing
vendored Tree-sitter core. The next risk is symbol semantics: which Go nodes we
extract, how we map them into the existing provider model, how ranges and order
are made deterministic, and how unsupported or degraded cases are caveated.

Without an internal extraction proof, user-facing Go `--symbols` output would
combine extraction semantics, CLI/report UX, and validation risk in one step.

## Goals

- Add a dedicated internal proof target, expected as:

```sh
zig build tree-sitter-go-symbol-proof
```

- Use vendored local Tree-sitter core and tree-sitter-go parser sources only.
- Extract a bounded current-symbol subset from in-memory Go source.
- Map extracted symbols to `provider.CurrentSymbolEvidence` or a directly
  compatible internal shape.
- Prove deterministic range semantics and deterministic ordering.
- Prove failure, unsupported, empty, invalid, generated-file, build-tag, and
  cgo-adjacent caveat behaviour without raw diagnostics or source snippets.
- Preserve no-provider output stability and existing Zig symbol behaviour.
- Record privacy-safe evidence and the explicit boundary that Go runtime symbol
  output is not implemented yet.

## Non-goals

- No user-facing Go `--symbols` output.
- No CLI flag changes.
- No report schema, fixture output, scoring, ranking, lineage, cache, or CI
  release changes.
- No Go provider registry entry.
- No Go package-manager, module, build-tag evaluation, cgo analysis, repo-wide
  scanning, LSP, custom query execution, or dependency graph analysis.
- No `git log -L`, Go symbol history, symbol lineage, source snippets, raw
  parser diagnostics, authors, emails, commit messages, ownership metrics, bug
  prediction, quality scoring, or developer ranking.
- No parser generation, network fetches, package-manager resolution, submodules,
  global Tree-sitter CLI, system parser packages, or `build.zig.zon`.

## Requirements

### R1 - Dedicated Go symbol proof target

The implementation must add a dedicated internal proof target, expected as:

```sh
zig build tree-sitter-go-symbol-proof
```

The proof target must be separate from product runtime. It may compile and link
vendored Tree-sitter core and tree-sitter-go sources for proof execution, but it
must not install or wire Go provider behaviour into the CLI.

### R2 - Direct AST traversal first

The first proof must use direct Tree-sitter AST traversal, not Tree-sitter query
files, as the Go extraction mechanism. This is a deliberate proof boundary: it
validates Go symbol semantics before introducing query versioning and capture
contracts.

If direct traversal cannot provide deterministic ranges or names for the bounded
subset, execution must stop for shaping instead of switching to a broader query
framework by local decision.

### R3 - Bounded Go symbol subset

The proof should extract these current working-tree symbol classes from
in-memory Go source when present:

- `package_clause` as a `module` symbol;
- top-level `function_declaration` as `function`;
- `method_declaration` as `method`;
- `type_spec` with `struct_type` as `type` with a struct caveat;
- `type_spec` with `interface_type` as `type` with an interface caveat;
- top-level `const_spec` names as `variable` with a constant caveat;
- top-level `var_spec` names as `variable`.

The proof must not extract struct fields, interface methods, local variables,
short declarations, imports, type aliases, generic constraints, or arbitrary
named types unless it explicitly emits a caveat that they are unsupported by the
first proof.

### R4 - Range semantics

Each symbol must use one-based inclusive line ranges from the enclosing
Go declaration node used for extraction:

- package clause;
- function declaration;
- method declaration;
- type spec;
- const spec;
- var spec.

For grouped `const` or `var` specs with multiple names, emit one symbol per name
sharing the same spec range. Ranges must be deterministic for repeated runs on
the same input.

### R5 - Ordering semantics

The proof must establish deterministic source order:

1. start byte ascending;
2. end byte ascending;
3. kind rank;
4. bytewise symbol name.

Do not rely only on alphabetical provider ordering for this proof. If final
storage uses the existing provider ordering helper, the proof must still show how
Go source order is derived or document the intentional ordering boundary.

### R6 - Existing provider shape and caveats

The proof must use `provider.CurrentSymbolEvidence` or a directly compatible
internal shape. The current `SymbolKind` enum has no dedicated `struct`,
`interface`, or `constant` variants, so the proof must map conservatively:

- package -> `module`;
- function -> `function`;
- method -> `method`;
- struct and interface -> `type` with caveats;
- const and var -> `variable` with caveats when needed.

Caveats must include current-only semantics and avoid implying Go type checking,
module loading, build-tag evaluation, cgo handling, custom queries, or runtime
Go provider support.

### R7 - Degraded and unsupported cases

The proof must cover and caveat:

- empty Go source;
- invalid or partial Go source;
- unsupported non-Go path;
- unsafe repo-relative path rejection before parsing;
- generated-file caveat or deterministic skip behaviour;
- build-tag caveat or deterministic handling;
- cgo-adjacent caveat or deterministic handling;
- unicode and Markdown-sensitive symbol names where the parser accepts them.

Failure paths must not expose raw parser diagnostics, absolute paths, source
snippets, remotes, author identities, private repo names, or raw private output.

### R8 - Existing behaviour preservation

Existing proof targets and product validation must continue to pass:

```sh
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
zig build tree-sitter-go-build-proof
zig build validate
```

No-provider table, JSON, Markdown, inspect, and existing Zig `--symbols` outputs
must remain byte-stable unless a separate feature explicitly changes them.

### R9 - Evidence document

Add or update a concise public evidence document, expected path:

```text
docs/tree-sitter-go-symbol-extraction-proof.md
```

It must record:

- proof target name;
- supported Go subset;
- direct traversal boundary;
- range and ordering semantics;
- symbol-kind mapping and caveats;
- validation commands and exit statuses;
- local/offline proof boundary;
- explicit statement that Go runtime `--symbols` output is not implemented yet.

### R10 - CI decision

The new proof target must either be added to CI after existing proof steps or a
durable reason must be recorded for excluding it. If added, CI must remain local
after checkout and Zig setup and must not require sibling repo smoke, secrets,
artifacts, release automation, cache, package managers, or network fetches.

### R11 - Privacy and claims

Committed evidence must use repo-relative paths and bounded public component
identifiers only. It must not include private paths, raw sibling reports, raw
parser stderr, source snippets from private repos, remotes, author identities,
commercial strategy, bug prediction, quality scoring, developer ranking, or
maintainer judgement.

## Edge cases

- If the Go parser API or node names differ from the expected source-import
  evidence, stop and record a blocker instead of broadening extraction locally.
- If receiver-qualified method names are needed to avoid ambiguity, stop and
  shape that naming contract separately. The first proof may use bare method
  names with a caveat.
- If structs, interfaces, constants, or variables cannot be mapped without
  expanding `provider.SymbolKind`, either map conservatively with caveats or stop
  for a seam-extension feature.
- If partial parse behaviour leaks diagnostics or snippets, block close-out.
- If no-provider outputs or existing Zig symbol outputs change, block close-out.
- If CI inclusion creates material cost or platform instability, record the
  decision and stop for planning.

## Verification

Close-out must include evidence for:

```sh
zig fmt --check build.zig src tests
zig build test
zig build
zig build validate
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
zig build tree-sitter-go-build-proof
zig build tree-sitter-go-symbol-proof
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo
```

The sibling path is execution-only context and must not be committed. Durable
summary evidence must use only the label `sibling-local-repo`.
