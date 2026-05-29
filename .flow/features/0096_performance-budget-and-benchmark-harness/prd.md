# Performance budget and benchmark harness

## Summary

Create an internal benchmark and performance-budget harness for the symbol,
historical-symbol, and relationship evidence paths. The goal is to make future
provider and reporting work prove bounded local runtime behaviour with stable,
privacy-safe evidence.

## Requirements

- REQ-001: Define named performance budgets for baseline file hotspots,
  current-symbol enrichment, historical-symbol attribution, and relationship
  enrichment.
- REQ-002: Add deterministic fixture benchmark coverage that can run in normal
  validation or a clearly named validation rung without network access.
- REQ-003: Add privacy-safe real-repo smoke timing evidence using labels,
  bounded counts, and elapsed values only; do not print raw reports or absolute
  private paths.
- REQ-004: Keep budget failures actionable with the phase, provider, scope, and
  likely limit or command to retry.
- REQ-005: Preserve default runtime semantics; benchmarking must not require a
  cache, telemetry, background upload, or remote enrichment.
- REQ-006: Keep public CLI/report output unchanged except for validation or
  diagnostic text required to explain budget failures.
- REQ-007: Include determinism checks so repeated runs over the fixture produce
  stable counts and output where applicable.
- REQ-008: Document the benchmark harness enough for future provider features to
  add rows without rediscovering the pattern.
- REQ-009: `zig build test` passes.
- REQ-010: `zig build validate` passes.
- REQ-011: `git diff --check` passes.

## Edge cases

- Large fixture data should not make normal validation unreasonably slow.
- Dirty worktrees should be reported as scoped evidence, not hidden.
- Shallow or partial history remains a caveated evidence condition, not an
  implicit fetch.
- Missing optional providers should record unsupported or skipped lanes without
  failing unrelated budgets.

## Verification notes

Close-out requires fixture benchmark evidence, privacy-safe real-repo smoke
summary, and validation proof. Synthetic-only timing is not enough for the
real-repo budget claim.
