# Historical fallback pressure reduction

## Problem

Historical-symbol output now distinguishes fallback row count from fallback hunk
pressure, and provider budget semantics are guarded. The next product risk is
whether avoidable fallback hunk pressure remains in cases where revision-local
symbol evidence is available and safe to use.

The tool must reduce fallback pressure only when evidence is deterministic and
honest. It must not guess nearest symbols, imply semantic lineage, or hide
file-level fallback evidence.

## Requirements

- REQ-001: Inspect current historical fallback pressure using the checked-in
  fixture and this repository's validation/dogfood surfaces.
- REQ-002: Select at most one concrete fallback-pressure case for improvement.
- REQ-003: The selected case must be evidence-safe: the changed hunk must
  intersect a revision-local symbol range or another deterministic provider
  fact already accepted by the historical attribution model.
- REQ-004: If no safe case exists, deliver a durable no-change proof instead of
  changing attribution behaviour.
- REQ-005: Do not introduce nearest-symbol guessing, adjacency attribution,
  semantic lineage claims, dependency truth, ownership claims, or bug-quality
  scoring claims.
- REQ-006: Preserve JSON schema, CLI flags, scoring/ranking, provider admission,
  cache, network, telemetry, release, tag, package, and remote behaviour.
- REQ-007: If behaviour changes, add or update focused fixture/golden coverage
  showing reduced fallback hunk pressure and preserved caveats.
- REQ-008: If behaviour changes, update historical fixture/docs metadata only
  where current truth changes.
- REQ-009: Keep `timed_out` and `unavailable` provider states out of scope.
- REQ-010: Validation must include `git diff --check`, `zig build test`, and
  `zig build validate`.
- REQ-011: High-assurance review must independently verify protected surfaces
  and evidence safety.

## Acceptance

- A fresh reviewer can identify the inspected fallback-pressure case, the
  decision taken, and the evidence basis.
- Either one narrow safe attribution improvement is delivered with fixture proof,
  or a no-change proof explains why no safe improvement is available now.
- Existing guarded provider-state semantics remain intact: unsupported/skipped
  do not consume failure budget; failed does.
- Historical outputs remain deterministic and local-first.

## Edge cases

- File-level fallback rows may represent many hunks; do not erase that pressure
  unless deterministic symbol attribution replaces it.
- Unsupported, failed, skipped, timed-out, and unavailable provider states are
  not interchangeable.
- Root-commit, binary, large-blob, and no-text-hunk caveats must remain honest.

## Verification

- `git diff --check`
- `zig build test`
- `zig build validate`
- Reviewer-owned protected-surface and fixture/golden checks.
