# Provider-specific caveat wording audit

## Purpose

Audit caveat wording across admitted relationship provider lanes and produce concrete follow-up recommendations without changing runtime behaviour.

## Requirements

- REQ-001: Audit caveat wording for Python, JavaScript, Go, Lua, Rust, TSX, TypeScript, and Zig relationship lanes.
- REQ-002: Compare repeated, confusing, overly broad, missing, or lane-inconsistent caveat wording using checked-in goldens and validation outputs.
- REQ-003: Classify findings as no action, docs wording candidate, fixture candidate, validation candidate, or runtime/provider candidate.
- REQ-004: Preserve current runtime behaviour, CLI flags, JSON schema, report fields, provider algorithms, provider admission, relation semantics, scoring, ranking, caps, cache, network, telemetry, release, tag, remote, package, and publish behaviour.
- REQ-005: Record privacy-safe bounded counts and project-relative paths only.
- REQ-006: Do not make provider wording changes in this audit unless a typo-only public doc fix is necessary and explicitly validated.
- REQ-007: Produce a durable audit document with successor recommendations.
- REQ-008: Run `git diff --check`, `zig build test`, and `zig build validate` before close-out.

## Acceptance

- The audit identifies whether provider-specific caveats are coherent enough for the current public surface.
- Follow-up recommendations are actionable and bounded.
- No runtime/provider/report semantic changes are made.

## Edge cases

- Some lane differences may be intentional because the providers expose different syntax evidence.
- A caveat may be noisy but still required for evidence honesty.
- Unsupported language behaviour must not be conflated with admitted provider caveats.

## Verification

- `git diff --check`
- `zig build test`
- `zig build validate`
- Reviewer-owned discovery and execution of credible lint/test gates.
