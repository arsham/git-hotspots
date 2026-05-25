# Feature 0053: JavaScript symbol extraction proof

## Summary

Add an internal, non-product proof that the vendored Tree-sitter JavaScript
parser, any scanner, and the project-owned query contract can extract current
JavaScript symbols into the existing provider symbol evidence shape.

This feature proves JavaScript symbol semantics only. It does not expose
JavaScript symbols in CLI output, add a provider registry entry, change report
schemas, change scoring, alter no-provider behaviour, add Node/package analysis,
or add TypeScript/TSX support.

## Problem

Feature 0051 proves JavaScript parser/scanner build compatibility, and Feature
0052 establishes the first JavaScript query contract and fixture coverage. The
next risk is extraction implementation: turning parsed JavaScript and JSX trees
into deterministic current-symbol evidence with correct ownership, ranges,
ordering, caveats, and failure behaviour.

Without an internal extraction proof, user-facing JavaScript `--symbols` output
would combine extraction semantics, CLI/report UX, and validation risk in one
step.

## Goals

- Add a dedicated internal proof target, expected as:

  ```sh
  zig build tree-sitter-javascript-symbol-proof
  ```

- Use vendored local Tree-sitter core and tree-sitter-javascript parser/scanner
  sources only.
- Use the project-owned JavaScript query contract from Feature 0052.
- Extract a bounded current-symbol subset from in-memory or fixture JavaScript
  and admitted JSX source.
- Map extracted symbols to `provider.CurrentSymbolEvidence` or a directly
  compatible internal shape.
- Prove deterministic range semantics and deterministic ordering.
- Prove degraded, unsupported, empty, invalid, generated/minified, JSX,
  export/CommonJS, anonymous, unsafe path, and Markdown-sensitive caveat
  behaviour without raw diagnostics or source snippets.
- Preserve no-provider output stability and existing Zig/Go/Python symbol
  behaviour.
- Record privacy-safe evidence and the explicit boundary that JavaScript runtime
  symbol output is not implemented yet.

## Non-goals

- No user-facing JavaScript `--symbols` output.
- No CLI flag changes.
- No report schema, fixture output, scoring, ranking, lineage, cache, or CI
  release changes.
- No JavaScript provider registry entry.
- No `package.json`, workspace, bundler, dependency graph, module resolution,
  Node provider identity, LSP, custom query execution, TypeScript, TSX, or
  repo-wide scanning.
- No `git log -L`, symbol history, symbol lineage, source snippets, raw parser
  diagnostics, authors, emails, commit messages, ownership metrics, bug
  prediction, quality scoring, or developer ranking.
- No parser generation, network fetches, package-manager resolution,
  submodules, global Tree-sitter CLI, system parser packages, or
  `build.zig.zon`.

## Requirements

### R1 Dedicated JavaScript symbol proof target

The implementation must add a dedicated internal proof target, expected as:

```sh
zig build tree-sitter-javascript-symbol-proof
```

The proof target must be separate from product runtime. It may compile and link
vendored Tree-sitter core and JavaScript sources for proof execution, but it
must not install or wire JavaScript provider behaviour into the CLI.

### R2 Query contract use

The proof must use the Feature 0052 project-owned JavaScript query contract. It
must not silently switch to upstream highlight queries, custom user queries,
LSP, package metadata, Node runtime analysis, or JavaScript semantic evaluation.

### R3 Bounded JavaScript symbol subset

The proof should extract these current working-tree symbol classes when present:

- module or file evidence where deterministic;
- top-level functions;
- function expressions assigned to stable names;
- arrow functions assigned to stable names;
- classes;
- methods and class fields where deterministic;
- simple constants and variables;
- ESM named exports, default exports, and deterministic re-exports;
- CommonJS `module.exports` and `exports.*` patterns where deterministic; and
- JSX component definitions when JSX was admitted and proved.

Unsupported dynamic constructs must be ignored or caveated deterministically.

### R4 Range semantics

Each symbol must use one-based inclusive line ranges from the selected
JavaScript declaration node under the Feature 0052 contract. Export wrappers,
class members, JSX components, anonymous exports, and generated/minified inputs
must match the contract and be proven with fixtures.

### R5 Ordering semantics

The proof must establish deterministic source order using start byte, end byte,
kind rank, and bytewise symbol name, unless an existing helper with equivalent
semantics is used and documented.

### R6 Existing provider shape and caveats

The proof must use `provider.CurrentSymbolEvidence` or a directly compatible
internal shape. Caveats must include current-only semantics and avoid implying
JavaScript type checking, Node execution, package loading, module resolution,
bundler analysis, dependency analysis, custom queries, LSP data, TypeScript,
TSX, or runtime JavaScript provider support.

### R7 Degraded and unsupported cases

The proof must cover and caveat empty source, invalid or partial source,
unsupported non-JavaScript path, unsafe repo-relative path rejection before
parsing, generated or minified file caveat or deterministic skip behaviour, JSX
when admitted, export/CommonJS patterns, anonymous exports, dynamic constructs,
and Markdown-sensitive symbol names where the parser accepts them.

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
zig build validate
```

No-provider table, JSON, Markdown, inspect, and existing Zig/Go/Python
`--symbols` outputs must remain byte-stable unless a separate feature explicitly
changes them.

### R9 Evidence document

Add a concise public evidence document, expected path:

```text
docs/tree-sitter-javascript-symbol-extraction-proof.md
```

It must record proof target name, supported JavaScript subset, JSX support or
deferral state, query contract basis, range and ordering semantics, symbol-kind
mapping and caveats, validation commands and exit statuses, local/offline proof
boundary, and explicit statement that JavaScript runtime `--symbols` output is
not implemented yet.

### R10 CI decision

The new proof target must either be added to CI after existing proof steps or a
durable reason must be recorded for excluding it. If added, CI must remain local
after checkout and Zig setup and must not require sibling repo smoke, secrets,
artifacts, release automation, cache, package managers, or network fetches.

### R11 Privacy and claims

Committed evidence must use repo-relative paths and bounded public component
identifiers only. It must not include private paths, raw sibling reports, raw
parser stderr, source snippets from private repos, remotes, author identities,
commercial strategy, bug prediction, quality scoring, developer ranking, or
maintainer judgement.

## Edge cases

- If JavaScript node names or query captures differ from the contract, stop and
  reshape instead of broadening extraction locally.
- If JSX handling cannot be deterministic, caveat or defer JSX rather than
  importing TypeScript/TSX or claiming broader support.
- If export or CommonJS naming cannot be deterministic, skip or caveat the case.
- If symbol kinds need schema expansion, stop for planning rather than changing
  public schema locally.
- If extraction needs package metadata, Node, module resolution, LSP, or custom
  queries to be useful, stop for a separate feature.

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
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo
```

Close-out evidence must prove no runtime provider output, no TypeScript/TSX
support, no Node/package/workspace analysis, deterministic degraded behaviour,
privacy-safe caveats, and stable existing provider outputs.
