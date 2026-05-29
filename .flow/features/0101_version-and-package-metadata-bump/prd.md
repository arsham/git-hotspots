# PRD: Version and package metadata bump

## Purpose

Update version and package metadata consistently for v0.1.0-alpha.3 release after
release notes are drafted. This prepares the repository for release validation
but must not create tags, publish packages, or push remote state.

## Requirements

- REQ-001: Update all repo-owned version surfaces for v0.1.0-alpha.3 in a
  consistent way.
- REQ-002: Keep release-note/changelog wording from feature 0100 aligned with
  the chosen version.
- REQ-003: Update package metadata, man/help/docs/version references, and any
  local packaging anchors required by existing validation.
- REQ-004: Do not modify runtime feature behaviour, scoring, report schemas, or
  provider support claims except where a version string is the only change.
- REQ-005: Do not create or push a tag, GitHub release, package publication, or
  remote release artefact.
- REQ-006: Preserve local-first defaults and no-network validation behaviour.
- REQ-007: Run the validation commands required by the dispatch contract,
  including version consistency and docs/man surface checks.
- REQ-008: Leave a clear durable note for the following validation feature about
  what version surfaces changed.

## Edge cases

- If multiple version anchors disagree, update all owned anchors in one atomic
  commit or stop with a blocker naming the unresolved owner.
- If a generated artefact is required, use the repo's existing generator or
  validation path; do not hand-edit generated output blindly.
- If the accidental deleted tag affects version choice, stop and ask rather than
  retagging.

## Verification notes

- Verify `zig build validate` or the narrower version/package checks named by
  the contract.
- Verify no tag or remote release side effect occurred.
- Verify package outputs remain ignored/local unless the repo already tracks the
  metadata file.
