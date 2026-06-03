# Historical fallback budget regression matrix

## Requirements

- REQ-001: Add regression coverage for historical provider-failure budget semantics introduced by feature 0122.
- REQ-002: Prove `unsupported` historical provider rows do not consume the provider-failure budget before later supported Zig attribution can run.
- REQ-003: Prove `skipped` historical fallback rows do not consume the provider-failure budget before later supported Zig attribution can run, using a deterministic constructed `FileHunkRecord` case such as no text hunks or an unavailable side before a supported Zig record.
- REQ-004: Prove `failed` historical provider rows still consume the provider-failure budget and can preserve fallback when the budget is exhausted.
- REQ-005: Keep `timed_out` and `unavailable` documented as uncovered unless a deterministic seam already exists; do not introduce timeout or unavailable injection seams in this slice.
- REQ-006: Prefer tests/validation-only changes; runtime code may change only if a direct regression-test seam requires a tiny helper with no behaviour change.
- REQ-007: Preserve the runtime behaviour delivered by feature 0122; this feature should guard that behaviour, not expand historical attribution semantics.
- REQ-008: Preserve JSON schema, CLI flags, provider admission, scoring/ranking, release/tag/package/remote/network/telemetry/cache behaviour, and evidence-only wording.
- REQ-009: Existing historical provider-state and fallback-pressure validation must continue to pass.
- REQ-010: If fixture/golden changes are needed, update table, JSON, Markdown, docs matrix, and validation anchors together.
- REQ-011: Close-out must include `git diff --check`, `zig build test`, and `zig build validate`; reviewer should also run or justify `zig build validate-all`.

## Acceptance

- The regression suite covers unsupported, skipped, and failed budget behaviour; skipped coverage uses the deterministic constructed historical fallback case rather than a timeout/unavailable injection seam.
- The tests prove unsupported/skipped fallback honesty is preserved while supported Zig attribution is not starved by non-failure states.
- The tests prove failed parser states still consume the provider-failure budget.
- No public interface or schema changes occur.
- The repo is clean after close-out.

## Edge cases

- Existing unsupported fallback rows must remain fallback evidence.
- Constructed skipped fallback rows, such as no-text-hunk or side-unavailable fallback records, must not consume provider-failure budget.
- Existing failed fallback rows must remain failed fallback evidence.
- Ambiguous hunks must not be forced into symbol attribution.
- Timeout and unavailable provider states remain out of scope without a separate deterministic seam feature.

## Verification notes

Required commands:

```sh
git diff --check
zig build test
zig build validate
```

Reviewer should inspect `src/historical_symbol_attribution.zig` tests and any fixture/golden updates to prove the budget distinction is guarded without semantic expansion.
