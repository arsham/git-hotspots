# Feature 0052: JavaScript query contract and fixtures

## Summary

Define a project-owned JavaScript query contract and fixture corpus for future
Tree-sitter symbol extraction. The contract covers JavaScript and admitted JSX
syntax, capture names, symbol-kind mapping, ranges, ordering, provider/query
version metadata, caveats, and degraded cases without exposing JavaScript
symbols through the product CLI.

This is a non-product, test-only contract. It must not add JavaScript runtime
provider behaviour, provider registry entries, report schema changes, scoring,
cache changes, package/workspace analysis, Node provider identity, TypeScript or
TSX support, or custom user query execution.

## Problem

Feature 0051 proves that the vendored JavaScript grammar can compile and parse
locally. It does not define which JavaScript or JSX constructs become current
symbols, how query captures map to provider evidence, or which fixtures prove
deterministic semantics.

Without a query contract, user-facing JavaScript symbols would combine grammar,
query design, extraction semantics, and output risk in one step.

## Outcome

A project-owned JavaScript symbol query contract and fixture corpus define the
supported subset, capture names, mapping, ranges, ordering, caveats, and
validation evidence. JavaScript runtime symbol output remains absent after this
feature.

## Requirements

### R1 Query asset and proof target

Add a project-owned JavaScript symbol query asset and a dedicated non-product
proof target, expected as:

```sh
zig build tree-sitter-javascript-query-proof
```

The query must use the vendored JavaScript grammar from Feature 0050 and the
build proof from Feature 0051. It must not import upstream highlight queries as
runtime truth, execute custom user queries, or use LSP data.

### R2 Capture contract

The contract must name accepted capture names for supported JavaScript symbols.
The first supported set should cover:

- module or file evidence when deterministic;
- function declarations;
- function expressions assigned to stable names;
- arrow functions assigned to stable names;
- classes;
- methods and class fields where deterministic;
- constants and variables;
- ESM named exports;
- default exports;
- re-exports when deterministic;
- CommonJS `module.exports` and `exports.*` assignments; and
- JSX component definitions when JSX was admitted by Feature 0050 and proved by
  Feature 0051.

Unsupported or ambiguous constructs must be ignored or caveated
deterministically.

### R3 Symbol-kind mapping

The contract must map supported captures into the existing provider symbol shape
or a directly compatible internal proof shape. It must document the chosen kind
for functions, classes, methods, variables, constants, module/file evidence,
exports, CommonJS assignments, and JSX components without expanding public
schema unless a separate feature does so.

### R4 Range semantics

The contract must define one-based inclusive line ranges for each supported
symbol class. Decorated/exported/wrapped forms must use deterministic ranges
from the selected declaration node. JSX component ranges must be explicit when
JSX is admitted. If a construct cannot produce deterministic line ranges, it
must be caveated or excluded.

### R5 Ordering semantics

The contract must establish deterministic source ordering using start byte, end
byte, kind rank, and bytewise symbol name, unless an existing helper with
equivalent semantics is used and documented.

### R6 Fixture corpus

Fixture coverage must include at least:

- `.js`, `.mjs`, and `.cjs` path examples;
- `.jsx` path examples when JSX remains admitted;
- top-level functions and function expressions;
- arrow functions;
- classes, methods, and class fields where supported;
- constants and variables;
- ESM named exports, default exports, and re-exports;
- CommonJS `module.exports` and `exports.*` patterns;
- anonymous exports that should be named, caveated, or skipped
  deterministically;
- JSX components, fragments, and expression-heavy examples when JSX is admitted;
- generated or minified bundles that should be caveated or skipped
  deterministically;
- empty files;
- invalid or partial files;
- unsupported paths and skipped-provider states;
- unsafe path rejection; and
- monorepo-style project-relative paths.

If JSX was deferred in Feature 0050 or 0051, the fixture corpus must record that
`.jsx` remains unsupported rather than claiming support.

### R7 Degraded and unsupported cases

Unsupported extensions must return unsupported without parsing. Unsafe paths
must be rejected before parsing. Invalid or partial JavaScript must return a
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
zig build validate
```

No-provider table, JSON, Markdown, inspect, and existing Zig/Go/Python
`--symbols` outputs must remain byte-stable unless a separate feature explicitly
changes them.

### R9 Evidence document

Add a concise public evidence document, expected path:

```text
docs/tree-sitter-javascript-query-contract.md
```

It must record query asset identity, query version, provider proof name,
supported subset, capture names, range and ordering semantics, symbol-kind
mapping, fixture coverage, caveats, validation commands, local/offline proof
boundary, and explicit statement that JavaScript runtime `--symbols` output is
not implemented yet.

### R10 Protected surfaces

Allowed changed paths are limited to non-product proof/query fixtures, proof
source, `build.zig` proof wiring, evidence docs, optional CI proof wiring, and
Flow state.

The implementation must not change product `src/` runtime provider behaviour,
provider registry, CLI/report/schema/scoring/cache, default outputs, TypeScript
or TSX source paths, Node/package/workspace analysis, or custom user query
execution.

## Non-goals

- No user-facing JavaScript `--symbols` output.
- No provider registry entry.
- No new CLI flags.
- No report schema, scoring, cache, package, release, LSP, Node, package
  manager, workspace, bundler, dependency graph, module resolution, custom user
  queries, TypeScript, TSX, or repo-wide scanning.

## Edge cases

- If the selected JavaScript grammar cannot parse JSX reliably, keep `.jsx`
  unsupported and record why.
- If an export or CommonJS pattern cannot be named deterministically, skip or
  caveat it instead of inventing names.
- If symbol kinds require public schema expansion, stop for planning rather than
  expanding the schema locally.
- If fixtures expose Markdown-sensitive names or paths, human output evidence
  must prove escaping before runtime output is later added.

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
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<local-sibling-path> -Dsmoke-label=sibling-local-repo
```

Close-out evidence must prove fixture coverage, deterministic ordering, degraded
case behaviour, privacy-safe caveats, no runtime provider output, no TypeScript
or TSX support, and no Node/package/workspace analysis.
