# Feature 0061: TypeScript/TSX symbol line-history evidence

## Problem

Feature 0060 adds inspect-only TypeScript/TSX symbol output. Existing
provider-neutral line-history support can attach current-line Git evidence to
inspected symbols for other supported languages. TypeScript and TSX users can
inspect current symbols in a hot file, but cannot yet ask which current
TypeScript/TSX symbol ranges carry current-line Git evidence.

This creates an artificial provider split even though the underlying evidence
model is provider-neutral. The feature should close that gap without claiming
true symbol history, TypeScript type history, package/module analysis, tsconfig
analysis, or Node runtime behaviour.

## Goals

- Enable current-line Git evidence for inspected TypeScript/TSX symbols through
  the existing opt-in flag combination:

  ```sh
  git-hotspots --inspect path.ts --symbols --symbol-line-history
  git-hotspots --inspect path.tsx --symbols --symbol-line-history
  ```

- Reuse the existing provider-neutral current-line blame/range model.
- Preserve file-level Git evidence as product truth.
- Keep the evidence framed as current-line Git evidence at HEAD, not symbol
  history, ownership, risk, quality, ranking, or type-aware lineage.
- Preserve existing no-provider, Zig, Go, Python, JavaScript, and plain
  TypeScript/TSX symbol behaviours unless the change is explicitly scoped and
  validated.

## Non-goals

- No `git log -L`.
- No true symbol history, symbol lineage, symbol move tracking, historical
  function identity, type history, or declaration-merge history.
- No authors, emails, commit messages, source snippets, diffs, raw blame
  output, previous filenames, ownership analytics, developer productivity
  metrics, risk scoring, or quality scoring.
- No TypeScript package loading, Node execution, `package.json` parsing,
  workspace discovery, bundler analysis, module resolution, dependency graph,
  tsconfig interpretation, type checking, LSP, custom queries, provider registry
  expansion beyond Feature 0060, cache, network access, telemetry, upload,
  remote enrichment, or repo-wide provider execution.
- No new report schema fields unless existing optional line-history fields are
  reused.

## Requirements

1. `--symbol-line-history` remains valid only with `--inspect PATH --symbols`.
2. For `.ts`, `.tsx`, `.mts`, and `.cts` inspected paths, successful
   TypeScript/TSX symbols receive current-line Git evidence when
   `--symbol-line-history` is present.
3. The evidence basis is current matched file plus current one-based inclusive
   symbol line ranges at HEAD.
4. TypeScript/TSX symbol output without `--symbol-line-history` remains stable.
5. Existing Zig, Go, Python, and JavaScript symbol line-history behaviour
   remains stable.
6. Existing no-provider and unsupported-provider behaviour remains stable.
7. Shallow and partial repositories add explicit caveats and never auto-fetch.
8. Dirty inspected TypeScript/TSX files degrade without invented pseudo-commit
   evidence.
9. Dirty unrelated files do not block evidence for the inspected TypeScript/TSX
   path.
10. Unsupported, empty, invalid, unavailable, missing-current, symlink, and
    too-large TypeScript/TSX cases degrade safely.
11. TypeScript/TSX caveats must mention relevant range limitations, including
    JSX, exports, CommonJS assignments, anonymous symbols, generated/minified
    files, dynamic constructs, package/module non-evaluation, Node
    non-evaluation, tsconfig non-evaluation, and type-checking absence where
    applicable.
12. Table, JSON, and Markdown include deterministic TypeScript/TSX current-line
    evidence goldens.
13. Privacy and prohibited-claim scans include all new TypeScript/TSX
    line-history outputs.
14. Real-repo close-out smoke uses privacy-safe labels only and must honestly
    state when the sibling repo has no safe tracked TypeScript or TSX file.
15. Output must not claim ownership, risk prediction, code quality,
    developer-performance metrics, or historical symbol identity.
16. The provider must continue to parse only the inspected file and must not run
    during default reports or non-symbol inspect reports.

## Edge cases

- TypeScript module symbols may receive line evidence if they have a current
  symbol range; this is still current-line evidence and must not be described as
  module history.
- TSX components use the current ranges from the TSX symbol provider and must
  carry caveats where needed.
- Exported, re-exported, CommonJS-assigned, interface, type-alias, enum,
  namespace, decorator, overload, and declaration-merge cases use current ranges
  from the TypeScript/TSX provider and must not imply type-aware or
  module-resolution knowledge.
- Generated/minified and dynamic examples remain parsed as current source only;
  the tool does not evaluate TypeScript or JavaScript semantics.
- Rename aliases should resolve through the inspect path resolution already
  implemented by file-level evidence. Evidence remains attached to the matched
  current file.
- Unsupported non-TypeScript/TSX files must not be parsed or caveated as
  TypeScript/TSX line-history evidence.

## Verification

Required validation commands:

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
```

Close-out validation must also run:

```sh
zig build validate -Dcloseout=true -Dsmoke-repo=<operator-sibling-repo> -Dsmoke-label=sibling-local-repo
```

Close-out evidence must include deterministic TypeScript and TSX line-history
goldens, repeated output checks, no-flag stability checks, legacy provider
line-history stability checks, privacy/prohibited scans, this-repo smoke, and
sibling-local-repo smoke or an honest bounded statement that no safe tracked
TypeScript/TSX file exists there.
