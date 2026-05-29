# Zig relationship provider feasibility proof

## Summary

Evaluate Zig relationship evidence after Go and Lua close. Zig has strong
dogfood value for this repository, but syntax-only relation extraction must be
honest about comptime, containers, imports, methods, namespace lookup, and build
graph limitations.

This feature may implement a conservative internal Zig relationship provider
proof only if it satisfies the shared admission bar. If not, it must record a
durable no-admit feasibility outcome with clear reasons. Public Zig relationship
support claims must stay unchanged until the later matrix refresh feature.

## Requirements

- REQ-001 - Depend on closed features 0091, 0092, and 0093.
- REQ-002 - Assess Zig feasibility against the shared provider admission bar
  before implementing public-facing support.
- REQ-003 - Use existing local Zig parser and current-symbol support as the
  syntax basis; do not require network access, Zig package lookup, build graph
  evaluation, hosted services, runtime LLMs, or mandatory cache truth.
- REQ-004 - If implemented, emit provider-neutral relation candidates for safe
  `contains`, `import_include` from `@import`-like syntax, simple call or
  reference-like syntax, `unresolved`, and `unknown` evidence.
- REQ-005 - If not safely implementable, record a no-admit outcome that names
  failed criteria and leaves validation green.
- REQ-006 - Attach Zig caveats for comptime, namespace lookup, containers,
  methods, imports, build graph meaning, generated code, parser failures, and
  cap hits where relevant.
- REQ-007 - Exercise the implemented proof or no-admit decision through the
  shared conformance harness and deterministic fixture evidence.
- REQ-008 - Prove relation evidence remains additive and does not change file
  score, file rank, symbol rank, historical symbol evidence, or public report
  schema semantics.
- REQ-009 - Keep README, user guide, man page, help/explain, capability matrix,
  and public report fixtures from claiming public Zig relationship support in
  this feature.
- REQ-010 - Record fresh `zig build test`, `zig build validate`, and
  privacy-safe dogfood smoke evidence or an explicit skip reason.

## Edge cases

- `@import` string cannot be mapped safely to a repo file.
- Container or namespace access resembles a reference but lacks semantic proof.
- Method-like syntax must not imply type or dispatch truth.
- Comptime constructs and generated code must stay caveated or unknown.
- The honest outcome may be no-admit rather than a partial misleading provider.

## Verification

- `git diff --check`
- `zig fmt --check build.zig src tests`
- `zig build test`
- `zig build validate`
- Privacy-safe this-repo dogfood smoke or explicit skip reason.
