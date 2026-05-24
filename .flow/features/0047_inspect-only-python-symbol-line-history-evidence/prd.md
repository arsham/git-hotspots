# PRD: Inspect-only Python symbol line-history evidence

## Problem

Feature 0046 adds inspect-only Python symbol output. Feature 0029 already added
current-line Git evidence for inspected symbols, and Features 0040 extended that
provider-neutral path to Go. Python users can inspect current symbols in a hot
file but cannot yet ask which current Python symbol ranges carry current-line
Git evidence.

This creates an artificial provider split even though the underlying evidence
model is provider-neutral. The feature should close that gap without claiming
true symbol history or adding Python package/import analysis.

## Goals

- Enable current-line Git evidence for inspected Python symbols through the
  existing opt-in flag combination:

  ```sh
  git-hotspots --inspect path.py --symbols --symbol-line-history
  ```

- Reuse the existing provider-neutral current-line blame/range model.
- Preserve file-level Git evidence as product truth.
- Keep the evidence framed as current-line Git evidence at HEAD, not symbol
  history, ownership, risk, quality, or ranking.
- Preserve existing no-provider, Zig symbol, Go symbol, Zig line-history, Go
  line-history, and plain Python symbol behaviours unless the change is
  explicitly scoped and validated.

## Non-goals

- No `git log -L`.
- No true symbol history, symbol lineage, symbol move tracking, or historical
  function identity.
- No authors, emails, commit messages, source snippets, diffs, raw blame output,
  previous filenames, ownership analytics, developer productivity metrics, risk
  scoring, or quality scoring.
- No Python package loading, import resolution, virtualenv discovery,
  `pyproject.toml` parsing, notebook handling, dependency graph, LSP, custom
  queries, provider registry expansion, cache, network access, telemetry,
  upload, remote enrichment, or repo-wide provider execution.
- No new report schema fields unless existing optional line-history fields are
  reused.

## Requirements

1. `--symbol-line-history` remains valid only with `--inspect PATH --symbols`.
2. For `.py` inspected paths, successful Python symbols receive current-line
   Git evidence when `--symbol-line-history` is present.
3. The evidence basis is current matched file plus current one-based inclusive
   symbol line ranges at HEAD.
4. Python symbol output without `--symbol-line-history` remains stable.
5. Existing Zig and Go symbol line-history behaviour remains stable.
6. Shallow and partial repositories add explicit caveats and never auto-fetch.
7. Dirty inspected Python files degrade without invented pseudo-commit evidence.
8. Dirty unrelated files do not block evidence for the inspected Python path.
9. Unsupported, empty, invalid, unavailable, missing-current, symlink, and
   too-large Python cases degrade safely.
10. Python caveats must mention relevant range limitations, including
    decorators, nested definitions, dynamic assignments, generated-file markers,
    package/import non-evaluation, virtualenv non-evaluation, and notebook
    non-support where applicable.
11. Table, JSON, and Markdown include deterministic Python current-line evidence
    goldens.
12. Privacy and prohibited-claim scans include all new Python line-history
    outputs.
13. Real-repo close-out smoke uses privacy-safe labels only and must honestly
    state when the sibling repo has no safe tracked Python file.

## Edge cases

- Python module symbols may receive line evidence if they have a current symbol
  range; this is still current-line evidence and must not be described as module
  history.
- Decorated and nested definitions use the current ranges from the Python symbol
  provider and must carry caveats where needed.
- Generated-file and dynamic-assignment examples remain parsed as current source
  only; the tool does not evaluate Python semantics.
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
zig build tree-sitter-python-build-proof
zig build tree-sitter-python-symbol-proof
git diff --check
```

Close-out validation must also run:

```sh
zig build validate -Dcloseout=true -Dsmoke-repo=<operator-sibling-repo> -Dsmoke-label=sibling-local-repo
```

Close-out evidence must include deterministic Python line-history goldens,
repeated output checks, no-flag stability checks, privacy/prohibited scans,
this-repo smoke, and sibling-local-repo smoke or an honest bounded statement
that no safe tracked Python file exists there.
