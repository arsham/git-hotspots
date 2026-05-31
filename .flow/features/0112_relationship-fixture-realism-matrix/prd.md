# Relationship fixture realism matrix

## Problem

The relationship fixture set now covers many admitted provider lanes, but the
coverage expectations are implicit. The 0110 realism audit and 0111 Zig golden
work showed that fixture representativeness can drift silently when a lane is
small, when a cap is not stable enough for a public golden, or when a lane lacks
uncertainty and omission coverage.

## Outcome

Add a durable validation or documentation matrix that records expected
relationship-golden coverage categories per admitted lane. The matrix should
help future provider/report changes preserve representative fixture coverage
without changing runtime behaviour or public evidence semantics.

## Requirements

- REQ-001: Inventory every admitted relationship golden lane: Python,
  JavaScript, Go, Lua, Rust, TSX, TypeScript, and Zig.
- REQ-002: Record whether each lane covers relation-kind diversity.
- REQ-003: Record whether each lane covers unknown and unresolved evidence.
- REQ-004: Record whether each lane covers human display omissions.
- REQ-005: Record whether each lane covers provider-cap omission, or an explicit
  stable reason when provider-cap coverage is intentionally not represented in
  that golden.
- REQ-006: Record caveat-diversity expectations or observed caveat coverage per
  lane.
- REQ-007: Record whether duplicate-looking relationship guard coverage exists
  for lanes where endpoint repeats are relevant.
- REQ-008: Prefer validation/docs metadata over changing goldens; change a
  golden only if a clear representativeness gap remains and can be made
  deterministic.
- REQ-009: Preserve runtime relationship behaviour, provider algorithms,
  provider admission, relation semantics, sorting, caps, scoring, ranking, and
  confidence.
- REQ-010: Preserve CLI flags/options and JSON schema/report fields.
- REQ-011: Preserve cache, network, telemetry, release, tag, remote, package,
  and publish behaviour.
- REQ-012: Keep all recorded evidence privacy-safe: no private paths, remotes,
  identities, diagnostics, raw reports, or commit messages.
- REQ-013: Update validation so matrix drift is checked or so the matrix is
  explicitly reviewed by `zig build validate`.
- REQ-014: Run `git diff --check`, `zig build test`, and `zig build validate`
  before close-out.

## Acceptance

- A relationship fixture realism matrix exists in docs or validation metadata.
- The matrix covers Python, JavaScript, Go, Lua, Rust, TSX, TypeScript, and Zig.
- Provider-cap omission is represented either by stable deterministic coverage
  or by explicit lane-level rationale.
- Validation detects or reviews matrix drift.
- No runtime, provider, CLI, JSON schema, scoring, cache, network, telemetry,
  release, tag, remote, package, or publish surface changes.

## Edge cases

- Provider-cap coverage may be intentionally absent for a lane when stable
  public fixture coverage would be oversized or coupled to implementation caps.
- A lane may have limited kind diversity because that provider or fixture has a
  deliberately narrow stable sample; record the reason instead of inflating the
  fixture.
- Duplicate-looking guardrails may be cross-lane rather than lane-local; record
  coverage honestly.

## Verification

- `git diff --check`
- `zig build test`
- `zig build validate`
- Review changed paths to confirm no runtime/provider/CLI/schema/scoring or
  release surfaces changed unless explicitly approved.
