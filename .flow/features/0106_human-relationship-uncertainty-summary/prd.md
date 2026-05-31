# Human relationship uncertainty summary

## Overview

Relationship output now uses compact row caveat references, but human table and
Markdown surfaces still make uncertainty and partialness harder to scan than the
underlying evidence allows. The 0104 audit identified unresolved and unknown
relation volume, display-limit omissions, and provider-cap omissions as the next
presentation target after caveat compaction.

This feature adds a provider-neutral human-only relationship summary for table
and Markdown output. It keeps JSON record evidence and schema unchanged unless a
future feature explicitly approves a schema addition.

## Requirements

- REQ-001: Add a human-only relationship evidence summary to table output when
  relationship records are present.
- REQ-002: Add the same human-only relationship evidence summary to Markdown
  output when relationship records are present.
- REQ-003: The summary must include total emitted relationship records and
  counts by relation kind for present kinds, including `contains`, `reference`,
  `call`, `import_include`, `unknown`, and `unresolved` when those kinds appear.
- REQ-004: The summary must include unresolved and unknown totals when present,
  without treating either as an error, failure, dependency proof, or call-graph
  result.
- REQ-005: The summary must keep display-limit omissions distinct from
  provider-cap omissions. Display-limit omission is a human sampling choice;
  provider-cap omission means emitted provider evidence is partial.
- REQ-006: The summary must remain provider-neutral and deterministic across
  repeated identical inputs.
- REQ-007: Preserve JSON report schema, JSON relationship records, and
  per-record caveats. Do not add JSON summary fields in this feature.
- REQ-008: Preserve CLI flags, option combinations, file and symbol ranking,
  scoring, confidence, provider admission, relationship semantics, cache
  behaviour, network behaviour, telemetry behaviour, release state, tags,
  remotes, and package artefacts.
- REQ-009: Keep relationship evidence framed as bounded local syntax/provider
  evidence. Do not claim call-graph truth, dependency proof, package
  resolution, type checking, ownership, code quality, maintainer
  responsibility, developer performance, or bug prediction.
- REQ-010: Unsupported or no-relationship outputs must not fabricate a summary
  that implies relationship evidence exists.
- REQ-011: Update golden fixtures and integration assertions for representative
  table and Markdown relationship outputs that include unknown, unresolved,
  display-limit omission, and provider-cap evidence where fixtures make that
  practical.
- REQ-012: Update README, docs/user-guide.md, man/git-hotspots.1, and any
  existing explain/help surface only where they describe human relationship
  summary presentation. Do not broaden provider support claims.
- REQ-013: Record fresh validation evidence for `git diff --check`,
  `zig build test`, `zig build validate`, deterministic repeated human output,
  JSON compatibility, and a privacy-safe close-out smoke or explicit skip
  reason.

## Acceptance

- Human table output includes a concise relationship summary that makes relation
  kind counts and uncertainty totals scannable before or near row samples.
- Human Markdown output includes an equivalent concise relationship summary.
- Display-limit omission and provider-cap omission are visibly different in
  human output.
- JSON output remains compatible and keeps record-level relationship evidence
  and caveats.
- Public wording remains local-first, deterministic, caveated, and
  evidence-only.

## Edge cases

- If a relationship block has zero records, no relationship summary should be
  emitted unless existing report structure already has a no-record placeholder.
- If a relation kind count is zero, omit it from the compact human summary
  unless including it is required to avoid ambiguity.
- If all emitted records are resolved and known, the summary should not imply
  uncertainty exists.
- If both display-limit and provider-cap omissions are present, both must be
  shown distinctly.
- If only display-limit omissions are present, do not imply provider truncation.
- If only provider-cap omissions are present, do not imply the user-selected
  human display limit caused the missing evidence.
- If a provider uses `unknown` for conservative syntax evidence, the summary
  must not relabel it as `call`, `reference`, or dependency evidence.
- If adding the summary makes table width worse, prefer compact wording over
  long inline text.

## Verification

The runner should record fresh evidence for:

- `git diff --check`
- `zig build test`
- `zig build validate`
- table and Markdown golden fixture diffs for relationship summaries
- JSON fixture or direct command evidence proving no schema drift
- deterministic repeated output for at least one summarized human relationship
  surface
- privacy-safe real-repository smoke or explicit close-out skip reason

Reviewer focus should include:

- whether the summary improves uncertainty and partialness readability without
  hiding row evidence or caveats;
- whether display-limit and provider-cap omissions remain distinct;
- whether JSON compatibility and provider-support claims are protected;
- whether docs and man pages describe the changed human presentation accurately;
  and
- whether the feature stayed within uncertainty summary and did not implement
  deduplication, provider admission, scoring, or JSON schema changes.
