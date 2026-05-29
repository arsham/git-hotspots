# Provider failure and caveat audit

## Summary

Audit provider failure handling and caveat wording across symbol, historical
symbol, and relationship evidence. The feature should make degradation states
consistent and easy to verify without changing ranking or scoring semantics.

## Requirements

- REQ-001: Depend on the 0096 performance and benchmark harness being closed.
- REQ-002: Inventory provider failure states for unsupported language, parse
  failure, oversized input, cap reached, missing optional provider, binary or
  non-text input, shallow history, and partial history.
- REQ-003: Normalize caveat wording across table, JSON, Markdown, explain, and
  validation summaries where those surfaces already expose the caveat.
- REQ-004: Preserve evidence-only wording; caveats must not imply bug
  prediction, code-quality scoring, ownership, developer judgement, or full
  semantic certainty.
- REQ-005: Preserve provider-specific nuance where generic wording would hide an
  important limitation.
- REQ-006: Keep default runtime local-first and deterministic; no network,
  telemetry, remote enrichment, or cache requirement.
- REQ-007: Add or update fixtures and validation assertions proving consistent
  caveat rendering and deterministic ordering.
- REQ-008: Ensure unsupported providers degrade without changing unrelated
  hotspot ranking or scoring.
- REQ-009: Include at least one real-repo or privacy-safe skip evidence path if
  a failure mode cannot be exercised safely in a local repo.
- REQ-010: `zig build test` passes.
- REQ-011: `zig build validate` passes.
- REQ-012: `git diff --check` passes.

## Edge cases

- Multiple caveats on the same file or symbol should merge deterministically.
- Provider-specific caveats should not be duplicated across aggregate and row
  level output unless both are intentionally needed.
- Public docs must stay aligned with inspected capability behaviour.

## Verification notes

Close-out requires proof that caveat rendering is coordinated across affected
surfaces and that unrelated public output does not drift.
