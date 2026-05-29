# Go relationship provider proof

## Summary

Add an internal Go relationship provider proof after the conformance harness is
closed. The provider may emit bounded syntax-only relationship evidence through
the shared provider-neutral contract, but public Go relationship support claims
must remain unchanged until the later matrix refresh feature admits the lane.

The proof must stay local-first and caveated. It must not claim package graph,
module graph, type checker, method-set, interface, cgo, build-tag, ownership,
quality, impact, scoring, or bug-prediction truth.

## Requirements

- REQ-001 - Depend on the closed conformance harness from feature 0091.
- REQ-002 - Use existing local Go parser and current-symbol support as the
  syntax basis; do not require network access, Go toolchain downloads, hosted
  services, runtime LLMs, or mandatory cache truth.
- REQ-003 - Emit provider-neutral relation candidates for safe `contains`,
  `import_include`, call-like or selector/reference-like syntax, `unresolved`,
  and `unknown` evidence.
- REQ-004 - Preserve unresolved targets instead of fabricating endpoint
  identity.
- REQ-005 - Attach Go caveats for package/module resolution, build tags, cgo,
  method sets, interfaces, type checking, vendored or generated code, and cap
  hits where relevant.
- REQ-006 - Exercise the provider through the shared conformance harness and Go
  fixture cases for imports, aliases, selectors, calls, unresolved targets,
  unknown fallback, provider failure, caps, and deterministic ordering.
- REQ-007 - Prove relation evidence remains additive and does not change file
  score, file rank, symbol rank, historical symbol evidence, or public report
  schema semantics.
- REQ-008 - Keep README, user guide, man page, help/explain, capability matrix,
  and public report fixtures from claiming public Go relationship support in
  this feature.
- REQ-009 - Record fresh `zig build test`, `zig build validate`, and
  privacy-safe smoke evidence or an explicit skip reason.

## Edge cases

- Import alias, dot import, blank import, and unresolved import string.
- Selector call where the receiver target cannot be resolved safely.
- Method-like syntax that must not imply method-set or interface truth.
- Build tags, generated files, cgo, oversized files, and parser failures.
- Cap reached for one file while other candidates still complete.

## Verification

- `git diff --check`
- `zig fmt --check build.zig src tests`
- `zig build test`
- `zig build validate`
- Privacy-safe real-repo smoke or explicit skip reason.
