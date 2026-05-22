# Contributing

Thanks for your interest in `git-hotspots`. This repository is in a narrow
public alpha, so issues and small focused pull requests are welcome.

## Alpha contribution posture

- Open an issue for bugs, confusing output, missing docs, or focused feature
  proposals.
- Keep pull requests small and easy to review.
- Prefer deterministic local evidence over broad rewrites or speculative
  architecture.
- Do not add package publishing, release automation, CI, hosted-service plans,
  telemetry, upload behaviour, provider runtime, or cache requirements as part
  of an unrelated change.

## Before opening a pull request

Run the local validation workflow:

```sh
zig build validate
```

If a narrower change only needs the fast gate while iterating, `zig build test`
is useful, but `zig build validate` is the expected pre-PR check.

## Project boundaries

Runtime defaults must stay local-first: no network access, telemetry, upload,
remote enrichment, fetch, pull, or push by default.

Hotspots are investigation prompts from deterministic Git-history evidence.
Avoid claims that the tool predicts bugs, assigns objective code-quality
ratings, scores technical debt, ranks developers, judges maintainers, measures
productivity, or uses AI/LLM judgement as product truth.

During alpha, do not rely on long-term API or report-schema stability beyond
what an accepted issue or feature explicitly covers.
