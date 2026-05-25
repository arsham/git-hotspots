# PRD: Tree-sitter JavaScript grammar admission review

## Problem

JavaScript is a high-value Tree-sitter candidate, but it is riskier than the Go
and Python tracks already implemented. A JavaScript provider must account for
CommonJS, ESM, JSX, anonymous exports, generated bundles, multiple path
extensions, and Node monorepo context without implying package-manager or
workspace discovery.

The repository must not import or run `tree-sitter-javascript` before upstream
identity, license, generated parser or scanner provenance, compatibility, BOM,
query, fixture, monorepo, and local-first gates are recorded.

## Goals

- Add one documentation-only admission artefact:

  ```text
  docs/tree-sitter-javascript-grammar-admission.md
  ```

- Record gates that must pass before JavaScript source import, build proof,
  extraction proof, inspect output, or line-history output.
- Decide whether JSX is admitted with JavaScript or deferred.
- Keep JavaScript support clearly marked as not implemented.

## Non-goals

- No `third_party/tree-sitter-javascript` source import.
- No `build.zig`, `build.zig.zon`, CI, test, fixture, source, provider registry,
  CLI, report schema, scoring, cache, release, package, network, telemetry,
  upload, remote enrichment, or runtime provider behaviour changes.
- No JavaScript parser build proof, extraction proof, inspect output, line
  history, custom query execution, LSP, package.json parsing, workspace
  discovery, module resolution, dependency graph, bundler analysis, or repo-wide
  scan.
- No `node` provider identity. Node remains runtime context only.

## Requirements

1. The admission document records public upstream candidate identity for
   `tree-sitter-javascript`.
2. The document records that immutable revision, checksum, license, and notice
   conclusions must be refreshed against the exact future selected revision.
3. The document defines generated parser and scanner provenance gates.
4. The document defines Tree-sitter core ABI compatibility gates against the
   already vendored core.
5. The document defines JavaScript path rules for `.js`, `.mjs`, `.cjs`, and
   `.jsx`, and explicitly decides whether `.jsx` is admitted or deferred.
6. The document defines a narrow future BOM and excluded file classes.
7. The document defines source-size and build-impact gates for the future source
   import.
8. The document defines JavaScript query fixture expectations for functions,
   classes, methods, constants, variables, ESM exports, CommonJS exports,
   anonymous exports, JSX if admitted, generated bundles, empty files, invalid
   files, unsupported paths, and monorepo paths.
9. The document states monorepo behaviour is inspect-path-only and extension-
   based; it must not imply package.json, workspace, bundler, dependency graph,
   module resolution, LSP, or repo-wide scanning.
10. The document states that JavaScript runtime support is not implemented.
11. The document preserves local-first and OSS/publicity boundaries.

## Verification

Required validation commands:

```sh
git diff --check
zig build validate
```

Close-out must also prove:

- changed paths are docs/Flow only;
- no `third_party/tree-sitter-javascript` path was added;
- no runtime/source/test/build/fixture/CI files changed;
- no public claim says JavaScript support exists;
- Node is described only as runtime context, not a provider;
- prohibited-claim and privacy scans pass; and
- future sequencing is explicit.
