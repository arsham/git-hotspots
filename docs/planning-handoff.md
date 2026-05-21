# Planning handoff

This handoff lets a future planner continue without relying on the original
chat. It summarises the next likely feature and the constraints that must stay
true when implementation planning begins.

## Source of truth

- Capability brief: `.flow/briefs/B001_local-first-hotspot-intelligence-cli.yaml`
- Current feature: `.flow/features/0001_project-goals-and-planning-briefs/`
- Project memory: `.flow/project-memory.md`
- Public goals: `README.md`

B001 remains the source capability brief. Feature 0001 exists to preserve
project goals and planning context, not to implement the CLI.

## Current thesis

`git-hotspots` should become a deterministic, local-first hotspot intelligence
CLI for developers and coding agents.

Tagline:

> Before you refactor, ask Git where the pain is.

The project should start by turning local Git history into explainable file-level
evidence. Symbol-level and dependency-aware views can arrive later through
optional providers.

## Next likely feature

The next implementation-planning feature should probably be:

> File-level CLI spike

Suggested scope for that future feature:

- decide the minimal Zig project/tooling boundary;
- analyse a local Git repository without network access;
- produce a ranked file-level hotspot report;
- emit a human-readable table and a JSON or Markdown export;
- include evidence and caveats for each hotspot;
- avoid tree-sitter, LSP, ctags, cache schema, and GitHub Actions in the first
  critical path.

Feature 0001 must not create this implementation. It only records enough context
for a later feature to shape it safely.

## Spike validation gates

A future file-level CLI spike should not be considered successful merely because
it runs. It should pass these gates:

- Useful output: on real repositories, top results should look worth inspecting
  to maintainers or experienced contributors.
- Determinism: repeated runs against the same repo, ref, config, and tool
  version should produce the same results.
- Explainability: each ranking should show why it appears, not just a score.
- Bounded performance: the implementation should stream Git history and avoid
  holding full history or repository contents in memory.
- Privacy default: no network calls, telemetry, background upload, or remote
  enrichment by default.
- Careful claims: outputs should frame hotspots as investigation prompts, not
  bug predictions or quality judgements.

## Deferred topics

These are important, but should not be forced into the first implementation
slice:

- tree-sitter symbol extraction;
- LSP-backed dependency or reference evidence;
- ctags fallback support;
- historical symbol identity across moves and renames;
- SQLite or other persistent cache schema;
- release automation and checksummed binaries;
- GitHub Action output;
- public case-study campaign;
- hosted product work or commercial strategy.

Repository artefacts should not contain hosted product plans, pricing, sales
strategy, or commercial roadmap details.

## Operational guardrails to preserve

- Cache is an optimisation, not product truth. The tool should work without it.
- Future cache must be local-only, disableable, clearable, and invalidated by
  Git range, ref, config, and provider-version changes.
- Author identity metrics are sensitive. Keep them absent, anonymised, or
  explicit opt-in unless later safeguards are recorded.
- Shareable output should prefer project-relative paths and warn that reports
  may reveal sensitive repository structure or history.
- Shallow or partial history must be detected and reported as scoped or
  incomplete. Do not auto-fetch or contact remotes to hide missing history.
- Providers are optional enrichers. Their output should include source, version,
  freshness, confidence, and failure state.
- Provider failures should degrade gracefully and must not silently rewrite core
  Git findings.

## Open questions for future shaping

Future implementation planning should answer these rather than guessing:

- Which exact Git command stream forms the first file-level evidence source?
- What is the smallest honest scoring formula for the spike?
- Which output format should be stable first: JSON, Markdown, or both?
- What performance target should the first spike use for small and medium repos?
- How much of the cache story belongs in the first implementation feature?
- Which sample repositories should be used for usefulness checks?
- What Zig version and package/build setup should the project standardise on?

## Stop conditions for future implementation

Stop and reshape if implementation planning starts to require:

- provider API design;
- tree-sitter, LSP, or ctags integration;
- database/cache schema design;
- telemetry or network behaviour;
- hosted dashboards or commercial strategy;
- bug-prediction claims;
- developer ranking or productivity analytics.
