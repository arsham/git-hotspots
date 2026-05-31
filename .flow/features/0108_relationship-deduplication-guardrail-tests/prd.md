# Relationship deduplication guardrail tests

## Summary

Add guardrail tests for relationship evidence records that can look duplicated to
humans while carrying different syntax evidence. The feature preserves the
current public contract: endpoint repeats with a different relation kind,
direction, provider, or evidence basis are not accidental duplicates and must
not be collapsed by future cleanup work.

## Problem

The relationship output noise audit found no exact duplicate relationship
records in sampled JSON outputs. It did find repeated source and target endpoint
pairs with different relation kinds or evidence bases, such as nested symbols
that produce both `contains` and `reference` or `call` evidence. Those records
are meaningful under the current evidence contract, but they are easy targets
for a future over-broad deduplication pass.

## Outcome

Tests lock the current relationship evidence contract so duplicate-looking
records remain preserved when relation kind, direction, provider, or evidence
basis differs. Any exact duplicate fixture introduced for the guardrail must be
handled according to the current implementation contract and documented by the
test expectation. The work is intentionally test-focused and must not alter
relationship semantics or output contracts unless a tiny test helper is needed.

## Requirements

- REQ-001: Add durable regression coverage for at least one repeated endpoint
  pair with different relation kinds.
- REQ-002: Add durable regression coverage for at least one repeated endpoint
  pair with different evidence basis when the current fixtures expose such a
  case.
- REQ-003: Tests must prove duplicate-looking records are preserved rather than
  collapsed when their differentiator changes evidence meaning.
- REQ-004: If an exact duplicate fixture is introduced, the test must document
  and assert the current exact-duplicate behaviour without changing the public
  contract.
- REQ-005: Prefer existing relationship fixtures and integration assertions over
  new runtime code.
- REQ-006: Any helper added must be test-only or narrowly shared for test
  assertions; it must not change production relationship aggregation.
- REQ-007: Preserve JSON schema, fields, record ordering, record-level caveats,
  and relationship evidence fields.
- REQ-008: Preserve human table and Markdown wording introduced by 0105, 0106,
  and 0107.
- REQ-009: Preserve provider algorithms, provider admission, relation kinds,
  direction semantics, scoring, ranking, confidence, and caps.
- REQ-010: Preserve CLI flags/options, cache behaviour, network behaviour,
  telemetry behaviour, release state, tags, remotes, package artefacts, and
  publishing behaviour.
- REQ-011: Add validation coverage so the guardrail runs in normal project
  validation, not only as an ad-hoc local check.
- REQ-012: Run and record `git diff --check`, `zig build test`, and
  `zig build validate` before close-out.

## Acceptance

- Duplicate-looking relationship records with meaningful differentiators remain
  present in tested output.
- Guardrails fail if a future implementation collapses those meaningful records
  without an explicit contract change.
- JSON and human fixture output remain deterministic.
- The feature does not introduce new user-facing claims, scores, rankings, or
  semantic certainty.

## Edge cases

- Same source and target with `contains` plus `reference` evidence.
- Same source and target with `contains` plus `call` evidence where current
  providers emit it.
- Repeated endpoints from different provider lanes or evidence snippets.
- Unsupported relationship lanes remain zero-record cases and are not treated
  as duplicates.
- Exact duplicates, if constructible in a fixture, are asserted only to document
  current behaviour and not to introduce a new deduplication rule.

## Verification

- `git diff --check`
- `zig build test`
- `zig build validate`
- Targeted integration or fixture assertion proving duplicate-looking records
  are preserved.
- Reviewer-owned discovery and execution of credible lint and test gates before
  close-out.

## Non-goals

- No production deduplication implementation.
- No relationship semantics changes.
- No JSON schema or output contract change.
- No human wording change.
- No provider admission, provider algorithm, cap, scoring, ranking, confidence,
  CLI, cache, network, telemetry, release, tag, remote, package, or publish
  change.
