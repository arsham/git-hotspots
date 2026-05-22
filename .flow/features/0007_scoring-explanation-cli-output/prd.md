# PRD: Scoring explanation CLI output

## Summary

Add a standalone static `git-hotspots --explain` output that explains how to
read current scores, confidence labels, caveats, and scope filters. The output
is documentation-like, deterministic, local-only, and does not require a Git
repository.

The feature must not change the scoring formula, Git analysis, filtering,
ranking, tie-breakers, or existing report schemas.

## Requirements

1. Add `--explain` as a standalone CLI mode.
2. `git-hotspots --explain` exits 0 outside a Git repository.
3. `--explain` writes deterministic static text to stdout and no stderr on success.
4. `--explain` must not run Git analysis, contact remotes, use cache, use providers, or require network access.
5. Combining `--explain` with analysis flags fails clearly on stderr.
6. Analysis flags that conflict with `--explain` are `--repo`, `--limit`, `--format`, `--since`, `--include-prefix`, and `--exclude-prefix`.
7. Help text documents `--explain`.
8. Default analysis behaviour remains unchanged when `--explain` is absent.
9. Existing table, JSON, and Markdown report outputs remain unchanged except for help/docs changes and validation additions.
10. The explanation describes hotspots as local Git-history investigation prompts.
11. The explanation says scores are not bug predictions.
12. The explanation says scores are not objective code-quality ratings.
13. The explanation says scores are not maintainer judgement or developer rankings.
14. The explanation says scores are not productivity analytics.
15. The explanation says scores are not AI or LLM judgement.
16. The explanation describes the current score components: frequency, churn, recency, cochange, and total.
17. The frequency explanation matches `src/scoring.zig`: `frequency = change_count * 10`.
18. The churn explanation matches `src/scoring.zig`: `churn = min((additions + deletions) / 25, 40)`.
19. The recency explanation matches `src/scoring.zig`: `recency = 20` at the selected head timestamp and otherwise decays by age in days to a floor of 0.
20. The cochange explanation matches `src/scoring.zig`: `cochange = min(cochange_total * 2, 20)`.
21. The total explanation matches `src/scoring.zig`: total is the sum of frequency, churn, recency, and cochange.
22. The explanation does not mention a size score because no size score exists today.
23. The confidence explanation matches `src/scoring.zig`: high requires at least three changes and no caveats.
24. The confidence explanation matches `src/scoring.zig`: medium requires at least two changes.
25. The confidence explanation matches `src/scoring.zig`: low is used otherwise.
26. The caveat explanation covers shallow history.
27. The caveat explanation covers partial/promisor history.
28. The caveat explanation covers dirty worktrees.
29. The caveat explanation covers binary or non-text churn that Git cannot count normally.
30. The caveat explanation covers large commits whose co-change evidence may be capped or caveated.
31. The caveat explanation covers deleted or not-present-at-HEAD paths.
32. The scope-filter explanation covers include prefixes as literal repo-relative prefixes.
33. The scope-filter explanation covers exclude prefixes as literal repo-relative prefixes.
34. The scope-filter explanation says filters apply before aggregation, scoring, co-change evidence, and limiting.
35. The scope-filter explanation says excludes win over includes.
36. The scope-filter explanation says scoped reports change the evidence universe.
37. The explanation output uses stable headings suitable for exact golden diffing.
38. The feature does not add a JSON explanation schema.
39. The feature does not add a subcommand, interactive mode, docs site, man page, or configurable weights.
40. The feature does not add providers, cache, telemetry, upload, fetch, network access, author metrics, release automation, CI automation, hosted-product content, or commercial strategy.

## Acceptance

- `git-hotspots --explain` is deterministic and works outside a Git repository.
- Invalid combinations with analysis flags fail clearly on stderr.
- Explanation text matches the current scoring and confidence implementation.
- Existing table, JSON, Markdown, include-prefix, and exclude-prefix behaviours remain stable.
- Canonical validation protects explain output and overclaiming boundaries.

## Edge cases

- `git-hotspots --explain --repo .` fails clearly.
- `git-hotspots --explain --format markdown` fails clearly.
- `git-hotspots --explain --include-prefix src/` fails clearly.
- `git-hotspots --explain --exclude-prefix .flow/` fails clearly.
- Running `git-hotspots --explain` from a non-git directory succeeds.
- Repeated `git-hotspots --explain` output is byte-identical.

## Verification

- `zig fmt --check build.zig src tests`
- `zig build test`
- `zig build run -- --help`
- exact diff against `fixtures/expected/explain.txt`
- repeated `--explain` diff
- invalid-combination stderr tests
- `zig build validate`
- close-out validation mode with a privacy-safe sibling repo label or explicit skip reason
- `git diff --check`
- `flow validate --target feature:0007 --format json` when Flow is available

## Public documentation

Update `README.md` with a compact "How to read scores" section that mirrors the
CLI explanation. Keep it visitor-facing and avoid Flow/process details.

## Non-goals

- Do not change scoring formulas, confidence thresholds, ranking, tie-breakers, Git analysis, scope filtering, or report schemas.
- Do not add a per-repo explanation mode.
- Do not add a machine-readable explanation schema.
- Do not add a docs site, man page, templates, or interactive tutorial.
- Do not add commercial, hosted, pricing, sales, or SaaS content.
