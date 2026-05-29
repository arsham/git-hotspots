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

This checkout uses the repository hooks in `.githooks/`.
Enable it with:

```sh
git config core.hooksPath .githooks
```

The commit hook runs staged whitespace checks and `zig build pre-commit`
before a commit is created. The push hook runs `zig build validate-all` once
for non-delete pushes.

Run the local validation workflow:

```sh
zig build validate
```

If a narrower change only needs the fast gate while iterating, use:

```sh
zig build pre-commit
```

`zig build validate` remains the expected pre-PR check.

Provider-lane changes should also run the full local proof aggregate:

```sh
zig build validate-all
```

The current public Validation workflow runs validation plus representative
Tree-sitter proof coverage on pushes to `master` and pull requests. Local
validation remains the source of truth for contributors. Run
`zig build validate-all` when touching provider lanes or proof wiring.

## Project boundaries

Runtime defaults must stay local-first: no network access, telemetry, upload,
remote enrichment, fetch, pull, or push by default.

Hotspots are investigation prompts from deterministic Git-history evidence.
Avoid claims that the tool predicts bugs, assigns objective code-quality
ratings, scores technical debt, ranks developers, judges maintainers, measures
productivity, or uses AI/LLM judgement as product truth.

During alpha, do not rely on long-term API or report-schema stability beyond
what an accepted issue or feature explicitly covers.

## Architecture guide

`git-hotspots` has a small deterministic core. Local Git-history evidence is
collected first, scored into investigation prompts, and then optional
current-file providers may attach enrichment for inspected files. Providers do
not change score, rank, confidence, lineage, or product truth.

For the fuller contributor reference, see
[`docs/developer-guide.md`](docs/developer-guide.md).

The contributor-facing pipeline is:

```text
CLI args -> local Git evidence -> scoring/confidence -> optional enrichment -> deterministic reports
```

Use these module boundaries when changing the code:

- `cli.zig` owns arguments, usage text, and user-facing CLI validation.
- `app.zig` owns orchestration from parsed config to rendered output.
- `git.zig` owns local Git evidence and remains the public Git-analysis facade.
- `scoring.zig` owns deterministic ranking and confidence rules.
- `provider.zig` owns provider evidence contracts and current-only semantics.
- `provider_selection.zig` chooses the bounded inspect-only symbol provider for
  a path; it is not a runtime plugin framework.
- `tree_sitter_*.zig` modules own language-specific current-symbol semantics.
- `report.zig` owns deterministic table, JSON, and Markdown output.

Keep new abstractions boring and local. If a change needs cache, config,
network access, runtime plugins, report schema changes, or provider influence on
ranking, shape it as an explicit feature instead of hiding it inside cleanup.
