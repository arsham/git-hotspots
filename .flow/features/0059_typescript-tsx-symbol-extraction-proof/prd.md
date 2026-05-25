# Feature 0059: TypeScript/TSX symbol extraction proof

## Summary

Add an internal, non-product proof that the vendored Tree-sitter TypeScript and
TSX parsers, scanners, and project-owned query contracts can extract current
symbols into the existing provider symbol evidence shape.

This feature proves TypeScript/TSX symbol semantics only. It does not expose
TypeScript or TSX symbols in CLI output, add a provider registry entry, change
report schemas, change scoring, alter no-provider behaviour, add Node/package or
tsconfig analysis, or add symbol history.

## Problem

Feature 0057 proves TypeScript/TSX parser and scanner build compatibility, and
Feature 0058 establishes TypeScript/TSX query contracts and fixture coverage.
The next risk is extraction implementation: turning TypeScript and TSX query
captures into deterministic current-symbol evidence with correct ownership,
ranges, ordering, caveats, and failure behaviour.

Without an internal extraction proof, user-facing TypeScript/TSX `--symbols`
output would combine extraction semantics, CLI/report UX, TSX semantics, and
validation risk in one step.

## Goals

- Add dedicated internal proof targets, expected as:

  ```sh
  zig build tree-sitter-typescript-symbol-proof
  zig build tree-sitter-tsx-symbol-proof
  ```

- Use vendored local Tree-sitter core and TypeScript/TSX parser/scanner sources
  only.
- Use the project-owned TypeScript/TSX query contracts from Feature 0058.
- Extract bounded current-symbol subsets from in-memory or fixture TypeScript
  and TSX source.
- Map extracted symbols to `provider.CurrentSymbolEvidence` or a directly
  compatible internal shape.
- Prove deterministic range semantics and deterministic ordering.
- Prove degraded, unsupported, empty, invalid, generated/minified, export,
  CommonJS, anonymous, unsafe path, Markdown-sensitive, TSX component, fragment,
  and JSX caveat behaviour without raw diagnostics or source snippets.
- Preserve no-provider output stability and existing Zig/Go/Python/JavaScript
  symbol behaviour.
- Record privacy-safe evidence and the explicit boundary that TypeScript/TSX
  runtime symbol output is not implemented yet.

## Non-goals

- No user-facing TypeScript/TSX `--symbols` output.
- No CLI flag changes.
- No report schema, fixture output, scoring, ranking, lineage, cache, or CI
  release changes.
- No TypeScript/TSX provider registry entry.
- No `package.json`, workspace, bundler, dependency graph, module resolution,
  Node provider identity, tsconfig analysis, type checking, LSP, custom query
  execution, or repo-wide semantic scanning.
- No `git log -L`, symbol history, symbol lineage, source snippets, raw parser
  diagnostics, authors, emails, commit messages, ownership metrics, bug
  prediction, quality scoring, or developer ranking.
- No parser generation, network fetches, package-manager resolution,
  submodules, global Tree-sitter CLI, system parser packages, or
  `build.zig.zon` changes unless already required by prior local proof targets.

## Requirements

### R1 Dedicated TypeScript and TSX symbol proof targets

The implementation must add dedicated internal proof targets, expected as:

```sh
zig build tree-sitter-typescript-symbol-proof
zig build tree-sitter-tsx-symbol-proof
```

The proof targets must be separate from product runtime. They may compile and
link vendored Tree-sitter core and TypeScript/TSX sources for proof execution,
but they must not install or wire TypeScript/TSX provider behaviour into the
CLI.

### R2 Query contract use

The proof must use the Feature 0058 project-owned TypeScript and TSX query
contracts. It must not silently switch to upstream highlight queries, custom
user queries, LSP, package metadata, Node runtime analysis, tsconfig analysis,
TypeScript type checking, or semantic evaluation.

### R3 Bounded TypeScript/TSX symbol subset

The proof should extract these current working-tree symbol classes when present
and deterministic:

- module or file evidence;
- top-level functions;
- function expressions assigned to stable names;
- arrow functions assigned to stable names;
- classes;
- constructors, methods, accessors, and class fields;
- interfaces;
- type aliases;
- enums and enum members where deterministic;
- namespaces and module declarations;
- simple constants and variables;
- ESM named exports, default exports, and deterministic re-exports;
- CommonJS `module.exports` and `exports.*` patterns only when deterministic;
- TSX component definitions; and
- JSX-bearing TSX constructs such as fragments and expression-heavy components
  when deterministic.

Unsupported dynamic constructs must be ignored or caveated deterministically.

### R4 Range semantics

Each symbol must use one-based inclusive line ranges from the selected
TypeScript or TSX declaration node under the Feature 0058 contracts. Export
wrappers, decorators, overloads, class members, TSX components, anonymous
exports, generated/minified inputs, and partial syntax must match the contract
and be proven with fixtures.

### R5 Ordering semantics

The proof must establish deterministic source order using start byte, end byte,
kind rank, and bytewise symbol name, unless an existing helper with equivalent
semantics is used and documented.

### R6 Existing provider shape and caveats

The proof must use `provider.CurrentSymbolEvidence` or a directly compatible
internal shape. Caveats must include current-only semantics and avoid implying
TypeScript type checking, Node execution, package loading, tsconfig analysis,
module resolution, bundler analysis, dependency analysis, custom queries, LSP
data, runtime TypeScript/TSX provider support, or symbol history.

### R7 Degraded and unsupported cases

The proof must cover and caveat empty source, invalid or partial source,
unsupported non-TypeScript/TSX path, unsafe repo-relative path rejection before
parsing, generated or minified file caveat or deterministic skip behaviour,
export/CommonJS patterns, anonymous exports, dynamic constructs, TSX fragments,
JSX-heavy components, and Markdown-sensitive symbol names where the parser
accepts them.

Failure paths must not expose raw parser diagnostics, absolute paths, source
snippets, remotes, author identities, private repo names, or raw private output.

### R8 Existing behaviour preservation

Existing proof targets and product validation must continue to pass:

```sh
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
zig build tree-sitter-go-build-proof
zig build tree-sitter-go-symbol-proof
zig build tree-sitter-python-build-proof
zig build tree-sitter-python-symbol-proof
zig build tree-sitter-javascript-build-proof
zig build tree-sitter-javascript-query-proof
zig build tree-sitter-javascript-symbol-proof
zig build tree-sitter-typescript-build-proof
zig build tree-sitter-tsx-build-proof
zig build tree-sitter-typescript-query-proof
zig build tree-sitter-tsx-query-proof
zig build validate
```

No-provider table, JSON, Markdown, inspect, and existing Zig/Go/Python/JavaScript
`--symbols` outputs must remain byte-stable unless a separate feature explicitly
changes them.

### R9 Evidence document

Add a concise public evidence document, expected path:

```text
docs/tree-sitter-typescript-symbol-extraction-proof.md
```

It must record proof target names, supported TypeScript and TSX subsets, TSX
support or deferral state, query contract basis, range and ordering semantics,
symbol-kind mapping and caveats, validation commands and exit statuses,
local/offline proof boundary, and explicit statement that TypeScript/TSX runtime
`--symbols` output is not implemented yet.

### R10 CI decision

The new proof targets must either be added to CI after existing proof steps or a
durable reason must be recorded for excluding them. If added, CI must remain
local after checkout and Zig setup and must not require sibling repo smoke,
secrets, artifacts, release automation, cache, package managers, or network
fetches.

### R11 Privacy and claims

Committed evidence must use repo-relative paths and bounded public component
identifiers only. It must not include private paths, raw sibling reports, raw
parser stderr, source snippets from private repos, remotes, author identities,
commercial strategy, bug prediction, quality scoring, developer ranking, or
maintainer judgement.

## Edge cases

- If TypeScript and TSX node names or query captures differ from the contract,
  stop and reshape instead of broadening extraction locally.
- If TSX handling cannot be deterministic, caveat or defer the construct rather
  than claiming broader support.
- If export, overload, declaration merge, namespace, or CommonJS naming cannot
  be deterministic, skip or caveat the case.
- If symbol kinds need schema expansion, stop for planning rather than changing
  public schema locally.
- If extraction needs package metadata, Node, module resolution, tsconfig, type
  checking, LSP, or custom queries to be useful, stop for a separate feature.

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
zig build tree-sitter-javascript-build-proof
zig build tree-sitter-javascript-query-proof
zig build tree-sitter-javascript-symbol-proof
zig build tree-sitter-typescript-build-proof
zig build tree-sitter-tsx-build-proof
zig build tree-sitter-typescript-query-proof
zig build tree-sitter-tsx-query-proof
zig build tree-sitter-typescript-symbol-proof
zig build tree-sitter-tsx-symbol-proof
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo
```

Close-out evidence must prove no runtime provider output, no Node/package,
workspace, tsconfig, type-checking, or LSP analysis, deterministic degraded
behaviour, privacy-safe caveats, and stable existing provider outputs.
