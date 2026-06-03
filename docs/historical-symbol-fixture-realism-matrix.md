# Historical-symbol fixture realism matrix

This matrix records what the checked-in historical-symbol golden protects. It
is a validation aid, not product scoring or provider-admission truth.

Source fixture:

- repository: `fixtures/symbols`
- command shape: `--symbols --historical-symbols --symbol-limit 2`
- golden files:
  - `fixtures/expected/historical-symbols.json`
  - `fixtures/expected/historical-symbols.md`
  - `fixtures/expected/historical-symbols.txt`

## Coverage matrix

| Coverage category | Fixture evidence | Why it matters |
| --- | --- | --- |
| Parsed revision-local Zig rows | `alpha`, `zebra`, and `target` rows have `provider_state: ok` and line ranges | proves historical hunk attribution can attach changed hunks to revision-local symbols |
| Unsupported file fallback | `src/readme.txt` has `provider_state: unsupported` with file-level fallback | proves unsupported paths remain visible instead of being dropped |
| Unattributed hunk fallback | `src/link.zig` has `provider_state: skipped`, `fallback_count: 1`, and `unattributed hunk fallback` | proves the engine avoids nearest-symbol guessing when attribution is unsafe |
| Fallback hunk pressure | fallback rows carry `fallback_count`; the fixture uses tiny counts while real repos may have a few fallback rows with many fallback hunks | keeps fallback row count separate from fallback hunk pressure |
| Multi-hunk fallback row | `src/example.zig` has `provider_state: skipped`, `fallback_count: 4`, and `unattributed hunk fallback; no nearest-symbol guessing` | proves one skipped row can aggregate multiple unmatched hunks without changing symbol attribution |
| Mixed parsed revision fallback | mixed parsed revisions count only unmatched hunks as fallback pressure while symbol-intersecting hunks stay attributed | prevents symbol-backed hunks from inflating file-level fallback pressure |
| Root-commit caveat | fallback rows include `root commit has no parent pre-image` | keeps root-commit evidence caveated instead of implying a normal hunk comparison |
| Display omission | `human_display.total_count: 8`, `shown_count: 2`, and `omitted_count: 6` | proves table and Markdown can stay compact while JSON keeps bounded records |
| Provider-state spread | summary includes `ok`, `unsupported`, `failed`, and `skipped` states | keeps user-facing provider states from collapsing into success/failure only |
| Failed parser fallback | `src/broken.zig` has `provider_state: failed`, `fallback_count: 1`, and low confidence | proves a supported-language historical blob can fail closed through executable fixture history |
| Aggregate-bound fixture status | `aggregate_record_bound: 128` and `aggregate_record_bound_exceeded: false` | proves checked-in fixture realism reports the bound without pretending the fixture exceeds it |
| Aggregate-bound synthetic proof | `src/historical_symbol_pipeline.zig` has synthetic tests for over-bound truncation and exactly-at-bound non-exceeded behaviour | proves the exceeded-bound branch without inflating checked-in fixture goldens |
| Local-only provenance | provenance records `local_only: true`, `network: false`, `checkout: false`, and `auto_fetch: false` | protects local-first historical analysis semantics |

`timed_out` and `unavailable` remain explicit historical provider-state
coverage gaps, not states proven impossible. See
`docs/historical-provider-state-fixture-gap-audit.md` for the fixture
feasibility decision.

## Reviewer checklist

When historical-symbol fixtures or wording change, reviewers should check this
matrix before approving the update:

1. Regenerate counts from `fixtures/expected/historical-symbols.json` rather
   than editing this document by guesswork.
2. Preserve both symbol-attributed rows and fallback rows unless the active
   feature explicitly reshapes the fixture.
3. Keep unsupported, skipped, fallback rows, and fallback hunk pressure
   distinct. They describe different evidence states and different precision
   signals.
4. For mixed parsed revisions, verify symbol-intersecting hunks remain symbol
   evidence and only unmatched hunks contribute fallback pressure.
5. Do not add `timed_out` or `unavailable` rows without a shaped fixture
   feature and deterministic evidence; timeout or environment-dependent
   provider-unavailable cases are too brittle for goldens.
6. Keep aggregate-bound fixture realism and synthetic proof separate: the
   fixture matrix records `aggregate_record_bound_exceeded: false`, while the
   synthetic pipeline tests prove over-bound truncation and exactly-at-bound
   non-exceeded behaviour.
7. Do not turn historical rows into semantic lineage, ownership, bug, quality,
   dependency, or ranking claims.
8. Re-run `zig build validate` so historical goldens, docs anchors, privacy
   checks, and performance budgets execute together.

## Protected surfaces

This document may be updated when fixture coverage changes. It must not change
runtime behaviour, CLI flags, JSON schema, scoring, provider admission,
relationship evidence, release/tag/package state, network access, telemetry, or
cache semantics.
