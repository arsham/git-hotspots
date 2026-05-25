# Feature 0058: TypeScript/TSX query contract and fixtures

## Summary

Define project-owned TypeScript and TSX query contracts and fixture corpora for
future Tree-sitter symbol extraction. The contracts cover TypeScript and TSX
syntax, capture names, symbol-kind mapping, ranges, ordering, provider/query
version metadata, caveats, and degraded cases without exposing TypeScript or TSX
symbols through the product CLI.

This is a non-product, test-only contract. It must not add TypeScript/TSX
runtime provider behaviour, provider registry entries, report schema changes,
scoring, cache changes, package/workspace analysis, Node provider identity,
tsconfig analysis, LSP behaviour, or custom user query execution.

## Problem

Feature 0057 proves that the vendored TypeScript and TSX grammars can compile
and parse locally. It does not define which TypeScript or TSX constructs become
current symbols, how query captures map to provider evidence, or which fixtures
prove deterministic semantics.

Without a query contract, user-facing TypeScript/TSX symbols would combine
grammar, query design, extraction semantics, JSX/TSX semantics, and output risk
in one step.

## Outcome

Project-owned TypeScript and TSX symbol query contracts and fixture corpora
define the supported subsets, capture names, mapping, ranges, ordering, caveats,
and validation evidence. TypeScript/TSX runtime symbol output remains absent
after this feature.

## Requirements

### R1 Query assets and proof targets

Add project-owned TypeScript and TSX symbol query assets and dedicated
non-product proof targets, expected as:

```sh
zig build tree-sitter-typescript-query-proof
zig build tree-sitter-tsx-query-proof
```

The query assets must use the vendored TypeScript/TSX grammars from Feature
0056 and the build proofs from Feature 0057. They must not import upstream
highlight queries as runtime truth, execute custom user queries, use LSP data,
run Node/package tooling, or consult tsconfig/module resolution.

### R2 Capture contract

The contracts must name accepted capture names for supported TypeScript and TSX
symbols. The first supported set should cover:

- module or file evidence when deterministic;
- function declarations;
- function expressions assigned to stable names;
- arrow functions assigned to stable names;
- classes;
- methods, constructors, accessors, and class fields where deterministic;
- interfaces;
- type aliases;
- enums and enum members where deterministic;
- namespaces and module declarations where deterministic;
- constants and variables;
- ESM named exports;
- default exports;
- re-exports when deterministic;
- CommonJS assignments only when the grammar and fixture semantics make them
  deterministic;
- TSX component definitions; and
- JSX-bearing TSX constructs such as fragments and expression-heavy component
  bodies when deterministic.

Unsupported or ambiguous constructs must be ignored or caveated
deterministically.

### R3 Symbol-kind mapping

The contracts must map supported captures into the existing provider symbol
shape or a directly compatible internal proof shape. They must document chosen
kinds for functions, classes, methods, variables, constants, interfaces, type
aliases, enums, namespaces, module/file evidence, exports, CommonJS assignments
where supported, and TSX components without expanding the public schema unless a
separate feature does so.

### R4 Range semantics

The contracts must define one-based inclusive line ranges for each supported
symbol class. Decorated/exported/wrapped forms must use deterministic ranges
from the selected declaration node. TSX component ranges must be explicit. If a
construct cannot produce deterministic line ranges, it must be caveated or
excluded.

### R5 Ordering semantics

The contracts must establish deterministic source ordering using start byte, end
byte, kind rank, and bytewise symbol name, unless an existing helper with
equivalent semantics is used and documented.

### R6 Fixture corpus

Fixture coverage must include at least:

- `.ts`, `.mts`, and `.cts` path examples;
- `.tsx` path examples;
- top-level functions and function expressions;
- arrow functions;
- classes, constructors, methods, accessors, and class fields where supported;
- interfaces;
- type aliases;
- enums;
- namespaces and module declarations where supported;
- constants and variables;
- ESM named exports, default exports, and re-exports;
- CommonJS patterns when supported or a deterministic unsupported finding;
- anonymous exports that should be named, caveated, or skipped
  deterministically;
- TSX components, fragments, and expression-heavy examples;
- generated or minified bundles that should be caveated or skipped
  deterministically;
- empty files;
- invalid or partial files;
- unsupported paths and skipped-provider states;
- unsafe path rejection; and
- monorepo-style project-relative paths.

### R7 Degraded and unsupported cases

Unsupported extensions must return unsupported without parsing. Unsafe paths
must be rejected before parsing. Invalid or partial TypeScript/TSX must return a
deterministic failed or caveated state without raw parser diagnostics, source
snippets, absolute paths, private repo names, remotes, authors, or raw private
output.

Generated or minified files must be caveated or skipped deterministically and
must not affect scoring.

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
zig build tree-sitter-typescript-build-proof
zig build tree-sitter-tsx-build-proof
zig build validate
```

No-provider table, JSON, Markdown, inspect, and existing Zig/Go/Python/JavaScript
`--symbols` outputs must remain byte-stable unless a separate feature explicitly
changes them.

### R9 Evidence document

Add a concise public evidence document, expected path:

```text
docs/tree-sitter-typescript-query-contract.md
```

It must record query asset identities, query versions, proof target names,
supported subsets, capture names, range and ordering semantics, symbol-kind
mapping, fixture coverage, caveats, validation commands, local/offline proof
boundary, and explicit statement that TypeScript/TSX runtime `--symbols` output
is not implemented yet.

### R10 Protected surfaces

Allowed changed paths are limited to non-product proof/query fixtures, proof
source, `build.zig` proof wiring, evidence docs, optional CI proof wiring, and
Flow state.

The implementation must not change product `src/` runtime provider behaviour,
provider registry, CLI/report/schema/scoring/cache, default outputs, JavaScript
query semantics, Node/package/workspace analysis, tsconfig analysis, LSP
behaviour, or custom user query execution.

## Non-goals

- No user-facing TypeScript/TSX `--symbols` output.
- No provider registry entry.
- No new CLI flags.
- No report schema, scoring, cache, package, release, LSP, Node, package
  manager, workspace, bundler, dependency graph, module resolution, tsconfig, or
  custom user query execution.
- No JavaScript query contract changes except shared helper reuse that preserves
  JavaScript proof output.

## Edge cases

- If TypeScript and TSX need different capture names or range semantics, keep
  both contracts explicit and independently reviewable.
- If an export, namespace, decorator, overload, declaration merge, or CommonJS
  pattern cannot be named deterministically, skip or caveat it instead of
  inventing names.
- If symbol kinds require public schema expansion, stop for planning rather
  than expanding the schema locally.
- If fixtures expose Markdown-sensitive names or paths, human output evidence
  must prove escaping before runtime output is later added.
- If query proof needs generated files not imported by Feature 0056, stop and
  reshape instead of silently expanding the BOM.

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
zig build tree-sitter-typescript-build-proof
zig build tree-sitter-tsx-build-proof
zig build tree-sitter-typescript-query-proof
zig build tree-sitter-tsx-query-proof
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo
```

Close-out evidence must prove fixture coverage, deterministic ordering, degraded
case behaviour, privacy-safe caveats, no runtime provider output, no
Node/package/workspace/tsconfig/LSP analysis, and no drift in JavaScript or
existing Zig/Go/Python symbol behaviour.
