# Feature 0045: Tree-sitter Python symbol extraction proof

## Summary

Add an internal, non-product proof that the vendored Tree-sitter Python parser,
scanner, and project-owned query contract can extract current Python symbols
into the existing provider symbol evidence shape.

This feature proves Python symbol semantics only. It does not expose Python
symbols in CLI output, add a provider registry entry, change report schemas,
change scoring, or alter no-provider behaviour.

## Problem

Feature 0043 proves Python parser/scanner build compatibility, and Feature 0044
establishes the first Python query contract and fixture coverage. The next risk
is extraction implementation: turning parsed Python trees and contract captures
into deterministic current-symbol evidence with correct ownership, ranges,
ordering, caveats, and failure behaviour.

Without an internal extraction proof, user-facing Python `--symbols` output
would combine extraction semantics, CLI/report UX, and validation risk in one
step.

## Goals

- Add a dedicated internal proof target, expected as:

  ```sh
  zig build tree-sitter-python-symbol-proof
  ```

- Use vendored local Tree-sitter core and tree-sitter-python parser/scanner
  sources only.
- Use the project-owned Python query contract from Feature 0044.
- Extract a bounded current-symbol subset from in-memory or fixture Python
  source.
- Map extracted symbols to `provider.CurrentSymbolEvidence` or a directly
  compatible internal shape.
- Prove deterministic range semantics and deterministic ordering.
- Prove degraded, unsupported, empty, invalid, generated-file, decorator,
  nested-definition, and dynamic-assignment caveat behaviour without raw
  diagnostics or source snippets.
- Preserve no-provider output stability and existing Zig/Go symbol behaviour.
- Record privacy-safe evidence and the explicit boundary that Python runtime
  symbol output is not implemented yet.

## Non-goals

- No user-facing Python `--symbols` output.
- No CLI flag changes.
- No report schema, fixture output, scoring, ranking, lineage, cache, or CI
  release changes.
- No Python provider registry entry.
- No Python package-manager, virtualenv, import resolution, dependency graph,
  notebook, LSP, custom query execution, or repo-wide scanning.
- No `git log -L`, symbol history, symbol lineage, source snippets, raw parser
  diagnostics, authors, emails, commit messages, ownership metrics, bug
  prediction, quality scoring, or developer ranking.
- No parser generation, network fetches, package-manager resolution,
  submodules, global Tree-sitter CLI, system parser packages, or
  `build.zig.zon`.

## Requirements

### R1 - Dedicated Python symbol proof target

The implementation must add a dedicated internal proof target, expected as:

```sh
zig build tree-sitter-python-symbol-proof
```

The proof target must be separate from product runtime. It may compile and link
vendored Tree-sitter core and tree-sitter-python sources for proof execution,
but it must not install or wire Python provider behaviour into the CLI.

### R2 - Query contract use

The proof must use the Feature 0044 project-owned Python query contract. It must
not silently switch to upstream highlight queries, custom user queries, LSP, or
Python semantic evaluation.

### R3 - Bounded Python symbol subset

The proof should extract these current working-tree symbol classes when present:

- module file evidence where deterministic;
- top-level classes as `type`;
- top-level functions as `function`;
- methods inside classes as `method`;
- simple module-level constants and assignments as a conservative existing kind
  with caveats;
- decorators as caveats or metadata according to the query contract; and
- nested functions/classes with deterministic caveats.

Unsupported dynamic constructs must be ignored or caveated deterministically.

### R4 - Range semantics

Each symbol must use one-based inclusive line ranges from the selected Python
declaration node under the Feature 0044 contract. Decorator and nested-definition
range rules must match the contract and be proven with fixtures.

### R5 - Ordering semantics

The proof must establish deterministic source order using start byte, end byte,
kind rank, and bytewise symbol name, unless an existing helper with equivalent
semantics is used and documented.

### R6 - Existing provider shape and caveats

The proof must use `provider.CurrentSymbolEvidence` or a directly compatible
internal shape. Caveats must include current-only semantics and avoid implying
Python type checking, package loading, import resolution, virtualenv handling,
custom queries, notebooks, dependency analysis, or runtime Python provider
support.

### R7 - Degraded and unsupported cases

The proof must cover and caveat empty source, invalid or partial source,
unsupported non-Python path, unsafe repo-relative path rejection before parsing,
generated-file caveat or deterministic skip behaviour, decorator-heavy input,
nested definitions, dynamic assignments, and Unicode/Markdown-sensitive symbol
names where the parser accepts them.

Failure paths must not expose raw parser diagnostics, absolute paths, source
snippets, remotes, author identities, private repo names, or raw private output.

### R8 - Existing behaviour preservation

Existing proof targets and product validation must continue to pass:

```sh
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
zig build tree-sitter-go-build-proof
zig build tree-sitter-go-symbol-proof
zig build tree-sitter-python-build-proof
zig build validate
```

No-provider table, JSON, Markdown, inspect, and existing Zig/Go `--symbols`
outputs must remain byte-stable unless a separate feature explicitly changes
them.

### R9 - Evidence document

Add a concise public evidence document, expected path:

```text
docs/tree-sitter-python-symbol-extraction-proof.md
```

It must record proof target name, supported Python subset, query contract basis,
range and ordering semantics, symbol-kind mapping and caveats, validation
commands and exit statuses, local/offline proof boundary, and explicit statement
that Python runtime `--symbols` output is not implemented yet.

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

- If Python node names or query captures differ from the contract, stop and
  reshape instead of broadening extraction locally.
- If decorator or nested-definition handling cannot be deterministic, caveat or
  stop for shaping.
- If constants cannot be mapped without expanding `provider.SymbolKind`, map
  conservatively with caveats or stop for a seam-extension feature.
- If partial parse behaviour leaks diagnostics or snippets, block close-out.
- If no-provider outputs or existing Zig/Go symbol outputs change, block
  close-out.

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
zig build tree-sitter-python-build-proof
zig build tree-sitter-python-symbol-proof
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo
```

The sibling path is execution-only context and must not be committed. Durable
summary evidence must use only the label `sibling-local-repo`.
