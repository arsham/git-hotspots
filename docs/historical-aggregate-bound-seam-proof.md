# Historical aggregate-bound seam proof

## Decision

Selected branch: **feasible next implementation slice**.

Deterministic exceeded-bound coverage is feasible without changing runtime
behaviour, CLI flags, JSON schema, scoring, provider admission, network,
telemetry, cache, releases, tags, packages, or remotes.

## Evidence from current seams

- `src/historical_symbol_pipeline.zig` already carries an explicit
  `max_aggregate_records` option.
- That pipeline truncates aggregate records when the bound is exceeded and
  flips `aggregate_record_bound_exceeded`.
- `src/historical_symbol_attribution.zig` exposes `aggregateRecords(...)`, so
  tests can drive the production aggregation logic with deterministic synthetic
  `git_hunks.FileHunkRecord` inputs.
- `docs/historical-symbol-fixture-realism-matrix.md` currently proves only the
  non-exceeded case: `aggregate_record_bound: 128` and
  `aggregate_record_bound_exceeded: false`.

## Why the seam is feasible

The current implementation already separates:

1. production aggregation,
2. pipeline-level truncation, and
3. fixture realism evidence.

That makes the exceeded-bound path reachable in a bounded test without needing
runtime changes. The existing seam is strong enough to exercise the production
truncation branch directly.

## Smallest recommended next slice

Add a narrow test-only helper or synthetic test case that:

- builds more than 128 distinct aggregate records through the production
  aggregation path,
- asserts `aggregate_record_bound_exceeded == true`,
- asserts the retained aggregate slice is truncated to the configured bound,
- keeps the checked-in fixture/golden output unchanged.

A synthetic helper is the smallest safe slice because it proves the truncation
branch directly while staying inside local-first, deterministic test control.
It should not be treated as equivalent to checked-in fixture realism; it only
proves the bound-handling seam.

## Trade-off note

A checked-in fixture/golden expansion would provide realism coverage, but it is
not required to prove the deterministic bound seam. For this feature, the
minimal useful next step is a test-only exceeded-bound proof, not a runtime or
fixture rewrite.
