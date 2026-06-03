# Historical failed-state fixture implementation

## Requirements

- REQ-001: Add deterministic historical-symbol fixture coverage for
  `provider_state: failed` using a supported-language historical blob that
  fails parsing through the existing historical provider path.
- REQ-002: The fixture must not depend on runtime injection, wall-clock timing,
  missing local dependencies, missing providers, remotes, absolute paths, raw
  parser diagnostics, author identities, emails, or commit messages.
- REQ-003: Update historical-symbol table, JSON, and Markdown goldens together
  if the fixture output changes.
- REQ-004: Preserve existing historical provider-state coverage for `ok`,
  `unsupported`, and `skipped`.
- REQ-005: Keep `timed_out` and `unavailable` explicitly uncovered unless a
  later feature shapes stable coverage.
- REQ-006: Update historical fixture realism and provider-state gap docs so
  they agree that `failed` is covered and why the remaining states stay
  uncovered.
- REQ-007: Add or update validation anchors only where needed to keep the
  provider-state coverage decision from drifting.
- REQ-008: Do not change CLI flags, JSON schema/report fields, scoring,
  ranking, provider admission, release/tag/package/remote/network/telemetry, or
  cache behaviour.

## Acceptance

- A deterministic fixture or fixture-history change produces at least one
  historical-symbol output row or fallback entry with `provider_state: failed`.
- Checked-in historical-symbol table, JSON, and Markdown goldens match the new
  deterministic output.
- Historical provider-state docs and validation agree that `failed` is covered,
  while `timed_out` and `unavailable` remain uncovered.
- The implementation remains local-first and privacy-safe and does not widen
  product claims.

## Edge cases

- Do not hand-author a failed row without executable fixture evidence.
- Do not use environment-dependent provider absence to force a failed state.
- Do not introduce a runtime test injection seam in this slice.
- If the existing parser path cannot produce `failed` from fixture content,
  stop with a planning-change recommendation instead of broadening scope.

## Verification

- `git diff --check`
- `zig build test`
- `zig build validate`
- `flow validate --target feature:0121`
- `flow validate --target brief:B002`
