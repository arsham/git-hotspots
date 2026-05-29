# Relation provider conformance harness

## Summary

Create a shared internal conformance harness for relationship providers before
adding more language lanes. The harness makes future provider additions safer by
checking common relation evidence behaviour once: relation kinds, unresolved and
unknown targets, unsupported languages, provider failure, caps, caveats,
privacy, duplicate merging, and deterministic ordering.

This feature changes internal tests, fixtures, helper code, and validation only.
It must not add public language support claims or alter file ranking, symbol
ranking, scoring, cache behaviour, network behaviour, telemetry, or report
schema semantics.

## Requirements

- REQ-001 - Add reusable conformance checks for provider-neutral relationship
  evidence candidates.
- REQ-002 - Cover `contains`, `reference`, `call`, `import_include`,
  `unresolved`, and `unknown` where the existing lanes can exercise them.
- REQ-003 - Cover unsupported language or unsupported provider behaviour without
  breaking file-level hotspot analysis.
- REQ-004 - Cover provider failure, parse failure, cap reached, duplicate or
  multi-pass caveat merging, and deterministic ordering.
- REQ-005 - Cover privacy checks so candidates and fixtures do not expose
  absolute paths, remotes, authors, emails, source snippets, parser diagnostics,
  raw private reports, or commit messages.
- REQ-006 - Exercise existing Python, JavaScript, TypeScript, TSX, and Rust
  relationship lanes through the harness where practical.
- REQ-007 - Preserve current public report semantics, capability claims, and
  ranking/scoring behaviour.
- REQ-008 - Wire the harness into `zig build test` and preserve or add
  validation coverage in `zig build validate` where suitable.
- REQ-009 - Record fresh validation evidence and a privacy-safe smoke record or
  explicit skip reason.

## Edge cases

- A provider supports current symbols but not relationship evidence.
- A provider emits unresolved evidence for a syntactic target.
- A provider emits relation-like syntax that cannot be safely classified.
- A cap is reached while other candidate files still complete.
- Multiple caveats merge without nondeterministic ordering.
- Existing public fixtures must stay stable unless the harness intentionally
  exposes an already-approved invariant.

## Verification

- `git diff --check`
- `zig fmt --check build.zig src tests`
- `zig build test`
- `zig build validate`
- Privacy-safe smoke or explicit skip reason.
