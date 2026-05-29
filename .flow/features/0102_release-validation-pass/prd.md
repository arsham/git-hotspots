# PRD: Release validation pass

## Purpose

Run and record a release-readiness validation pass after release notes and
version metadata are prepared. This feature proves the repository is ready for a
future explicit tag decision, without tagging or publishing.

## Requirements

- REQ-001: Run the full release validation ladder named by the dispatch
  contract, including `zig build validate` and any release/package dogfood checks
  already supported by the repo.
- REQ-002: Include source-install or package dogfood evidence when supported by
  existing tooling.
- REQ-003: Include privacy-safe real-repo smoke evidence using labels and
  bounded counts only; do not commit raw private reports or absolute local
  paths.
- REQ-004: Verify deterministic fixture JSON/Markdown and performance budget
  checks still pass.
- REQ-005: Verify prohibited-claim, docs/man/help, provider capability matrix,
  and local-only/runtime dependency checks still pass.
- REQ-006: Record durable validation evidence in Flow run state and any release
  checklist artefact if one exists from prior features.
- REQ-007: Do not change product behaviour unless validation exposes a direct
  release-blocking bug; if it does, keep the fix narrow and record it.
- REQ-008: Do not create or push tags, releases, package uploads, or remote
  artefacts.

## Edge cases

- If a sibling/local smoke repo is unavailable, record an explicit privacy-safe
  skip reason accepted by existing validation rules.
- If validation is too slow or flaky, stop with evidence and route to planning
  instead of weakening checks silently.
- If validation reveals a stale public claim, fix the claim or stop with a
  blocker before release preparation continues.

## Verification notes

- Close-out requires durable command evidence, not only runner prose.
- Reviewer should independently spot-check the validation evidence and changed
  release artefacts.
