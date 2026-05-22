# Project Memory

## Purpose

Durable cross-feature context for the git-hotspots reboot. Keep this compact;
briefs, feature files, PRDs, and code own detailed active truth.

## Glossary

- Hotspot: a file or symbol with concentrated change pressure in Git history.
  Treat it as an investigation prompt, not proof of bad code.
- Provider: an optional evidence enricher, such as tree-sitter, LSP, ctags,
  dependency data, blame/history, test data, or coverage data.
- Agent-ready export: deterministic report output shaped for a user-chosen
  coding agent. It is not model-generated product truth.

## Active constraints

- Public thesis: deterministic, local-first hotspot intelligence CLI for
  developers and coding agents.
- Tagline: "Before you refactor, ask Git where the pain is."
- Repository artefacts stay OSS/publicity-oriented. Do not record hosted
  product plans, pricing, sales strategy, or commercial roadmap details here.
- Runtime defaults must be local-first: no network, telemetry, background
  upload, or remote enrichment by default.
- Public claims must frame hotspots as evidence and investigation prompts, not
  bug prediction, code-quality scoring, developer ranking, or OSS maintainer
  judgement.
- File-level Git-history evidence comes first: churn, change frequency,
  recency, co-change, size, confidence, and explainable evidence.
- Providers come later and remain optional enrichers. Future provider output
  should carry source, version, freshness, confidence, and failure state.
- Cache is a future optimisation, not product truth. Default behaviour must work
  without cache; future cache must be local-only, disableable, clearable, and
  invalidated by Git range/ref/config/provider-version changes.
- Author metrics are sensitive. Keep them absent, anonymised, or explicit opt-in
  unless a later feature records stronger safeguards.
- Shallow or partial history must be detected and reported as scoped or
  incomplete. Do not auto-fetch or contact remotes to hide missing history.
- Implementation features need real-repository smoke validation once an
  executable exists. Fixture-only evidence is not enough; default smoke targets
  are this repo and one suitable sibling/local repo, with privacy-safe labels
  and no committed absolute paths or raw private report dumps.

## Planning heuristics

- Keep B001 as the source capability brief for the project thesis and
  boundaries.
- Prefer small, executable feature slices. The current CLI spike already
  supports table, JSON, Markdown, explicit include/exclude prefixes, `--explain`,
  and `zig build validate`; do not plan as if the file-level spike is still
  future work.
- Do not let tree-sitter, LSP, cache design, release packaging, or public case
  studies enter an unrelated feature by momentum.
- Public case studies should be exploratory and careful, never judgemental.
- Plan validation so future runners do not need Arsham to manually remember the
  real-project smoke checks after each implementation feature.

## Current traps

- Overbuilding SaaS, dashboards, provider APIs, or cache schema before proving
  file-level usefulness.
- Letting agent-facing exports imply runtime LLM dependence.
- Treating churn as diagnosis instead of evidence.
- Recording private commercial strategy in repository artefacts.
