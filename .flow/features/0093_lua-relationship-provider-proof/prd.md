# Lua relationship provider proof

## Summary

Add an internal Lua relationship provider proof after the Go proof closes. The
provider may emit bounded syntax-only relationship evidence through the shared
provider-neutral contract, but public Lua relationship support claims must stay
unchanged until the later matrix refresh feature admits the lane.

Lua is dynamic, so the proof must be conservative. It must not claim module
loader truth, package graph truth, metatable semantics, runtime mutation,
ownership, quality, impact, scoring, or bug-prediction truth.

## Requirements

- REQ-001 - Depend on the closed Go proof from feature 0092 and the shared
  conformance harness from feature 0091.
- REQ-002 - Use existing local Lua parser and current-symbol support as the
  syntax basis; do not require network access, package lookups, runtime
  execution, hosted services, runtime LLMs, or mandatory cache truth.
- REQ-003 - Emit provider-neutral relation candidates for safe `contains`,
  `import_include` from `require`-like syntax, call-like syntax,
  table/member reference-like syntax, `unresolved`, and `unknown` evidence.
- REQ-004 - Preserve unresolved targets and dynamic constructs instead of
  fabricating endpoint identity.
- REQ-005 - Attach Lua caveats for dynamic tables, metatables, module loaders,
  runtime mutation, package conventions, generated files, parser failures, and
  cap hits where relevant.
- REQ-006 - Exercise the provider through the shared conformance harness and Lua
  fixture cases for `require`, method-call syntax, table/member access,
  unresolved targets, unknown fallback, provider failure, caps, and deterministic
  ordering.
- REQ-007 - Prove relation evidence remains additive and does not change file
  score, file rank, symbol rank, historical symbol evidence, or public report
  schema semantics.
- REQ-008 - Keep README, user guide, man page, help/explain, capability matrix,
  and public report fixtures from claiming public Lua relationship support in
  this feature.
- REQ-009 - Record fresh `zig build test`, `zig build validate`, and
  privacy-safe smoke evidence or an explicit skip reason.

## Edge cases

- `require` string that cannot be mapped to a file safely.
- Colon-call syntax, table field access, and dynamic key access.
- Metatable or runtime mutation patterns that must remain unknown or caveated.
- Generated files, oversized files, parser failures, and cap hits.
- Existing public report fixtures remain stable until feature 0095.

## Verification

- `git diff --check`
- `zig fmt --check build.zig src tests`
- `zig build test`
- `zig build validate`
- Privacy-safe real-repo smoke or explicit skip reason.
