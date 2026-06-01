# Historical symbol and relationship workflow guide

## Purpose

Explain how to use historical-symbol evidence and relationship evidence together as investigation prompts without expanding product claims.

## Requirements

- REQ-001: Add or update documentation that explains a combined workflow for `--historical-symbols` and `--symbol-relationships`.
- REQ-002: Make clear that historical-symbol attribution and relationship records are independent local evidence streams with caveats, not dependency truth, call-graph truth, ownership analysis, quality scoring, or bug prediction.
- REQ-003: Include a small sequence for choosing scope, enabling symbols, inspecting historical evidence, then reading relationship evidence.
- REQ-004: Reference existing report surfaces and examples without changing CLI flags, JSON schema, report fields, provider behaviour, scoring, ranking, caps, cache, network, telemetry, release, tag, remote, package, or publish behaviour.
- REQ-005: Use project-relative examples and privacy-safe snippets only.
- REQ-006: Update validation if docs/man/help guardrails need to protect the new workflow wording.
- REQ-007: Run `git diff --check`, `zig build test`, and `zig build validate` before close-out.

## Acceptance

- A user can understand how to combine historical-symbol and relationship evidence for investigation.
- The guide preserves deterministic, local-first, evidence-only framing.
- No runtime or schema behaviour changes.

## Edge cases

- Unsupported provider lanes must be presented as unavailable enrichment, not failure of hotspot analysis.
- Relationship evidence should not be described as explaining why historical churn occurred.
- Historical attribution caveats must remain visible when paired with relationship evidence.

## Verification

- `git diff --check`
- `zig build test`
- `zig build validate`
- Reviewer-owned discovery and execution of credible lint/test gates.
