# PRD: Release notes and changelog draft

## Purpose

Draft the human-facing release notes and changelog entry for v0.1.0-alpha.3
release after the symbol, historical-symbol, relationship-provider, and
hardening work. This is preparation only: it must not tag, publish, push, or
announce a release.

## Requirements

- REQ-001: Create or update release-note/changelog draft artefacts using
  project-relative paths and public-safe language.
- REQ-002: Summarise the file, symbol, historical-symbol, relationship,
  provider-expansion, validation, performance-budget, and documentation work
  without claiming bug prediction, code quality scoring, ownership truth,
  dependency truth, or complete call-graph semantics.
- REQ-003: State local-first, deterministic, evidence-only framing for the
  release.
- REQ-004: Include upgrade/usage notes only for behaviours already implemented
  and validated.
- REQ-005: Mention the accidental `v0.1.0-alpha.3` tag deletion only if a
  durable release checklist needs it; do not expose private operator chatter.
- REQ-006: Do not change runtime logic, CLI semantics, report schema, package
  publishing automation, or version constants.
- REQ-007: Keep the draft suitable for later tag preparation, but stop before
  creating or pushing tags.
- REQ-008: Run `git diff --check` and documentation/prohibited-claim checks
  named by the validation harness or dispatch contract.

## Edge cases

- If no changelog file exists, create the smallest conventional draft location
  that fits existing repo style and document it.
- If release-note wording would require a new claim, either remove the claim or
  route to planning instead of inventing support.
- If validation discovers stale public docs, keep the fix inside documentation
  scope only.

## Verification notes

- Verify the draft is public-safe and local-first.
- Verify no tag, release, upload, publish, or remote mutation occurs.
- Verify changed public prose passes prohibited-claim and privacy scans.
