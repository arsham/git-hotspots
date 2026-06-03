# Historical aggregate-bound exceeded proof

## Summary

Add a focused test-only proof for the historical-symbol aggregate bound exceeded
path identified by feature 0126.

The current checked-in historical fixture proves `aggregate_record_bound: 128`
with `aggregate_record_bound_exceeded: false`. Feature 0126 proved that the
production aggregation and pipeline truncation seams can deterministically cover
the exceeded path without changing runtime behaviour or expanding fixture
goldens. This feature implements that narrow proof.

## Requirements

- REQ-001: Add deterministic test coverage for
  `aggregate_record_bound_exceeded: true`.
- REQ-002: Drive the proof through production historical-symbol aggregation or
  pipeline truncation seams, not through a hand-built final report object.
- REQ-003: Build more aggregate records than the configured bound in a bounded
  synthetic test.
- REQ-004: Assert the retained aggregate record count is truncated to the
  configured bound.
- REQ-005: Assert the exceeded-bound flag is true when records are truncated.
- REQ-006: Keep existing checked-in historical fixture/golden output unchanged
  unless execution proves a tiny golden update is strictly necessary and within
  this feature's protected surfaces.
- REQ-007: Keep existing non-exceeded fixture proof intact:
  `aggregate_record_bound: 128` and `aggregate_record_bound_exceeded: false`.
- REQ-008: Do not change runtime attribution semantics, fallback pressure
  semantics, provider-state semantics, display omission semantics, or
  local-first provenance.
- REQ-009: Do not add timeout or unavailable provider-state injection seams.
- REQ-010: Do not change CLI flags, JSON schema shape, scoring, ranking,
  provider admission, release/tag/package/remote state, network behaviour,
  telemetry, or cache behaviour.
- REQ-011: Keep docs honest that this is synthetic test proof for the bound
  path, not fixture realism coverage.
- REQ-012: Update validation/docs metadata only if needed to keep the exceeded
  proof discoverable and not overclaimed.
- REQ-013: Run `git diff --check`, `zig build test`, and
  `zig build validate` before close-out.

## Acceptance

- A deterministic test proves `aggregate_record_bound_exceeded: true` using the
  production aggregation or truncation seam.
- The test asserts both retained-count truncation and the exceeded-bound flag.
- Existing historical-symbol fixture goldens remain stable unless a strictly
  necessary and reviewed update is justified.
- The historical-symbol fixture realism matrix continues to distinguish
  fixture realism from synthetic bound proof.
- Protected runtime, CLI, schema, provider, scoring, release, remote, network,
  telemetry, and cache surfaces remain unchanged.

## Edge cases

- Exactly-at-bound record counts must not set the exceeded flag unless current
  production semantics already do so.
- Over-bound record counts must retain only the configured number of aggregate
  records.
- Synthetic record identities should be deterministic and project-relative when
  paths are involved.
- The test must avoid creating large or brittle Git history fixtures.

## Verification

- `git diff --check`
- `zig build test`
- `zig build validate`
- Reviewer spot-check that the proof uses production aggregation/truncation
  logic rather than constructing a final output object by hand.
