# Relationship fixture gap closures

## Purpose

Close small, stable fixture representativeness gaps identified by the fixture realism matrix and caveat audit, preferring validation/fixture changes over runtime changes.

## Requirements

- REQ-001: Use `docs/relationship-fixture-realism-matrix.md` and any completed caveat audit findings as the comparison basis.
- REQ-002: Close only fixture or validation gaps that are stable, deterministic, and low-risk.
- REQ-003: Prefer adding or adjusting checked-in fixtures, goldens, or validation metadata over changing runtime/provider behaviour.
- REQ-004: Preserve runtime behaviour, CLI flags, JSON schema, report fields, provider algorithms, provider admission, relation semantics, scoring, ranking, caps, cache, network, telemetry, release, tag, remote, package, and publish behaviour.
- REQ-005: If no safe fixture gap remains after audit, record a no-change evidence pass instead of inventing churn.
- REQ-006: Update integration and validation checks only where they guard the chosen fixture closure.
- REQ-007: Keep all evidence project-relative and privacy-safe.
- REQ-008: Run `git diff --check`, `zig build test`, and `zig build validate` before close-out.

## Acceptance

- At least one concrete fixture gap is closed, or a documented no-change decision explains why no safe closure exists.
- Golden outputs remain deterministic.
- Relationship fixture realism validation remains coherent after changes.

## Edge cases

- Provider-cap coverage may remain synthetic if lane-local cap goldens would be oversized or cap-coupled.
- Fixture diversity should not force unstable provider behaviour.
- Fixture changes must not create new public semantic claims.

## Verification

- `git diff --check`
- `zig build test`
- `zig build validate`
- Reviewer-owned discovery and execution of credible lint/test gates.
