# Historical fallback pressure golden realism

## Purpose

Improve the representativeness of historical-symbol fallback-pressure fixture
coverage after the fallback-pressure attribution fix. The current golden proves
fallback rows and fallback counts, but its fallback pressure is tiny. Real repo
audits showed that a small number of fallback rows can represent many fallback
hunks, so the fixture should either model that distinction deterministically or
record why a fixture would be brittle.

## Requirements

- REQ-001: Inspect the existing `fixtures/symbols` history and historical-symbol
  golden to determine whether a deterministic multi-hunk fallback-pressure case
  can be added without changing runtime semantics.
- REQ-002: If feasible, add the smallest deterministic fixture/golden case where
  one fallback row carries multiple fallback hunks.
- REQ-003: If not feasible, add a tracked no-change proof explaining why the
  checked-in fixture should remain tiny and why real-repo audit evidence is
  sufficient for now.
- REQ-004: Preserve the 0124 behaviour: mixed parsed revisions must count only
  unmatched hunks as fallback pressure while symbol-intersecting hunks remain
  attributed.
- REQ-005: Preserve whole-file fallback semantics for unsupported, skipped, and
  failed provider states.
- REQ-006: Update `fixtures/expected/historical-symbols.{json,md,txt}` together
  if fixture output changes.
- REQ-007: Update `docs/historical-symbol-fixture-realism-matrix.md` and related
  validation anchors when fixture coverage or rationale changes.
- REQ-008: Keep `timed_out` and `unavailable` explicitly uncovered unless a
  separately shaped deterministic seam exists.
- REQ-009: Do not change CLI flags, JSON schema, scoring, ranking, provider
  admission, release/tag/package/remote behaviour, network access, telemetry, or
  cache semantics.
- REQ-010: Validate with `git diff --check`, `zig build test`, and
  `zig build validate` at minimum.

## Acceptance

- ACC-001: The feature either lands deterministic multi-hunk fallback-pressure
  fixture coverage or lands a tracked no-change proof.
- ACC-002: Historical-symbol goldens, docs, and validation agree after the
  change or no-change proof.
- ACC-003: Mixed parsed revision behaviour from feature 0124 remains protected.
- ACC-004: Protected surfaces remain unchanged.

## Edge cases

- A fixture edit that changes provider state counts is acceptable only if the
  change is intentional, deterministic, and documented in the matrix.
- A fixture edit that requires nearest-symbol guessing, semantic lineage claims,
  timeout injection, unavailable-provider injection, or brittle environment
  setup is out of scope.
- If a feasible fixture would be larger than the current bounded golden can
  explain clearly, prefer a no-change proof over a confusing fixture.

## Verification

- Run `git diff --check`.
- Run `zig build test`.
- Run `zig build validate`.
- If fixture output changes, reviewers must inspect the historical-symbol JSON,
  Markdown, and table goldens for agreement.
- If no fixture output changes, reviewers must inspect the tracked proof artifact
  and verify it references the deterministic seam that was considered.
