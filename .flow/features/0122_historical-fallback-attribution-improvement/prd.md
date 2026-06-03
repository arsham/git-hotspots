# Historical fallback attribution improvement

## Problem

Historical-symbol evidence now covers successful, unsupported, skipped, and
failed provider states, but real-repository audits still show fallback hunk
pressure can be high. Some fallback pressure is expected and honest, but the
next product improvement should determine whether one narrow attribution case
can reduce avoidable fallback without guessing.

The implementation must improve precision only where evidence is deterministic.
It must not infer nearest symbols for unsafe hunks, invent historical lineage, or
turn fallback pressure into scoring, ranking, ownership, dependency, or bug
prediction claims.

## Outcome

Reduce one concrete, audit-backed historical-symbol fallback case by improving
revision-local hunk-to-symbol attribution or by proving that no safe improvement
exists for that case.

The delivered change should be small enough to explain in fixtures and should
preserve all existing provider-state, fallback-pressure, and caveat semantics.

## Requirements

REQ-001: Inspect current historical fallback rows and attribution logic before
changing code.

REQ-002: Select one deterministic improvement case from fixture or this-repo
historical-symbol evidence where fallback can be reduced without nearest-symbol
guessing.

REQ-003: If no safe deterministic case exists, stop with a docs-only proof and
route reconcile to follow-up planning rather than forcing a runtime change.

REQ-004: Any runtime change must preserve current JSON schema, CLI flags,
provider admission, scoring/ranking behaviour, cache/network/telemetry policy,
and release/package/tag surfaces.

REQ-005: Any improved attribution must be based on revision-local parsed symbol
ranges, hunk intersection, or another deterministic evidence rule documented in
the code/tests.

REQ-006: The implementation must not attribute unsafe fallback hunks to nearest
symbols or adjacent symbols without direct evidence.

REQ-007: Existing fallback rows for unsupported, skipped, and failed provider
states must remain present where those states still apply.

REQ-008: Historical provider-state validation must continue to cover `ok`,
`unsupported`, `skipped`, `failed`, and explicitly uncovered `timed_out` /
`unavailable`.

REQ-009: Fallback-pressure validation must continue to distinguish fallback row
count from fallback hunk pressure.

REQ-010: Fixture/golden updates must cover the improved case in table, JSON,
and Markdown outputs when behaviour changes.

REQ-011: Documentation or validation metadata must be updated only when the
behaviour change affects the historical-symbol fixture realism or interpretive
contract.

REQ-012: The change must remain local-first and deterministic with no network,
remote enrichment, telemetry, default cache requirement, package publishing, or
release automation.

REQ-013: Close-out must include `git diff --check`, `zig build test`, and
`zig build validate`; high-assurance review should also run or justify
`zig build validate-all`.

## Acceptance

- A fresh runner can identify the selected fallback case and why it is safe or
  unsafe to improve without planner chat.
- Either one deterministic fallback attribution improvement lands with fixture
  proof, or a proof document explains why this slice should not change runtime.
- Existing provider-state and fallback-pressure guards pass.
- Human and JSON outputs remain evidence-only and do not imply lineage,
  dependency truth, bug prediction, code quality, ownership, or developer
  performance.
- The repo is clean after close-out and no release/tag/package/remote side
  effect occurs.

## Edge cases

- Unsupported files must stay fallback evidence, not symbol evidence.
- Parser failed rows must stay failed fallback evidence.
- Skipped root-commit or unattributed hunks must not be forced into a symbol.
- Multi-symbol or overlapping symbol ranges must use existing deterministic
  ordering or explicit evidence; ambiguous cases remain fallback.
- Large aggregate output must keep existing bounds and omission semantics.

## Verification notes

Required commands:

```sh
git diff --check
zig build test
zig build validate
```

Reviewer should inspect historical-symbol fixture goldens and the new or changed
logic to prove fallback pressure improved only for a deterministic case. If the
runner chooses the no-runtime-change branch, reviewer should verify the proof is
specific, source-backed, and does not hide an implementation opportunity.
