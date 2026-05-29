# PRD: Tag preparation checklist

## Purpose

Prepare the explicit tag/release checklist for v0.1.0-alpha.3 after validation
passes. This feature stops before tag creation, push, package publication, or
release announcement unless the operator gives a later explicit approval.

## Requirements

- REQ-001: Create or update a release checklist with the exact proposed tag
  name, target commit, validation evidence references, and rollback/delete-tag
  notes.
- REQ-002: Include the prior accidental `v0.1.0-alpha.3` deletion as an
  operational caution if useful, without private chatter or unnecessary detail.
- REQ-003: State the exact commands that would create and push the tag, but do
  not execute them.
- REQ-004: Require explicit operator confirmation before any future tag, push,
  package publish, GitHub release, or announcement.
- REQ-005: Confirm the working tree is clean and the proposed tag target is the
  intended commit at checklist time.
- REQ-006: Reference release notes, version metadata, and validation evidence
  produced by features 0100, 0101, and 0102.
- REQ-007: Keep the checklist local-first and deterministic; no network action
  beyond read-only status checks unless explicitly approved.
- REQ-008: Run `git diff --check` and the docs/prohibited-claim checks named by
  the dispatch contract.

## Edge cases

- If the proposed tag already exists locally or remotely, stop and ask; do not
  overwrite, delete, or recreate it.
- If `origin/master` changed unexpectedly, stop with a status report.
- If validation evidence is stale, route back to validation instead of preparing
  a tag.

## Verification notes

- Reviewer must confirm no tag exists or was created by this feature.
- Reviewer must confirm checklist commands are inert documentation, not executed
  side effects.
