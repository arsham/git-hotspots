# CI workflow reliability proof

## Overview

Verify that the GitHub Actions CI workflow introduced by the CI pipeline hardening slice works on the hosted GitHub runner after the cleaned local stack is pushed. This is a release/admin proof slice, not a product runtime change.

The feature exists to close the confidence gap between local validation (`zig build validate`, `zig build validate-all`) and the actual hosted CI workflow that now delegates to `zig build validate-all`.

## Requirements

- REQ-001: Push the current cleaned `master` branch to `origin` so the hosted workflow runs on the commit containing `.github/workflows/ci.yml` using `zig build validate-all`.
- REQ-002: Inspect the GitHub Actions run for the pushed commit and record whether the hosted workflow completed successfully.
- REQ-003: If the hosted workflow passes, record concise evidence: commit SHA, workflow name, run id or URL, conclusion, and checked command surface.
- REQ-004: If the hosted workflow fails, do not paper over it; capture the failing job/step/log summary and route to a follow-up repair slice rather than broadening this proof slice.
- REQ-005: Preserve runtime behaviour, CLI flags/options, report schemas, provider semantics, scoring/ranking, cache/network/telemetry behaviour, release/tag/package/publishing surfaces, and product docs unless CI evidence exposes a directly relevant issue.
- REQ-006: Do not create tags, publish releases, upload assets, publish packages, or mutate remotes other than the intended `git push origin master` required to trigger CI.
- REQ-007: Keep evidence privacy-safe: record GitHub run identifiers/URLs and bounded summaries, not large logs or private absolute local paths.
- REQ-008: Confirm local repo state is clean before and after the proof, except for Flow lifecycle state while the run is active.

## Acceptance

- The feature closes with one of two explicit outcomes:
  - hosted CI passed for the pushed commit, with durable evidence recorded; or
  - hosted CI failed, with a narrow follow-up repair target recorded and this run reconciled accordingly.
- Any external side effect is limited to pushing `master` to `origin` and read-only GitHub Actions inspection.
- No release, tag, asset, or package publication occurs.

## Edge cases

- If GitHub Actions is delayed, wait boundedly using GitHub CLI or report a blocker rather than polling indefinitely.
- If multiple runs exist, use the run associated with the pushed commit SHA and workflow file.
- If authentication is missing for GitHub CLI, stop with a clear blocker and commands the operator can run manually.
- If the push is rejected because remote moved, stop and report; do not rebase, merge, or force-push without explicit approval.

## Verification

- `git status --short` before and after.
- `git push origin master` for the intended branch update.
- `gh run list` / `gh run view` or equivalent read-only GitHub inspection for the pushed commit.
- `flow validate --target feature:0118` and run validation during close-out.
