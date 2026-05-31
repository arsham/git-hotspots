# Provider cap wording hardening

## Summary

Human relationship output already shows compact caveats and uncertainty
summaries. The remaining presentation gap is that display-limit omissions and
provider-cap omissions can still read similarly in table and Markdown output.
This feature makes those two forms of partialness visibly distinct for humans
without changing JSON, provider algorithms, CLI flags, scoring, ranking, or
relationship semantics.

## Requirements

- REQ-001: Table output for `--symbol-relationships` MUST distinguish
  display-limit omissions from provider-cap omissions in human wording.
- REQ-002: Markdown output for `--symbol-relationships` MUST distinguish
  display-limit omissions from provider-cap omissions in human wording.
- REQ-003: Display-limit omission wording MUST describe a presentation/sample
  limit, not missing provider evidence.
- REQ-004: Provider-cap omission wording MUST describe partial provider
  evidence, not merely hidden rows.
- REQ-005: When both display-limit omissions and provider-cap omissions are
  present, human output MUST expose both without merging their counts.
- REQ-006: When only display-limit omissions are present, human output MUST NOT
  imply provider cap truncation.
- REQ-007: When only provider-cap omissions are present, human output MUST NOT
  imply the omitted count is only a display sample choice.
- REQ-008: When neither omission type is present, human output MUST NOT add
  noisy zero-value cap wording.
- REQ-009: JSON report fields, schema, relationship records, per-record caveats,
  and existing cap fields MUST remain compatible and unchanged unless existing
  generated values naturally reflect unchanged data.
- REQ-010: The provider cap algorithm, record cap, display limit behaviour,
  ordering, scoring, ranking, confidence, and provider admission matrix MUST NOT
  change.
- REQ-011: CLI flags, option validation, diagnostics, and default behaviours
  MUST NOT change.
- REQ-012: Documentation and man-page wording MUST describe the distinction as
  deterministic syntax evidence and MUST NOT imply call-graph truth, dependency
  proof, ownership, code quality, developer metrics, or bug prediction.
- REQ-013: Golden fixtures or equivalent integration assertions MUST cover table
  and Markdown wording for display-limit omissions, provider-cap omissions, and
  their distinction.
- REQ-014: Validation MUST include `git diff --check`, `zig build test`, and
  `zig build validate`; close-out review MUST independently discover and run
  credible project lint and test gates.

## Acceptance

- Table and Markdown relationship reports make display-limit omissions and
  provider-cap omissions visibly different.
- JSON output remains compatible and keeps record-level evidence unchanged.
- Existing uncertainty summaries and compact caveat markers remain present.
- Fixture and documentation updates prove the wording without expanding public
  claims.

## Edge cases

- A lane has many emitted records but no provider cap: show only display/sample
  omission wording where rows are hidden by the human output limit.
- A lane reaches the provider cap: state that provider evidence is partial even
  if only a few rows are shown.
- A lane has no relationship rows: do not fabricate omission or cap summaries.
- Unsupported relationship lanes stay unsupported and do not gain cap wording.

## Verification notes

- Compare table, Markdown, and JSON fixtures for relationship output.
- JSON compatibility should be checked by fixture diff and validation scan: no
  new human-summary-only keys should be required in JSON.
- Real-repository validation may use the existing default validation/dogfood
  ladder; raw private reports must not be committed or printed.
