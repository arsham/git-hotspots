# Relationship output noise audit

## Overview

Audit the public `--symbol-relationships` output for usefulness, duplicate or
noisy records, caveat clarity, deterministic ordering, and provider-neutral
consistency before changing relationship aggregation or documentation. The
feature produces an evidence-backed audit document and follow-up targets only.
It must not change runtime behaviour, scoring, ranking, report schema, provider
admission, release artefacts, tags, or package publication.

This is the first precision pass after broad relationship provider admission.
It should make the next implementation slice safer by proving which noisy
patterns are real, which are acceptable caveats, and which should become
provider-neutral fixes.

## Requirements

- REQ-001: Produce `docs/relationship-output-noise-audit.md` as the sole product
  artefact unless a validation command exposes a direct documentation typo in
  the audit itself.
- REQ-002: Sample current public relationship outputs from deterministic fixture
  commands and this repository using `--symbols --symbol-relationships` across
  table, JSON, and Markdown surfaces where practical.
- REQ-003: Include at least one fixture or command path that exercises each
  admitted relationship lane group: Python, JavaScript or TypeScript or TSX,
  Rust, Go, Lua, and Zig, or record a concrete skip reason for any lane that
  cannot be exercised safely.
- REQ-004: Classify observed noise into provider-neutral buckets, including
  duplicate records, over-broad `reference` records, ambiguous `call` records,
  unresolved target volume, repeated caveats, cap or omission presentation,
  ordering instability, and unsupported-lane presentation.
- REQ-005: For each material finding, record command shape, bounded counts,
  affected public surface, provider lane, caveat state, and a privacy-safe
  observation. Do not commit raw private reports, source snippets, absolute
  local paths, remotes, author identities, emails, parser diagnostics, or commit
  messages.
- REQ-006: Distinguish true repair targets from acceptable caveats. Do not turn
  syntax-only caveats into claims of call-graph truth, dependency truth,
  ownership, code quality, maintainer judgement, developer metrics, or bug
  prediction.
- REQ-007: Preserve current public semantics during the audit. No CLI flags,
  report keys, output order, scoring, ranking, provider support matrix,
  validation budgets, cache behaviour, network behaviour, telemetry, release
  state, tags, or package artefacts may change in this feature.
- REQ-008: Prioritise follow-up targets into small successor slices, with at
  least one recommended next implementation feature and clear non-goals.
- REQ-009: If the audit finds no actionable noise, record that outcome with
  evidence and recommend the next product slice without inventing a repair.
- REQ-010: Record fresh validation evidence for `git diff --check`,
  `zig build test`, and `zig build validate`. If a privacy-safe sibling smoke
  is unavailable, record the explicit skip reason rather than a private path.

## Acceptance

- The audit document exists, is project-relative, and is enough for a fresh
  planner to shape the next relationship precision implementation without this
  chat.
- The audit covers table, JSON, and Markdown relationship output or explains
  why a surface was not sampled.
- Findings are evidence-backed, privacy-safe, and caveated as syntax evidence.
- The feature does not change runtime behaviour, public report schema, scoring,
  ranking, provider admission, release artefacts, tags, remotes, or packages.
- Validation evidence is fresh and recorded in the run state.

## Edge cases

- If relationship output is absent for a sampled fixture, classify whether that
  is expected unsupported-lane behaviour, a fixture setup issue, or a product
  finding.
- If a command output is too large, record bounded counts and categories rather
  than raw output.
- If a provider emits many unresolved targets, decide whether the volume is
  useful evidence, presentation noise, or a cap/summary follow-up.
- If duplicate-looking records differ by source endpoint, target endpoint,
  relation kind, direction, provider, or evidence basis, do not classify them as
  duplicates without stating the differentiator.
- If ordering differs only because command inputs differ, do not classify it as
  nondeterminism.

## Verification

The runner should record fresh evidence for:

- `git diff --check`
- `zig build test`
- `zig build validate`
- representative relationship-output command shapes used by the audit
- local or explicit skipped sibling smoke evidence, privacy-safe only

Reviewer focus should be whether the audit evidence is sufficient, whether
follow-up targets are specific and bounded, and whether the feature preserved
all public runtime and release boundaries.
