# PRD: Scope filters for useful hotspot reports

## Summary

Add explicit path-prefix filtering to the file-level CLI so users can produce
focused reports without silently hiding evidence. The first scope-control slice
is repeatable `--exclude-prefix PATH` using repo-relative literal prefix
semantics. Defaults remain unfiltered.

This feature exists because the current self-smoke report works but is dominated
by `.flow/*` lifecycle artefacts. Users need a visible, deterministic way to
exclude known workflow or generated paths when preparing source-oriented reports
or public demos.

## Goals

- Provide explicit user-controlled path exclusion for file-level hotspot reports.
- Keep the default evidence universe unfiltered unless the user supplies filters.
- Apply filters before aggregation, ranking, limiting, and co-change evidence.
- Disclose active scope and exclusion counts in table and JSON output.
- Keep reports local-first, deterministic, project-relative, and privacy-safe.
- Extend validation so scope-filter regressions are caught by `zig build validate`.

## Non-goals

- No default project scope or built-in default exclusions in this feature.
- No include flags, glob syntax, pathspec compatibility, or `.gitignore` import.
- No config files, rule engines, or project-type detection.
- No providers, tree-sitter, LSP, ctags, cache/database work, release packaging,
  GitHub Actions, network access, telemetry, author metrics, hosted strategy, or
  commercial content.
- No scoring formula redesign beyond changing the candidate set when filters are
  active.
- No claims that filtered hotspots predict bugs, score code quality, or judge
  developers.

## Requirements

1. The CLI accepts repeatable `--exclude-prefix PATH` flags.
2. Prefixes are interpreted as repo-relative literal Git path prefixes using `/`
   separators, not globs or regular expressions.
3. Empty prefixes fail clearly on stderr.
4. Absolute prefixes fail clearly on stderr.
5. Prefixes containing parent-traversal segments such as `..` fail clearly on
   stderr.
6. Prefixes containing NUL or dangerous control characters fail clearly on
   stderr.
7. Existing flags `--repo`, `--limit`, `--format`, `--since`, and `--help` remain
   compatible.
8. With no exclude prefixes, default output remains unfiltered and deterministic.
9. Filtering is applied before file stats are aggregated.
10. Filtering is applied before score calculation.
11. Filtering is applied before co-change pair calculation.
12. Filtering is applied before `--limit` is applied.
13. Excluded paths never appear in JSON `results[].path`.
14. Excluded paths never appear in JSON `results[].cochanges[].path`.
15. Excluded paths never appear as table result rows.
16. Empty scoped result sets produce a successful report with clear scope/caveat
    information, not an empty-repository or non-git error.
17. Deleted files that remain in scope keep current deleted-file behaviour, such
    as missing size and deletion caveats.
18. Deleted files under excluded prefixes are excluded from results and co-change
    evidence.
19. Renamed paths are filtered according to the path recorded in the current
    change event model; the implementation must document any limitation rather
    than inventing perfect rename semantics.
20. JSON output includes `analysis.scope` metadata.
21. `analysis.scope` includes whether filters are active.
22. `analysis.scope` includes supplied `exclude_prefixes` in deterministic order.
23. `analysis.scope` includes deterministic `excluded_path_count`.
24. `analysis.scope` includes deterministic `excluded_change_count` or equivalent
    filtered-change count.
25. JSON output contains no absolute local paths, private repository names, raw
    private report dumps, author identities, author emails, remote URLs, or raw
    excluded path dumps by default.
26. Table output includes a compact scope line when filters are active.
27. Table output keeps paths project-relative.
28. Scope metadata must be rendered from the same analysis model as JSON, not
    recomputed separately in the reporter.
29. README documents the flag and no-glob prefix semantics.
30. README includes a scoped example, such as excluding `.flow/` for a
    source-oriented public/demo report.
31. README explains that filters change the evidence universe and should be used
    deliberately.
32. README remains visitor-facing and does not expose Flow process details.
33. Help output documents `--exclude-prefix` without commercial or hosted
    strategy language.
34. The feature introduces no network, fetch, pull, push, upload, telemetry,
    remote enrichment, provider runtime, cache requirement, release automation,
    or CI service dependency.
35. The feature introduces no author/developer metrics.

## Edge cases

- `.flow/` with high churn should be removable from this repository's scoped
  output by passing `--exclude-prefix .flow/`.
- Default unfiltered output should still be able to show `.flow/` paths.
- A fixture should include a normal source path such as `src/app.zig` and a
  high-churn workflow path such as `.flow/state.yaml`.
- Paths with spaces, unicode, tabs, and glob-looking characters should behave as
  literal paths.
- Prefixes such as `vendor/` should not exclude `src/vendor_adapter.zig` unless
  the prefix literally matches the beginning of the Git path.
- Excluded-only ranges selected by `--since` should produce an empty scoped
  report, not an error.
- Invalid `--since` remains an error regardless of filters.
- Large commits mixing included and excluded paths should not leak excluded paths
  into co-change summaries.
- Filter counters should stay bounded and deterministic; do not print full
  excluded path lists by default.

## Validation

Implementation close-out must include:

- `zig fmt --check build.zig src tests`
- `zig build test`
- `zig build validate`
- `git diff --check`
- clear stderr tests for invalid prefixes
- fixture tests proving default unfiltered output and scoped filtered output
- fixture tests proving excluded paths do not appear in results or cochanges
- deterministic JSON diff with active filters
- empty scoped report test
- real-repository smoke on this repo proving `--exclude-prefix .flow/` removes
  `.flow/**` rows and co-change evidence
- close-out sibling/local repo smoke through the existing validation workflow, or
  an explicit privacy-safe skip reason
- `flow validate --target feature:0004 --format json`

Validation evidence must remain privacy-safe: labels and counts are acceptable;
absolute local paths, private repo names, raw private reports, source snippets,
author identities, author emails, and remote URLs are not.

## Acceptance

The feature is done when a future runner can execute the canonical validation
workflow and prove that explicit prefix filtering is deterministic, transparent,
local-only, privacy-safe, and useful for source-oriented reports without changing
unfiltered default behaviour.
