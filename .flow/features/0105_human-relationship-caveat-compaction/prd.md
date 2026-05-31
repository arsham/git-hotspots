# Human relationship caveat compaction

## Problem

Feature 0104 found that relationship evidence is broadly useful but noisy in
human table and Markdown output because the same caveat text repeats on many
relationship rows. JSON needs per-record caveats for machine consumers, but
human surfaces should make repeated caveats easier to scan without weakening the
syntax-evidence warning.

## Outcome

Human table and Markdown relationship output present repeated relationship
caveats through deterministic compact summaries and row references, while JSON
schema and record-level caveats remain unchanged. Users can still see that
relationship rows are caveated syntax evidence, but repeated text no longer
dominates the human report.

## Requirements

- REQ-001: Add provider-neutral caveat compaction for relationship evidence in
  human table output.
- REQ-002: Add provider-neutral caveat compaction for relationship evidence in
  Markdown output.
- REQ-003: Preserve JSON report schema, JSON relationship records, and JSON
  per-record caveat arrays exactly except for changes that are already produced
  by existing deterministic ordering or fixture setup.
- REQ-004: Preserve CLI flags, option combinations, file and symbol ranking,
  scoring, confidence, provider admission, relationship semantics, cache
  behaviour, network behaviour, telemetry behaviour, release state, tags,
  remotes, and package artefacts.
- REQ-005: Keep relationship evidence framed as bounded local syntax/provider
  evidence. Do not claim call-graph truth, dependency proof, package resolution,
  type checking, ownership, code quality, maintainer responsibility, developer
  performance, or bug prediction.
- REQ-006: Render each unique relationship caveat once per appropriate human
  relationship block or provider lane, with a deterministic stable marker or
  label that lets row-level evidence refer back to the caveat.
- REQ-007: Include enough row-level indication in table and Markdown output for
  users to know which relationships are caveated, even when full caveat text is
  grouped elsewhere.
- REQ-008: Keep caveat ordering deterministic across repeated identical inputs.
  Prefer first-seen or existing relation sort order, but record the chosen rule
  in implementation comments or tests when non-obvious.
- REQ-009: Distinguish caveat compaction from uncertainty or cap summaries.
  This feature may add caveat grouping, but must not add a new uncertainty
  summary, cap wording redesign, or deduplication rule unless required to keep
  caveat references understandable.
- REQ-010: Update golden fixtures and integration assertions for table and
  Markdown relationship output across representative admitted provider lanes.
- REQ-011: Add or update a deterministic check proving repeated identical human
  relationship output remains byte-stable after compaction.
- REQ-012: Update README, docs/user-guide.md, man/git-hotspots.1, and any
  existing explain/help surface only where they describe human relationship
  caveat presentation. Do not broaden provider support claims.
- REQ-013: Ensure unsupported or no-relationship lanes still render without
  fabricated caveat summaries.
- REQ-014: Record fresh validation evidence for git diff --check, zig build
  test, zig build validate, and at least one privacy-safe relationship output
  smoke covering compact caveats.

## Acceptance

- Human table relationship output uses compact caveat presentation instead of
  repeating the same full caveat text on many rows.
- Markdown relationship output uses compact caveat presentation instead of
  repeating the same full caveat text on many rows.
- JSON output remains schema-compatible and keeps record-level caveat evidence.
- Public wording remains local-first, deterministic, caveated, and
  evidence-only.
- Fixtures, integration checks, docs/man/explain surfaces, and validation stay
  aligned with the new human-output presentation.

## Edge cases

- If a relationship row has no caveats, it should not receive a misleading
  caveat marker.
- If a relationship row has multiple caveats, the row reference should preserve
  all relevant markers or make the multi-caveat state clear.
- If a human output block has only one caveat instance, compaction should remain
  readable and not add more noise than the original rendering.
- If an unsupported lane emits zero relationship rows, the report must not add a
  relationship caveat summary that implies relationship evidence exists.
- If a provider emits cap or omission caveats, compaction may group the caveat
  text but must not blur provider-cap omission with display-limit omission.
- If table width becomes worse after adding markers, prefer a short stable
  marker and a summary section over long inline text.
- If existing fixtures depend on exact caveat text placement, update them only
  for intentional human-output changes and prove JSON did not drift.

## Verification

The runner should record fresh evidence for:

- git diff --check
- zig build test
- zig build validate
- table and Markdown golden fixture diffs for compact relationship caveats
- JSON fixture or direct command evidence proving relationship records and
  per-record caveats remain present and schema-compatible
- deterministic repeat output for at least one compacted human relationship
  surface
- privacy-safe real-repository or explicit skipped sibling smoke evidence

Reviewer focus should include:

- whether compaction improves human readability without hiding caveats;
- whether JSON compatibility and provider-support claims are protected;
- whether docs and man pages describe the changed human presentation accurately;
- whether the feature stayed within caveat compaction and did not implement the
  later uncertainty summary, cap wording redesign, or deduplication slices.
