# Symbol and relationship workflow docs polish

## Summary

Polish public documentation for symbol, historical-symbol, and relationship
workflows after the performance and caveat hardening features are closed. This
is a documentation and examples feature, not a new analysis capability.

## Requirements

- REQ-001: Depend on 0096, 0097, and 0098 being closed.
- REQ-002: Update README, user guide, developer guide, and man page examples for
  `--symbols`, `--symbol-line-history`, and `--symbol-relationships`.
- REQ-003: Explain when to use file hotspots, current-symbol hotspots,
  historical-symbol evidence, and relationship evidence together.
- REQ-004: Keep all wording evidence-only and investigation-prompt oriented; do
  not claim bug prediction, code-quality scoring, ownership truth, dependency
  truth, call-graph truth, or developer judgement.
- REQ-005: Include local-first and privacy framing for performance, provider,
  and real-repo smoke evidence.
- REQ-006: Keep examples project-relative and avoid committed absolute private
  paths or raw private report output.
- REQ-007: Coordinate docs with help, explain, validation scans, and provider
  capability matrix checks.
- REQ-008: Do not change CLI semantics, report schema, ranking, scoring, or
  provider behaviour except for documentation-only fixture text if validation
  requires it.
- REQ-009: `zig build validate` passes, including docs/man/prohibited-claim and
  provider capability matrix checks.
- REQ-010: `git diff --check` passes.

## Edge cases

- Examples must not imply that relationship evidence is a complete call graph.
- Historical-symbol examples must distinguish current-symbol, line-history, and
  true historical attribution evidence.
- Provider unsupported states should be documented as normal bounded evidence,
  not failure of the whole command.

## Verification notes

Close-out requires docs/man/help/explain validation and prohibited-claim scans.
No browser-visible UI evidence is required.
