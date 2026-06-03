# Historical symbol precision audit

## Purpose

Audit historical-symbol output quality on real repositories before shaping more
historical-symbol runtime work. The slice is audit-first and documentation-only:
it should identify concrete follow-up work, not change attribution behaviour.

## Requirements

- REQ-001: Sample `--historical-symbols` on this repository with a bounded,
  privacy-safe command shape.
- REQ-002: Use one approved sibling/local repository when available; otherwise
  record a privacy-safe skip reason.
- REQ-003: Compare real output against checked-in historical-symbol fixture
  expectations and `docs/historical-symbol-fixture-realism-matrix.md`.
- REQ-004: Record fallback rate, provider states, unattributed hunks, display
  omissions, aggregate-bound behaviour, and caveat clarity.
- REQ-005: Preserve privacy by recording labels, bounded counts, categorical
  findings, and project-relative paths only.
- REQ-006: Produce `docs/historical-symbol-precision-audit.md` with concrete
  successor recommendations.
- REQ-007: Do not change runtime behaviour, providers, CLI flags, JSON schema,
  scoring, ranking, cache, network, telemetry, release state, tags, remotes,
  packages, or publishing behaviour.
- REQ-008: Validate with `git diff --check` and `zig build validate`.

## Acceptance

- A fresh reader can understand whether real historical-symbol output is useful,
  honest, and fixture-representative.
- The audit names any concrete implementation or fixture follow-up without
  expanding scope inside this feature.
- The repository remains local-first and deterministic; no raw private reports,
  absolute private paths, remotes, author identities, emails, parser diagnostics,
  or commit messages are recorded.

## Edge cases

- If a sibling repository is unavailable or not privacy-safe, record a bounded
  skip reason instead of inventing evidence.
- If real output exposes no precision gap, record that explicitly and recommend
  no implementation follow-up.
- If validation reveals a real bug, stop and route it as a follow-up rather than
  silently fixing runtime behaviour inside the audit.

## Verification

- `git diff --check`
- `zig build validate`
- `flow validate --target feature:0119`
- `flow validate --target brief:B002`
