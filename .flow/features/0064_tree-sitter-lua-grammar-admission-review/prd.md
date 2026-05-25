# PRD: Tree-sitter Lua grammar admission review

## Problem

Lua is one of the original language interests and is likely simpler than Rust,
but a future provider still needs an admission record before source import or
runtime work. Lua symbol extraction must handle global functions, local
functions, table-field functions, method-call syntax, modules-as-tables, and
common test/config path patterns without implying runtime execution, module
resolution, package loading, dependency analysis, LSP, or repo-wide symbol scans.

The repository must not import or run `tree-sitter-lua` before upstream identity,
license, generated parser provenance, compatibility, BOM, query, fixture,
monorepo, and local-first gates are recorded.

## Goals

- Add one documentation-only admission artefact:

  ```text
  docs/tree-sitter-lua-grammar-admission.md
  ```

- Record gates that must pass before Lua source import, build proof, extraction
  proof, inspect output, or line-history output.
- Decide the initial Lua symbol subset and explicitly defer runtime/module
  analysis.
- Keep Lua support clearly marked as not implemented.

## Non-goals

- No `third_party/tree-sitter-lua` source import.
- No `build.zig`, `build.zig.zon`, CI, test, fixture, source, provider registry,
  CLI, report schema, scoring, cache, release, package, network, telemetry,
  upload, remote enrichment, or runtime provider behaviour changes.
- No Lua parser build proof, extraction proof, inspect output, line history,
  custom query execution, require/module resolution, package path analysis,
  runtime execution, LSP, dependency graph, or repo-wide scan.

## Requirements

1. The admission document records public upstream candidate identity for
   `tree-sitter-lua`.
2. The document records that immutable revision, checksum, license, and notice
   conclusions must be refreshed against the exact future selected revision.
3. The document defines generated parser provenance gates and any scanner or
   external scanner gates if present.
4. The document defines Tree-sitter core ABI compatibility gates against the
   already vendored core.
5. The document defines Lua path rules for `.lua` files only.
6. The document defines the initial future symbol subset, including local
   functions, global functions, table-field functions, method definitions using
   colon syntax, and module-table patterns only when they can be represented
   syntactically.
7. The document defines caveats for dynamic table assignment, metatables,
   generated Lua, embedded DSLs, and module patterns.
8. The document defines a narrow future BOM and excluded file classes.
9. The document defines source-size and build-impact gates for the future source
   import.
10. The document defines Lua query fixture expectations for local functions,
    global functions, table-field functions, colon-method functions, anonymous
    functions assigned to names, module-like tables, comments/strings that look
    like code, empty files, invalid files, unsupported paths, and monorepo paths.
11. The document states monorepo behaviour is inspect-path-only and extension-
    based; it must not imply require/module resolution, package path analysis,
    runtime execution, LSP, dependency graph, or repo-wide scanning.
12. The document states that Lua runtime support is not implemented.
13. The document preserves local-first and OSS/publicity boundaries.

## Verification

Required validation commands:

```sh
git diff --check
zig build validate
```

Close-out must also prove:

- changed paths are docs/Flow only;
- no `third_party/tree-sitter-lua` path was added;
- no runtime/source/test/build/fixture/CI files changed;
- no public claim says Lua support exists;
- prohibited-claim and privacy scans pass; and
- future sequencing is explicit.
