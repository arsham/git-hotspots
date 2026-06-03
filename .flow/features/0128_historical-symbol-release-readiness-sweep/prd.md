# PRD: Historical symbol release readiness sweep

## Summary

Audit the post-alpha.4 historical-symbol surface for release readiness after the
recent fallback-pressure, provider-state, fixture-realism, and aggregate-bound
proof work. The slice is audit/validation first: if the surfaces are already
aligned, produce a durable no-code readiness proof; if stale wording is found,
apply docs/validation-only corrections.

## Requirements

- REQ-001: Inspect the historical-symbol release-facing surfaces for stale or
  contradictory claims, including `README.md`, `docs/user-guide.md`,
  `man/git-hotspots.1`, `CHANGELOG.md`, and historical-symbol audit or matrix
  docs.
- REQ-002: Verify the historical-symbol fixture and validation surfaces remain
  aligned with current truth: provider states, fallback row count, fallback hunk
  pressure, multi-hunk fallback, mixed parsed revision fallback, aggregate bound
  fixture status, and synthetic aggregate-bound proof.
- REQ-003: Preserve the distinction between checked-in fixture realism and
  synthetic test proof; do not imply that fixture goldens prove exceeded-bound
  output when they record `aggregate_record_bound_exceeded: false`.
- REQ-004: If all inspected surfaces are already aligned, create a concise
  tracked readiness/no-change proof artifact that names inspected surfaces,
  commands, and the reason no public wording change is needed.
- REQ-005: If stale wording is found, apply docs and validation-anchor fixes
  only; keep runtime behaviour and report semantics unchanged.
- REQ-006: Do not change runtime logic, CLI flags, JSON schema, scoring,
  ranking, provider admission, fixture golden data, release/tag/package/remote,
  network, telemetry, or cache behaviour.
- REQ-007: Validation must include `git diff --check`, `zig build test`, and
  `zig build validate`; close-out should record whether a second local smoke
  repo was used or a privacy-safe skip reason.

## Acceptance

- ACC-001: A fresh reviewer can tell whether historical-symbol public surfaces
  are release-ready from committed evidence without reading this planning chat.
- ACC-002: Any changed wording stays evidence-only and does not claim semantic
  lineage, ownership, bug prediction, code quality, dependency truth, or
  developer performance.
- ACC-003: If the result is no-code/no-doc-change, the proof artifact is still
  tracked and names the validated surfaces and commands.
- ACC-004: Validation passes and the worktree is clean at close-out.

## Edge cases and non-goals

- This feature does not publish, tag, draft, or mutate a release.
- This feature does not broaden historical-symbol provider admission.
- This feature does not add fixture rows, regenerate golden data, or change
  synthetic aggregate-bound tests unless a validation-anchor-only adjustment is
  required by stale documentation.
- This feature does not redesign historical-symbol UX or add new report fields.

## Verification

- `git diff --check`
- `zig build test`
- `zig build validate`
- `flow validate --target feature:0128`
- `flow validate --target brief:B002`
- close-out smoke via `tools/flow-closeout-check.sh` with a privacy-safe second
  repo or explicit skip reason
