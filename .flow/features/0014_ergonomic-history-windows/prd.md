# Feature 0014: Large-repo history recipes

## Summary

Document practical large-repository command recipes using the existing
`--since REV`, `--scope`, `--include-prefix`, and `--progress` options. This
feature deliberately does not add named history-window syntax yet.

The goal is to help users get faster, focused, deterministic reports on large
repositories without changing the product contract that an unqualified run uses
full reachable local Git history.

## Problem

Feature 0013 added opt-in progress feedback for long runs. Real-repo validation
showed that large repositories can still take noticeably longer when analysing
all reachable history. Users need guidance for choosing smaller evidence
windows and source-focused scopes using the CLI surface that already exists.

The README currently documents `--since` as an option, but it does not provide
large-repo recipes or explain that existing Git revision syntax can be used to
bound history deterministically.

## Outcome

Add a concise public documentation section with large-repo recipes. The section
must explain that:

- omitting `--since` keeps full-history behaviour;
- `--since REV` means analyse `REV..HEAD` using Git revision syntax;
- bounded examples such as `HEAD~500` and `HEAD~1000` are deterministic and
  useful for faster exploratory runs;
- `--scope project` and `--include-prefix` can focus reports before heavier
  future features such as cache or providers exist;
- `--progress` gives stderr-only feedback during long local analysis.

No runtime CLI behaviour changes in this feature.

## In scope

- README large-repository recipe section.
- Optional refresh to `docs/real-repo-validation.md` only if it improves the
  explanation of existing evidence without adding private details.
- Optional project memory note that named history windows are deferred, not
  rejected.
- Validation that docs remain public, non-commercial, non-judgemental, and
  consistent with current CLI behaviour.

## Out of scope

- Named history-window syntax such as `--since last-30d`, `--since 12m`, or
  `--since recent`.
- Changing the default history range.
- Date, duration, or calendar parsing.
- Repo-size auto-windowing.
- Cache, streaming history ingestion, provider work, CI, packaging, releases,
  telemetry, network access, or performance claims.
- Public third-party case studies or raw sibling-repo output.

## Deferred design note

Named history windows remain a possible future feature. Before implementing
them, the project must decide exact deterministic semantics, including whether
windows are anchored to the analysed `HEAD` timestamp, how fixed-day cutoffs are
computed, how Git refs with the same names are handled, and how boundary commits
are tested.

## Requirements

- README includes a section such as `Large repository recipes`.
- Recipes use existing supported options only.
- Recipes include at least:
  - a project-focused recent exploratory run using `--scope project`,
    `--since HEAD~500`, and `--progress`;
  - a source-focused run using `--include-prefix src/` and a bounded
    `--since` revision;
  - a full-history reminder explaining that omitting `--since` keeps full
    reachable local history.
- Docs do not imply that bounded runs are more correct than full-history runs;
  they are exploratory scopes.
- Docs do not claim speedups beyond reducing the selected history/output for an
  explicit bounded query.
- Docs preserve local-first, no-telemetry, no-network, non-judgemental framing.
- Existing CLI help and runtime behaviour remain unchanged unless validation
  exposes a documentation mismatch requiring a docs-only correction.

## Edge cases and cautions

- Do not recommend shell calendar expressions as product syntax.
- Do not use private local paths or raw sibling-repo output in committed docs.
- Do not introduce examples that require network access or remote fetching.
- Keep README visitor-facing; do not expose Flow process detail.

## Verification

Minimum validation before close-out:

- `zig build validate`
- `git diff --check`
- `git-hotspots --help` smoke, proving docs did not require unsupported flags.
- README scan for unsupported named history-window syntax as product syntax.
- README scan for commercial/SaaS/pricing/sales strategy.
- README scan for bug-prediction, objective quality-score, or developer-ranking
  claims.
- If `docs/real-repo-validation.md` changes, privacy scan proving no private
  path, repo name, remote URL, author identity, raw sibling output, commit
  message, or source snippet was added.

Close-out does not require sibling-repo smoke because this is a docs-only
feature and does not change runtime behaviour. The existing canonical
validation still includes this-repo smoke.
