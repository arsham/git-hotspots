# PRD: Tree-sitter Rust grammar admission review

## Problem

Rust is a high-value Tree-sitter candidate and was part of the original Rust
experiment, but Rust syntax and symbol semantics are materially more complex
than Go, Python, JavaScript, or TypeScript. A future provider must account for
functions, methods, impl blocks, traits, modules, macros, generics, attributes,
and crate layout without implying type checking, cargo metadata loading, LSP,
macro expansion, dependency graph analysis, or repo-wide symbol scans.

The repository must not import or run `tree-sitter-rust` before upstream
identity, license, generated parser provenance, compatibility, BOM, query,
fixture, monorepo, and local-first gates are recorded.

## Goals

- Add one documentation-only admission artefact:

  ```text
  docs/tree-sitter-rust-grammar-admission.md
  ```

- Record gates that must pass before Rust source import, build proof,
  extraction proof, inspect output, or line-history output.
- Decide the initial Rust symbol subset and explicitly defer semantic Rust
  analysis.
- Keep Rust support clearly marked as not implemented.

## Non-goals

- No `third_party/tree-sitter-rust` source import.
- No `build.zig`, `build.zig.zon`, CI, test, fixture, source, provider registry,
  CLI, report schema, scoring, cache, release, package, network, telemetry,
  upload, remote enrichment, or runtime provider behaviour changes.
- No Rust parser build proof, extraction proof, inspect output, line history,
  custom query execution, Cargo.toml parsing, cargo metadata loading, crate graph
  analysis, macro expansion, type checking, LSP, dependency graph, or repo-wide
  scan.

## Requirements

1. The admission document records public upstream candidate identity for
   `tree-sitter-rust`.
2. The document records that immutable revision, checksum, license, and notice
   conclusions must be refreshed against the exact future selected revision.
3. The document defines generated parser provenance gates and any scanner or
   external scanner gates if present.
4. The document defines Tree-sitter core ABI compatibility gates against the
   already vendored core.
5. The document defines Rust path rules for `.rs` files only.
6. The document defines the initial future symbol subset, including functions,
   methods, impl items, traits, modules, structs, enums, and constants only when
   they can be represented without semantic Rust analysis.
7. The document defines macro, attribute, generic, trait, impl, module, and
   nested item caveats.
8. The document defines a narrow future BOM and excluded file classes.
9. The document defines source-size and build-impact gates for the future source
   import.
10. The document defines Rust query fixture expectations for freestanding
    functions, methods in impl blocks, trait methods, modules, structs, enums,
    const/static items, macro-heavy files, attributes, generics, empty files,
    invalid files, unsupported paths, and monorepo paths.
11. The document states monorepo behaviour is inspect-path-only and extension-
    based; it must not imply Cargo.toml, workspace, crate graph, dependency
    graph, macro expansion, type checking, LSP, or repo-wide scanning.
12. The document states that Rust runtime support is not implemented.
13. The document preserves local-first and OSS/publicity boundaries.

## Verification

Required validation commands:

```sh
git diff --check
zig build validate
```

Close-out must also prove:

- changed paths are docs/Flow only;
- no `third_party/tree-sitter-rust` path was added;
- no runtime/source/test/build/fixture/CI files changed;
- no public claim says Rust support exists;
- prohibited-claim and privacy scans pass; and
- future sequencing is explicit.
