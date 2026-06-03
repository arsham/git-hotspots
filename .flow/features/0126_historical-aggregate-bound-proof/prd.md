# Historical aggregate-bound seam proof

## Problem

The historical-symbol fixture matrix proves that `aggregate_record_bound` is
reported when the bound is not exceeded. It does not prove the
`aggregate_record_bound_exceeded: true` path. Before implementing fixture or
validation coverage, we need to know whether a deterministic, maintainable seam
exists.

## Outcome

Produce a tracked proof document that decides whether
`aggregate_record_bound_exceeded: true` can be covered deterministically. If it
is feasible, the proof defines the next implementation slice. If it is not
feasible, the proof records why the path remains uncovered without relying on
chat context.

## Requirements

- REQ-001: Inspect the current historical-symbol aggregate-bound implementation
  and fixture/test seams.
- REQ-002: Add `docs/historical-aggregate-bound-seam-proof.md` as the durable
  proof artifact.
- REQ-003: The proof must state whether deterministic exceeded-bound coverage is
  feasible.
- REQ-004: If feasible, the proof must name the smallest recommended next
  fixture/test/golden implementation slice.
- REQ-005: If infeasible, the proof must explain why current seams are too
  brittle, too synthetic, too slow, or otherwise unsuitable.
- REQ-006: The proof must preserve the current fixture matrix truth: current
  checked-in goldens prove `aggregate_record_bound: 128` and
  `aggregate_record_bound_exceeded: false` only.
- REQ-007: Do not add or change fixture history, goldens, runtime logic, CLI
  flags, JSON schema shape, scoring, ranking, provider admission,
  release/tag/package/remote state, network access, telemetry, or cache
  behaviour.
- REQ-008: `timed_out` and `unavailable` provider states remain uncovered unless
  a separately shaped feature proves deterministic seams.
- REQ-009: Validation must include `git diff --check` and `zig build validate`.

## Acceptance

- `docs/historical-aggregate-bound-seam-proof.md` exists and is understandable
  without chat context.
- The proof selects exactly one branch: feasible next implementation slice or
  tracked no-change rationale.
- Existing historical-symbol fixture/golden output is unchanged.
- Protected runtime, public CLI, schema, provider, scoring, release, package,
  remote, network, telemetry, and cache surfaces do not drift.

## Edge cases

- A test-only helper may be recommended for the next slice if the proof shows it
  exercises production aggregate-bound logic without changing runtime behaviour.
- A huge generated fixture history is not acceptable if it makes validation slow
  or brittle.
- Synthetic-only proof must not be presented as equivalent to checked-in fixture
  realism unless the proof explains that trade-off.

## Verification

Run:

```sh
git diff --check
zig build validate
```

Reviewer should inspect the proof artifact against this PRD, B002, and the
current historical-symbol fixture realism matrix.
