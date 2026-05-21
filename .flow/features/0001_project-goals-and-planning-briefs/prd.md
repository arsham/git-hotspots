# PRD: Project goals and planning briefs

## Purpose

Feature 0001 turns the git-hotspots reboot discussion into durable,
OSS-safe planning artefacts. It is not a CLI implementation feature. Its job is
to make future shaping sessions recover the project direction without relying on
chat history.

## Source brief

- Capability source: `B001 Local-first hotspot intelligence CLI`
- Tagline: `Before you refactor, ask Git where the pain is.`
- Public thesis: deterministic, local-first hotspot intelligence CLI for
  developers and coding agents.

B001 remains the capability source. Feature 0001 should reference it and add
execution-specific documentation scope rather than duplicating all B001 content.

## Requirements

### R1 - Flow authority and acceptance

Feature 0001 must record a documentation-only execution boundary in
`feature.yaml` and this PRD.

Required content:

- the problem and outcome for durable project-goal capture;
- acceptance criteria that preserve the local-first public thesis;
- explicit non-goals for runtime code, package setup, provider APIs, hosted
  product strategy, pricing, telemetry, developer ranking, and bug-prediction
  claims;
- a packet plan with Packet Rubric v1 context for each packet;
- alignment with B001 as the primary capability brief.

### R2 - Public project-goal documentation

The feature must create concise public documentation for OSS readers and future
contributors.

Preferred artefact:

- `README.md` when absent or still project-empty.

Fallback artefact:

- `docs/project-goals.md` if a future runner decides `README.md` should stay
  shorter.

The public documentation must include:

- the tagline;
- what git-hotspots is;
- who it is for;
- why Git history is useful evidence;
- first useful layer: file-level evidence from churn, change frequency,
  recency, co-change, size, confidence, and explanations;
- future provider direction: tree-sitter, LSP, ctags, dependency, blame/history,
  and test or coverage evidence as optional enrichers;
- agent-ready exports as a consumer of deterministic evidence, not model-driven
  product truth;
- safe non-goals and claim boundaries.

### R3 - Cross-feature project memory

The feature must update `.flow/project-memory.md` with compact durable truth that
future features must preserve.

Minimum memory topics:

- local-first, deterministic, no-network/no-telemetry default;
- repository is OSS/publicity-oriented;
- no hosted product, pricing, or sales strategy in repo artefacts;
- hotspots are investigation prompts, not judgements;
- file-level Git evidence comes before provider precision;
- providers are optional enrichers and must carry source/version/confidence and
  failure state when designed later;
- cache is future optimisation, not truth;
- author metrics are sensitive and absent, anonymised, or opt-in;
- shallow or partial history must be detected and reported as scoped or
  incomplete, not silently corrected by remote fetch.

### R4 - Future planning handoff

The feature must create a concise handoff for the next implementation-planning
session.

Preferred artefact:

- `docs/planning-handoff.md`

The handoff must include:

- next likely feature: file-level CLI spike;
- current preference: Zig is the likely implementation language for the spike,
  but Feature 0001 must not add toolchain files;
- validation gates for the spike: useful output on real repos, deterministic
  repeated output, bounded performance, and explainable evidence;
- deferred topics: tree-sitter/provider architecture, cache schema, release
  automation, GitHub Action, case-study campaign, and any hosted product work;
- open questions that should be answered by future shaping, not guessed during
  execution.

## Non-goals

Feature 0001 must not implement or scaffold:

- CLI code;
- `build.zig`, package manifests, dependency locks, or release scripts;
- scoring algorithms;
- provider APIs or provider implementations;
- cache schema or database setup;
- GitHub Actions;
- telemetry;
- hosted dashboards;
- pricing, paid tiers, or sales strategy;
- runtime LLM integration;
- developer ranking or productivity analytics;
- bug-prediction or code-quality scoring claims.

Commercial ideas may exist outside the repository, but this feature must not
record commercial strategy in repo artefacts.

## Edge cases and constraints

### Existing README appears before execution

If `README.md` exists by the time the runner starts, the runner should preserve
useful existing content and either update it narrowly or create
`docs/project-goals.md` as the detailed public goals artefact.

### Public wording is too strong

If wording implies bug prediction, objective code quality measurement, developer
performance ranking, or judgement of OSS maintainers, revise it to evidence and
investigation language.

### Commercial wording appears

If artefacts start to describe pricing, hosted product plans, sales strategy, or
paid offers, stop and remove that content. If the runner believes a commercial
boundary affects execution, escalate to the planner rather than recording the
plan in the repo.

### Toolchain choice becomes necessary

If execution seems to require choosing build tooling, package management, Zig
version, Git backend libraries, tree-sitter bindings, or SQLite libraries, stop.
Those belong to later implementation features.

### Provider detail becomes too deep

Provider architecture should be described only as future direction. Detailed
interfaces, schemas, sandboxing, parser choices, and LSP behaviour belong to
later features.

## Verification

Required checks before completion:

1. Run Flow validation:

   ```bash
   flow validate --target feature:0001 --format json
   ```

2. Run whitespace/diff validation:

   ```bash
   git diff --check
   ```

3. Review changed files and confirm only Flow planning and documentation
   artefacts changed.

4. Search changed planning/docs artefacts for prohibited public claims and
   commercial strategy. Matches that only state non-goals are acceptable; any
   actual plan, price, hosted roadmap, bug-prediction claim, or developer-ranking
   claim must be removed.

5. Fresh-session sufficiency audit:

   A future planner must be able to recover the public thesis, non-goals,
   operational constraints, next likely implementation feature, and deferred
   topics from B001, Feature 0001, `.flow/project-memory.md`, and public docs
   without reading this chat.

## Acceptance mapping

Feature 0001 is complete only when:

- B001 is linked and aligned as the source capability brief;
- `feature.yaml` and this PRD describe docs-only scope and acceptance;
- public project-goal documentation exists;
- `.flow/project-memory.md` contains compact cross-feature truth;
- a future-planning handoff exists;
- no runtime implementation or package scaffold was added;
- no repository artefact records hosted product, pricing, or sales strategy;
- no public claim implies bug prediction, code-quality scoring, or developer
  performance ranking.
