# PRD: Tree-sitter TypeScript grammar admission review

## Problem

TypeScript is a high-value Tree-sitter candidate, but it is broader than
JavaScript and carries extra risk around type-only constructs, declaration
files, enums, interfaces, decorators, TSX, multiple path extensions, and
possible multi-parser upstream layout.

The repository must not import or run `tree-sitter-typescript` before upstream
identity, license, generated parser or scanner provenance, compatibility, BOM,
query, fixture, monorepo, and local-first gates are recorded.

## Goals

- Add one documentation-only admission artefact:

  ```text
  docs/tree-sitter-typescript-grammar-admission.md
  ```

- Record gates that must pass before TypeScript source import, build proof,
  extraction proof, inspect output, or line-history output.
- Decide whether TSX is admitted with TypeScript or deferred.
- Keep TypeScript support clearly marked as not implemented.

## Non-goals

- No `third_party/tree-sitter-typescript` source import.
- No `build.zig`, `build.zig.zon`, CI, test, fixture, source, provider registry,
  CLI, report schema, scoring, cache, release, package, network, telemetry,
  upload, remote enrichment, or runtime provider behaviour changes.
- No TypeScript parser build proof, extraction proof, inspect output, line
  history, custom query execution, LSP, package.json parsing, tsconfig parsing,
  workspace discovery, module resolution, dependency graph, bundler analysis,
  or repo-wide scan.
- No `node` provider identity. Node remains runtime context only.

## Requirements

1. The admission document records public upstream candidate identity for
   `tree-sitter-typescript`.
2. The document records that immutable revision, checksum, license, and notice
   conclusions must be refreshed against the exact future selected revision.
3. The document defines generated parser and scanner provenance gates for
   TypeScript and TSX where applicable.
4. The document defines Tree-sitter core ABI compatibility gates against the
   already vendored core.
5. The document defines TypeScript path rules for `.ts`, `.mts`, `.cts`, and
   `.tsx`, and explicitly decides whether `.tsx` is admitted or deferred.
6. The document defines a narrow future BOM and excluded file classes.
7. The document defines source-size and build-impact gates for the future source
   import.
8. The document defines TypeScript query fixture expectations for functions,
   classes, methods, interfaces, type aliases, enums, type-only constructs,
   decorators, declaration files, TSX if admitted, empty files, invalid files,
   unsupported paths, and monorepo paths.
9. The document states monorepo behaviour is inspect-path-only and extension-
   based; it must not imply package.json, tsconfig, workspace, bundler,
   dependency graph, module resolution, LSP, or repo-wide scanning.
10. The document states that TypeScript runtime support is not implemented.
11. The document preserves local-first and OSS/publicity boundaries.

## Verification

Required validation commands:

```sh
git diff --check
zig build validate
```

Close-out must also prove:

- changed paths are docs/Flow only;
- no `third_party/tree-sitter-typescript` path was added;
- no runtime/source/test/build/fixture/CI files changed;
- no public claim says TypeScript support exists;
- Node is described only as runtime context, not a provider;
- prohibited-claim and privacy scans pass; and
- future sequencing is explicit.
