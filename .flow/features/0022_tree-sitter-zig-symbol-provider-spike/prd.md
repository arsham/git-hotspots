# Feature 0022: Tree-sitter Zig symbol provider feasibility spike

## Problem

`git-hotspots` now has a provider/symbol evidence contract and an internal
provider seam, but it does not yet know whether a real tree-sitter Zig provider
can be added without damaging the project goals: deterministic local-first
analysis, simple source installs, no network dependency, and file-level Git
evidence as product truth.

A direct tree-sitter implementation would combine several risks in one feature:
C build/linking, generated grammar source, license/notice handling, report UX,
parser correctness, provider failure semantics, and validation. Local inspection
shows system `tree-sitter` is installed on this machine, but the repository does
not contain a pinned `tree-sitter-zig` grammar. Depending on host packages would
not be a portable source-install story.

## Outcome

Create a durable feasibility and decision record for the first tree-sitter Zig
symbol provider. The feature should define the next implementation path and stop
conditions without adding parser runtime, new build dependencies, CLI flags,
report schema fields, provider registry, cache, or scoring changes.

## Requirements

### R1: Feasibility decision document

Add a focused document, preferably `docs/tree-sitter-zig-provider-spike.md`,
that records the current feasibility decision for a tree-sitter Zig provider.

The document must cover:

- the current dependency-free build/source-install baseline;
- local feasibility evidence, including that system tree-sitter availability is
  not portable product evidence;
- the dependency strategy options considered;
- the recommended next implementation strategy;
- explicit stop conditions that should prevent runtime integration;
- the next feature slice if implementation is safe.

### R2: Dependency and build strategy

The document must compare these approaches:

- system-linked `tree-sitter` plus a separate Zig grammar;
- vendored, pinned tree-sitter core C sources and generated Zig grammar C
  sources;
- external command or local prototype only;
- deferring tree-sitter runtime integration.

It must state that any future runtime implementation must be buildable offline
from the repository checkout, with no build-time fetches or hidden global-system
requirements. If vendoring is recommended, the document must record that a later
feature must handle pinned upstream versions, licenses, notice obligations,
update policy, and cross-platform validation before landing the dependency.

### R3: Symbol mapping plan

The document must map current working-tree Zig symbols into the existing
`src/provider.zig` seam. It must describe at least:

- provider envelope values for tree-sitter Zig;
- repo-relative file paths only;
- symbol name, kind, and current range;
- confidence and caveats;
- freshness and failure states;
- deterministic ordering;
- unsupported, unavailable, failed, partial, stale, timed-out, and skipped
  states.

The plan must remain current-only. It must not imply historical symbol lineage,
symbol moves, symbol renames, ownership, dependency propagation, source snippets,
author metrics, bug prediction, code-quality scoring, or developer ranking.

### R4: Future runtime surface

Define the preferred first runtime surface for the later provider feature.

The default recommendation should be opt-in and inspect-oriented, for example
current Zig symbol evidence attached only when inspecting an in-scope `.zig`
file. Normal no-provider table, JSON, and Markdown output should remain useful
and should not imply provider evidence exists when the provider is unavailable or
not requested.

This feature must not add the CLI surface itself.

### R5: Validation plan for the future implementation

The document must record the validation matrix required before a runtime
provider can close out. It should include:

- `git diff --check`;
- `zig fmt --check build.zig src tests` where applicable;
- `zig build test`;
- `zig build validate`;
- close-out validation with this repo and a privacy-safe sibling/local repo
  label when available;
- byte-stable no-provider table, JSON, and Markdown outputs;
- deterministic provider output for the same repo/ref/config/tool version;
- fixture coverage for Zig functions/types/modules, nested symbols, invalid or
  partial Zig, empty files, unsupported files, and deterministic ranges;
- provider unavailable/unsupported/failed/timed-out/skipped/stale/partial/unknown
  degradation;
- privacy scans for absolute paths, remotes, source snippets, raw parser stderr,
  raw private reports, author identities, and private repo names;
- local-first scans proving no fetch, upload, telemetry, remote enrichment, or
  background provider execution.

### R6: No runtime behaviour in this feature

This feature must not add or modify:

- tree-sitter or tree-sitter-zig source code;
- `build.zig.zon`;
- C build/linking;
- parser runtime;
- provider registry or plugin lifecycle;
- CLI flags;
- report schema fields;
- scoring, ranking, confidence, rename-lineage, or co-change logic;
- cache;
- fixtures or goldens unless the PRD is updated to justify a documentation-only
  validation fixture;
- network, telemetry, upload, remote enrichment, or background analysis.

`zig build validate` must pass after the documentation change.

## Edge cases and stop conditions

The future runtime provider feature should stop before implementation if:

- generated Zig grammar sources cannot be pinned and built offline with Zig
  `0.16.0`;
- implementation requires build-time network fetches or global system packages;
- license or notice obligations are unclear;
- provider output would require scoring or report-schema commitments beyond the
  shaped spike;
- parser failures cannot be represented through the provider failure/caveat
  model;
- source-install UX becomes materially worse than the current `zig build`
  workflow;
- output would imply symbol-history truth, bug prediction, code-quality scoring,
  developer ranking, or maintainer judgement.

## Verification notes

Review should reject close-out if the feature adds runtime parser integration,
build dependencies, CLI/report output, scoring changes, cache, provider registry,
network behaviour, telemetry, raw private evidence, or commercial/SaaS content.

The close-out proof should show:

- only documentation and Flow planning artefacts changed, unless the PRD was
  explicitly reshaped;
- the new document is specific enough for a future runner to implement the first
  real tree-sitter Zig provider without relying on chat context;
- no-provider CLI behaviour remains unchanged;
- `zig build validate` passes.
