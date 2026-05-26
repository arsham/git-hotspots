# Rust query contract and fixtures

## Problem

A Rust parser build proof does not define which Rust constructs become current
symbols, how query captures map to provider evidence, or which fixtures prove
deterministic Rust semantics. Without a query contract, user-facing Rust
symbols would combine grammar, query design, extraction semantics, Rust macro
and type caveats, and output risk in one step.

## Outcome

A project-owned Rust symbol query contract and fixture corpus define the
supported subset, capture names, mapping, ranges, ordering, caveats, and
validation evidence. Rust runtime symbol output remains absent after this
feature.

## Requirements

### R1 Query contract scope

- Define built-in Rust symbol query captures for stable inspect-oriented syntax.
- Cover freestanding functions, methods in `impl` blocks, trait declarations,
  trait methods, modules, structs, tuple structs, unit structs, enums,
  constants, static items, and deliberately included or skipped enum variants
  only when represented syntactically.
- Define symbol-kind mapping, range semantics, deterministic ordering, provider
  version metadata, query version metadata, and unsupported-case caveats.
- Keep query assets project-owned; do not blindly import upstream highlight
  queries.
- Do not add runtime provider output, provider registry entries, CLI flags,
  report schema fields, scoring changes, cache changes, custom user query
  execution, Cargo/package/module analysis, macro expansion, type checking,
  LSP, network, telemetry, upload, or remote enrichment.

### R2 Fixture coverage

Fixture coverage must include:

- `.rs` path examples;
- freestanding functions;
- methods in inherent `impl` blocks;
- trait declarations and trait methods;
- modules, including inline module declarations and nested modules;
- structs, tuple structs, and unit structs when they can be mapped
  deterministically;
- enums and variants when variant capture is deliberately included or skipped;
- constants and static items;
- macro-heavy files and macro invocations that should be caveated or skipped;
- attributes and conditional compilation examples;
- generics, lifetimes, trait bounds, and where clauses;
- nested items;
- generated Rust files;
- empty files;
- invalid or partial files;
- unsupported paths and skipped-provider states; and
- monorepo-style project-relative paths.

### R3 Evidence document

Add a concise public evidence document, expected path:

```text
docs/tree-sitter-rust-query-contract.md
```

It must record query asset identities, query versions, proof target names,
supported subsets, capture names, range and ordering semantics, symbol-kind
mapping, fixture coverage, caveats, validation commands, local/offline proof
boundary, and explicit statement that Rust runtime `--symbols` output is not
implemented yet.

### R4 Existing behaviour preservation

Existing proof targets and product validation must continue to pass. No-provider
table, JSON, Markdown, inspect, and existing Zig, Go, Python, JavaScript, Lua,
TypeScript, and TSX symbol outputs must remain byte-stable unless a separate
feature explicitly changes them.

## Acceptance criteria

- A project-owned Rust query contract exists and is covered by deterministic
  fixture/proof targets.
- Supported syntax, skipped syntax, caveats, capture names, symbol kinds,
  ranges, ordering, provider/query versions, and fixture coverage are explicit.
- The evidence document exists at `docs/tree-sitter-rust-query-contract.md`.
- Rust runtime symbol output, provider registry wiring, custom user queries,
  Cargo/package/module analysis, macro expansion, type checking, report
  schemas, scoring, cache, CI, network, telemetry, upload, and remote
  enrichment remain absent.
- Existing language provider outputs and no-provider outputs remain stable.

## Edge cases

- If a Rust construct cannot be named deterministically, skip or caveat it
  rather than inventing semantic meaning.
- If trait resolution, module resolution, macro expansion, type checking,
  conditional compilation, or crate graph analysis would be required, keep the
  construct out of the supported subset or caveat it explicitly.
- If symbol kinds require public schema expansion, stop for planning rather
  than expanding the schema locally.
- If fixtures expose Markdown-sensitive names or paths, human output evidence
  must prove escaping before runtime output is later added.
- If query proof needs generated files not imported by Feature 0071, stop and
  reshape instead of silently expanding the BOM.

## Verification

Close-out must include evidence for:

```sh
git diff --check
zig build validate
zig build tree-sitter-rust-build-proof
zig build tree-sitter-rust-query-proof
fixture coverage proof
unsupported and degraded case proof
changed-path scan for query-proof-only scope
no-runtime-output scan
no-provider output stability check
privacy-safe this-repo smoke
privacy-safe sibling-local-repo smoke or bounded no-safe-file finding
```
