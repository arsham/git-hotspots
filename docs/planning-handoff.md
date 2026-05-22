# Development snapshot

This snapshot lets a future planner continue without relying on the original
chat. It records current project state after the initial CLI spike and points at
remaining candidate seams without choosing the next implementation feature.

## Source of truth

- Capability brief: `.flow/briefs/B001_local-first-hotspot-intelligence-cli.yaml`
- Project memory: `.flow/project-memory.md`
- Public overview: `README.md`
- Current CLI behaviour: `./zig-out/bin/git-hotspots --help` and
  `./zig-out/bin/git-hotspots --explain`

B001 remains the source capability brief for the project thesis and boundaries.
Feature files and PRDs own feature-specific execution truth.

## Current thesis

`git-hotspots` is a deterministic, local-first hotspot intelligence CLI for
developers and coding agents.

Tagline:

> Before you refactor, ask Git where the pain is.

The product truth is deterministic local Git-history evidence. Hotspots are
investigation prompts, not bug predictions, code-quality ratings, maintainer
judgement, developer rankings, or productivity analytics.

## Current CLI state

The current Zig CLI can analyse local Git history at file level and emit:

- terminal table reports;
- deterministic JSON reports;
- deterministic Markdown reports;
- a standalone `--explain` output for score, confidence, caveat, and scope
  semantics.

Supported user-facing options are:

- `--repo PATH`
- `--limit N`
- `--format table|json|markdown`
- `--since REV`
- repeatable `--include-prefix PATH`
- repeatable `--exclude-prefix PATH`
- `--explain`
- `--help`

Scope prefixes are explicit repo-relative literal Git path prefixes. They are
not globs, pathspecs, gitignore rules, regexes, or project configuration.
Includes narrow the evidence universe; excludes remove from it and win over
includes.

## Validation state

The canonical local validation command is:

```sh
zig build validate
```

It runs the fast Zig test gate, deterministic fixture checks, JSON and Markdown
validity checks, explain-output checks, privacy/local-first scans, and
privacy-safe real-repository smoke on this repo. Close-out validation can also
accept a sibling/local smoke repo or an explicit privacy-safe skip reason.

Implementation features should continue to include real-repository smoke once an
executable exists. Do not rely on fixture-only evidence for close-out.

## Remaining candidate seams

No next implementation feature is selected in this snapshot. Possible future
shaping candidates include:

- first public release polish and install instructions;
- a stable version string instead of the spike version marker;
- a small `inspect` or per-file explanation view;
- more robust path selection ergonomics if prefix filters become limiting;
- performance and large-repo benchmarking;
- cache design, only as an optimisation and not product truth;
- provider architecture for tree-sitter, LSP, ctags, dependency, blame, test, or
  coverage enrichment;
- public case-study examples framed as exploration, not judgement.

Choose the next feature through Flow shaping rather than treating this list as a
roadmap commitment.

## Operational guardrails to preserve

- Runtime defaults stay local-first: no network calls, telemetry, background
  upload, or remote enrichment by default.
- Shareable output should prefer project-relative paths and warn when reports may
  reveal sensitive repository structure or history.
- Author identity metrics are sensitive and remain absent, anonymised, or
  explicit opt-in unless later safeguards are recorded.
- Shallow or partial history must be detected and reported honestly. Do not
  auto-fetch or contact remotes to hide missing history.
- Providers are optional enrichers. Their output should include source, version,
  freshness, confidence, and failure state.
- Cache is a future optimisation, not product truth. The tool should work without
  cache.

## Stop conditions for future shaping

Stop and reshape if a proposed feature requires:

- hosted-product, pricing, sales, or commercial strategy in repo artefacts;
- bug-prediction, objective code-quality, technical-debt-score, developer-ranking,
  maintainer-judgement, or productivity-analytics claims;
- network, telemetry, upload, remote enrichment, or auto-fetch behaviour;
- provider, cache, release, or CI design inside an unrelated feature;
- raw private smoke output, absolute local paths, author identities, or private
  repo names in committed artefacts.
