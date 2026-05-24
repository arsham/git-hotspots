# PRD: Inspect-only Go symbol line-history evidence

## Problem

Feature 0039 added inspect-only Go symbol output. Feature 0029 already added
current-line Git evidence for inspected symbols, but that path is effectively
Zig-only in user-facing behaviour. Go users can inspect current symbols in a hot
file but cannot ask which current symbol ranges carry current-line Git evidence.

This creates an artificial provider split even though the underlying evidence
model is provider-neutral. The feature should close that gap without claiming
true symbol history or adding package-aware Go analysis.

## Goals

- Enable current-line Git evidence for inspected Go symbols through the existing
  opt-in flag combination:

  ```sh
  git-hotspots --inspect path.go --symbols --symbol-line-history
  ```

- Reuse the existing provider-neutral current-line blame/range model.
- Preserve file-level Git evidence as product truth.
- Keep the evidence framed as current-line Git evidence at HEAD, not symbol
  history, ownership, risk, quality, or ranking.
- Preserve existing no-provider, Zig symbol, Zig line-history, and plain Go
  symbol behaviours unless the change is explicitly scoped and validated.

## Non-goals

- No `git log -L`.
- No true symbol history, symbol lineage, symbol move tracking, or historical
  function identity.
- No authors, emails, commit messages, source snippets, diffs, raw blame output,
  previous filenames, ownership analytics, developer productivity metrics, risk
  scoring, or quality scoring.
- No Go package loading, module analysis, build-tag evaluation, cgo analysis,
  dependency graph, LSP, custom queries, provider registry expansion, cache,
  network access, telemetry, upload, remote enrichment, or repo-wide provider
  execution.
- No new report schema fields unless existing optional line-history fields are
  reused.

## Requirements

1. `--symbol-line-history` remains valid only with `--inspect PATH --symbols`.
2. For `.go` inspected paths, successful Go symbols receive current-line Git
   evidence when `--symbol-line-history` is present.
3. The evidence basis is current matched file plus current one-based inclusive
   symbol line ranges at HEAD.
4. Go symbol output without `--symbol-line-history` remains stable.
5. Existing Zig symbol line-history behaviour remains stable.
6. Shallow and partial repositories add explicit caveats and never auto-fetch.
7. Dirty inspected Go files degrade without invented pseudo-commit evidence.
8. Dirty unrelated files do not block evidence for the inspected Go path.
9. Unsupported, empty, invalid, unavailable, missing-current, symlink, and
   too-large Go cases degrade safely.
10. Go caveats must mention relevant range limitations, including grouped
    const/var ranges, bare method names, and build-tag/generated/cgo non-
    evaluation where applicable.
11. Table, JSON, and Markdown include deterministic Go current-line evidence
    goldens.
12. Privacy and prohibited-claim scans include all new Go line-history outputs.
13. Real-repo close-out smoke uses privacy-safe labels only and must honestly
    state when the sibling repo has no safe tracked Go file.

## Edge cases

- Go package/module symbols may receive line evidence if they have a current
  symbol range; this is still current-line evidence and must not be described as
  package history.
- Grouped const and var names may share enclosing declaration ranges and must be
  caveated if needed.
- Generated/build-tag/cgo-adjacent examples remain parsed as current source only;
  the tool does not evaluate those Go semantics.
- Rename aliases should resolve through the inspect path resolution already
  implemented by file-level evidence. Evidence remains attached to the matched
  current file.

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
git diff --check
```

Close-out validation must also run:

```sh
zig build validate -Dcloseout=true -Dsmoke-repo=<operator-sibling-repo> -Dsmoke-label=sibling-local-repo
```

Close-out evidence must include deterministic Go line-history goldens, repeated
output checks, no-flag stability checks, privacy/prohibited scans, this-repo
smoke, and sibling-local-repo smoke or an honest bounded statement that no safe
tracked Go file exists there.
