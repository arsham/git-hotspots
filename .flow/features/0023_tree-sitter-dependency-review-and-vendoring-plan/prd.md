# PRD: Tree-sitter dependency review and vendoring plan

## Problem

Feature 0022 recorded that a future Tree-sitter Zig provider should not proceed
until parser sources, grammar provenance, license obligations, offline build
constraints, and source-install impact are reviewed. The repository still has no
`build.zig.zon`, no vendored Tree-sitter sources, no generated Zig grammar
sources, and no parser runtime. Jumping directly to vendoring or build
integration would combine dependency, legal, source-install, and provider
semantics risk in one feature.

## Outcome

Produce a documentation-only dependency review, bill-of-materials candidate, and
vendoring go/no-go plan for a future Tree-sitter Zig provider. The record must be
specific enough for a later feature to import pinned sources or stop safely, but
this feature must not add vendored code, build graph changes, parser runtime, CLI
surface, report schema fields, scoring changes, provider registry, cache,
network runtime behaviour, telemetry, or background analysis.

## Requirements

### Scope and artefact

- Add a dependency review document, expected path:
  `docs/tree-sitter-dependency-vendoring-plan.md`.
- The document must cover both Tree-sitter core and a Zig grammar source.
- The document must distinguish candidate facts from decisions. Unknowns must be
  labelled as blockers or follow-up requirements, not guessed.
- The feature is documentation-only. It may update Flow state and docs, but it
  must not add or modify runtime source, tests, fixtures, build dependencies, CLI
  behaviour, report schemas, scoring, cache, provider registry, vendored parser
  sources, generated grammar sources, submodules, or third-party source trees.

### Dependency bill of materials candidate

For each dependency candidate, the document must record:

- upstream project name;
- upstream URL;
- selected immutable commit, tag, or release candidate;
- source archive or checkout identity and checksum when available or generated
  during review;
- license file path and SPDX identifier;
- copyright and notice obligations;
- whether generated files are present;
- generated-source provenance for grammar C sources, including the generator,
  grammar source revision, and whether generated output is reproducible;
- expected local vendoring path for a later feature;
- expected update policy and how future updates should be reviewed.

### Dependency strategy comparison

The document must compare at least these options:

- relying on system Tree-sitter packages;
- build-time fetches or package-manager/network dependency resolution;
- shelling out to a Tree-sitter CLI;
- vendoring pinned Tree-sitter core and generated Zig grammar C sources;
- deferring runtime parser integration.

The comparison must preserve the existing source-install baseline: a local
checkout and `zig build` must continue to work without global parser packages or
network fetches unless a later feature explicitly changes and proves that.

### Go/no-go decision

The document must end with a clear recommendation for the next feature:

- `go`: proceed to a vendored-source import feature;
- `conditional_go`: proceed only after listed blockers are resolved;
- `no_go`: do not vendor or build Tree-sitter yet.

The decision must list concrete blockers, risks, and required evidence for the
next feature. A future vendoring feature must remain separate from this one.

### Future vendoring contract

The document must define the acceptance contract for a later vendored-source
import feature, including:

- exact source revisions and checksums;
- committed license and notice files or attribution text;
- expected vendored layout, preferably explicit `third_party/tree-sitter*` paths;
- no submodules and no build-time fetches;
- changed-path expectations;
- no runtime parser execution unless a still later feature adds an opt-in build
  or provider runtime;
- validation and privacy scans required before close-out.

### Future offline build and provider contract

The document must define what a later offline build proof and first runtime
provider feature must prove, including:

- no system `tree-sitter`, `pkg-config`, global package, submodule, remote
  dependency, `curl`, `wget`, `git clone`, upload, telemetry, or remote
  enrichment path;
- clean source-copy build without network;
- byte-stable no-provider table, JSON, and Markdown output;
- provider output remains opt-in, inspect-oriented, current-working-tree Zig
  symbol evidence only;
- parser failures map into provider failure, freshness, confidence, and caveat
  states;
- no file-level scoring or ranking changes.

## Non-goals

- No vendored Tree-sitter core source files.
- No vendored tree-sitter-zig grammar source or generated C files.
- No `build.zig.zon`.
- No `build.zig` C build or linking changes.
- No parser wrapper, parser runtime, provider registry, CLI flags, report schema
  additions, scoring or ranking changes, cache, source/test/fixture changes, CI,
  release packaging, network runtime, telemetry, upload, remote enrichment, or
  background provider execution.
- No claim that symbol evidence exists in current CLI reports.

## Edge cases and stop conditions

Stop and return a blocker or `conditional_go` if:

- exact upstream revisions cannot be selected;
- license files, SPDX identifiers, copyright, or notice obligations are unclear;
- generated Zig grammar provenance cannot be established;
- grammar C output cannot be pinned, reproduced, or trusted enough for vendoring;
- the only viable path requires build-time network fetches, global system
  packages, submodules, or remote parser services;
- vendoring would materially degrade source-install UX without a mitigation;
- the next implementation would require report schema, scoring, cache, provider
  registry, or runtime provider semantics that are not shaped yet;
- the document would need private paths, private repository names, raw parser
  stderr, raw private reports, author identities, commercial strategy,
  bug-prediction claims, code-quality scoring claims, developer ranking, or
  maintainer judgement.

## Verification

Close-out for this docs-only feature requires:

- `git diff --check` passes;
- `zig build validate` passes;
- changed-path scan proves only docs plus Flow planning/lifecycle files changed;
- no `src/`, `tests/`, `fixtures/`, `tools/`, `build.zig`, `build.zig.zon`,
  `third_party/`, parser sources, grammar sources, submodules, generated C,
  CLI/report/scoring/cache/provider-registry changes were added;
- no-runtime/dependency scan proves no runtime tree-sitter integration was added;
- no-network scan finds no fetch/upload/telemetry/remote enrichment/background
  analysis path and no `curl`, `wget`, `git clone`, submodule, or build-time
  fetch workflow committed;
- privacy/prohibited-claim scan finds no absolute private paths, private remotes,
  raw parser stderr, raw private reports, author identities, private repo names,
  hosted/pricing/sales strategy, bug-prediction, quality-score, developer-ranking,
  or maintainer-judgement claims;
- real-repo smoke beyond the existing `zig build validate` self-repo smoke is not
  required because runtime/build behaviour is unchanged.
