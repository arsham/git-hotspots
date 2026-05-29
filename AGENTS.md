# Agent guidance

This repository is the OSS home for `git-hotspots`, a planned deterministic,
local-first hotspot intelligence CLI.

## Project boundaries

- Keep the public repository OSS/publicity-oriented.
- Do not add monetisation plans, pricing, hosted product strategy, or sales
  strategy to repo artefacts.
- Treat hotspots as investigation prompts, not accusations, bug predictions,
  code-quality scores, or developer-performance metrics.
- Runtime defaults should remain local-first: no network access, telemetry,
  background upload, or remote enrichment by default.
- Agent-ready exports may help users feed their own tools, but runtime product
  truth must remain deterministic evidence.

## Implementation direction

- First useful layer: file-level Git-history evidence.
- Start with churn, change frequency, recency, co-change, size, confidence, and
  explainable evidence.
- Providers come later as optional enrichers. Possible providers include
  tree-sitter, LSP, ctags, dependency data, blame/history, and test or coverage
  data.
- Cache is a future optimisation, not product truth. The tool should work
  without cache.

## Public documentation

- Keep `README.md` polished and visitor-facing.
- Keep internal planning/process detail out of the README.
- Prefer project-relative paths in examples and shareable output.
- Avoid claims that the tool predicts bugs, judges maintainers, or ranks
  developers.
- When changing CLI parsing, help, or diagnostic wording, update
  `tests/integration.sh`, `tools/validate.sh`, `README.md`,
  `docs/user-guide.md`, `docs/developer-guide.md`, and `man/git-hotspots.1`
  together.

## Working style

- Make small, reviewable changes.
- Do not add build/package scaffolding unless the active feature asks for it.
- For implementation features, include real-repository smoke validation once an
  executable exists; default to this repo plus one suitable sibling/local repo,
  and record privacy-safe evidence without committing absolute local paths or
  raw private report output.
- Before Flow close-out, run `tools/flow-closeout-check.sh` with a
  privacy-safe second smoke repo or explicit skip reason.
- Preserve existing Flow state when present; use Flow commands for lifecycle
  updates instead of hand-editing Flow artefacts when a command exists.
