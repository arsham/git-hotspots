# PRD: Tree-sitter Python grammar admission review

## Problem

The Tree-sitter language strategy identifies Python as the next candidate after
Go. Python has broad user value, but Python parsing and symbol mapping carry
language-specific risks: indentation-sensitive syntax, decorators, nested
functions and classes, dynamic assignments, generated files, and project/module
conventions.

The repository must not import or run `tree-sitter-python` before provenance,
license, generated parser/scanner, compatibility, BOM, query, fixture, and
local-first gates are recorded.

## Goals

- Add one documentation-only admission artefact:

  ```text
  docs/tree-sitter-python-grammar-admission.md
  ```

- Record the gates that must pass before Python source import, build proof,
  extraction proof, or runtime provider output.
- Preserve the staged language-expansion sequence proven by Go.
- Keep Python support clearly marked as not implemented.

## Non-goals

- No `third_party/tree-sitter-python` source import.
- No `build.zig`, `build.zig.zon`, CI, test, fixture, source, provider registry,
  CLI, report schema, scoring, cache, release, package, network, telemetry,
  upload, remote enrichment, or runtime provider behaviour changes.
- No Python parser build proof, extraction proof, inspect output, custom query
  execution, LSP, type inference, import/module resolution, virtual environment
  discovery, pyproject parsing, dependency graph, notebook handling, or repo-wide
  scan.

## Requirements

1. The admission document records public upstream candidate identity for
   `tree-sitter-python`.
2. The document records that immutable revision, checksum, license, and notice
   conclusions must be refreshed against the exact future selected revision.
3. The document defines generated parser and scanner provenance gates, including
   how external scanner presence or absence must be proved.
4. The document defines Tree-sitter core ABI compatibility gates against the
   already vendored core.
5. The document defines a narrow future BOM and excluded file classes.
6. The document defines source-size and build-impact gates for the future source
   import.
7. The document defines Python symbol query fixture expectations for modules,
   classes, functions, methods, constants, decorators, nested definitions,
   indentation errors, dynamic assignments, generated files, empty files,
   invalid files, and unsupported paths.
8. The document states monorepo behaviour is inspect-path-only and extension-
   based; it must not imply package, venv, workspace, pyproject, dependency
   graph, import resolution, notebook, or repo-wide scanning.
9. The document states that Python runtime support is not implemented.
10. The document preserves local-first and OSS/publicity boundaries.

## Verification

Required validation commands:

```sh
git diff --check
zig build validate
```

Close-out must also prove:

- changed paths are docs/Flow only;
- no `third_party/tree-sitter-python` path was added;
- no runtime/source/test/build/fixture/CI files changed;
- no public claim says Python support exists;
- prohibited-claim and privacy scans pass; and
- future sequencing is explicit.
