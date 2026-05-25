# PRD: JavaScript symbol line-history evidence

## Problem

Feature 0054 adds inspect-only JavaScript symbol output. Feature 0029 already
added current-line Git evidence for inspected symbols, and Features 0040 and
0047 extended that provider-neutral path to Go and Python. JavaScript users can
inspect current symbols in a hot file but cannot yet ask which current
JavaScript symbol ranges carry current-line Git evidence.

This creates an artificial provider split even though the underlying evidence
model is provider-neutral. The feature should close that gap without claiming
true symbol history or adding JavaScript package/module/Node analysis.

## Goals

- Enable current-line Git evidence for inspected JavaScript symbols through the
  existing opt-in flag combination:

  ```sh
  git-hotspots --inspect path.js --symbols --symbol-line-history
  ```

- Reuse the existing provider-neutral current-line blame/range model.
- Preserve file-level Git evidence as product truth.
- Keep the evidence framed as current-line Git evidence at HEAD, not symbol
  history, ownership, risk, quality, or ranking.
- Preserve existing no-provider, Zig symbol, Go symbol, Python symbol, Zig
  line-history, Go line-history, Python line-history, and plain JavaScript
  symbol behaviours unless the change is explicitly scoped and validated.

## Non-goals

- No `git log -L`.
- No true symbol history, symbol lineage, symbol move tracking, or historical
  function identity.
- No authors, emails, commit messages, source snippets, diffs, raw blame output,
  previous filenames, ownership analytics, developer productivity metrics, risk
  scoring, or quality scoring.
- No JavaScript package loading, Node execution, `package.json` parsing,
  workspace discovery, bundler analysis, module resolution, dependency graph,
  LSP, custom queries, TypeScript, TSX, provider registry expansion, cache,
  network access, telemetry, upload, remote enrichment, or repo-wide provider
  execution.
- No new report schema fields unless existing optional line-history fields are
  reused.

## Requirements

1. `--symbol-line-history` remains valid only with `--inspect PATH --symbols`.
2. For `.js`, `.mjs`, `.cjs`, and admitted `.jsx` inspected paths, successful
   JavaScript symbols receive current-line Git evidence when
   `--symbol-line-history` is present.
3. If `.jsx` was deferred by earlier JavaScript features, `.jsx` must remain
   unsupported and must not receive invented line-history support.
4. The evidence basis is current matched file plus current one-based inclusive
   symbol line ranges at HEAD.
5. JavaScript symbol output without `--symbol-line-history` remains stable.
6. Existing Zig, Go, and Python symbol line-history behaviour remains stable.
7. Shallow and partial repositories add explicit caveats and never auto-fetch.
8. Dirty inspected JavaScript files degrade without invented pseudo-commit
   evidence.
9. Dirty unrelated files do not block evidence for the inspected JavaScript
   path.
10. Unsupported, empty, invalid, unavailable, missing-current, symlink, and
    too-large JavaScript cases degrade safely.
11. JavaScript caveats must mention relevant range limitations, including JSX,
    exports, CommonJS assignments, anonymous symbols, generated/minified files,
    dynamic constructs, package/module non-evaluation, Node non-evaluation,
    TypeScript non-support, and TSX non-support where applicable.
12. Table, JSON, and Markdown include deterministic JavaScript current-line
    evidence goldens.
13. Privacy and prohibited-claim scans include all new JavaScript line-history
    outputs.
14. Real-repo close-out smoke uses privacy-safe labels only and must honestly
    state when the sibling repo has no safe tracked JavaScript file.

## Edge cases

- JavaScript module symbols may receive line evidence if they have a current
  symbol range; this is still current-line evidence and must not be described as
  module history.
- JSX components use the current ranges from the JavaScript symbol provider and
  must carry caveats where needed.
- Exported and CommonJS-assigned symbols use current ranges from the JavaScript
  provider and must not imply module-resolution knowledge.
- Generated/minified and dynamic examples remain parsed as current source only;
  the tool does not evaluate JavaScript semantics.
- Rename aliases should resolve through the inspect path resolution already
  implemented by file-level evidence. Evidence remains attached to the matched
  current file.
- Unsupported TypeScript and TSX files must not be parsed or caveated as
  JavaScript line-history evidence.

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
git diff --check
```

Close-out validation must also run:

```sh
zig build validate -Dcloseout=true -Dsmoke-repo=<operator-sibling-repo> -Dsmoke-label=sibling-local-repo
```

Close-out evidence must include deterministic JavaScript line-history goldens,
repeated output checks, no-flag stability checks, privacy/prohibited scans,
this-repo smoke, and sibling-local-repo smoke or an honest bounded statement
that no safe tracked JavaScript file exists there.
