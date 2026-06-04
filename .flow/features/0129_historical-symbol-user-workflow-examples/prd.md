# Historical symbol user workflow examples

## Problem

The historical-symbol surface now has stronger fixture and validation proof for
fallback pressure and aggregate-bound behaviour, but users still need concise
workflow examples that show how to interpret the evidence without overclaiming.
Current documentation explains the concepts, yet it does not provide a compact
walkthrough that connects historical symbol rows, fallback pressure,
aggregate-bound caveats, and the relationship-evidence boundary in one
investigation flow.

## Outcome

Add public documentation examples that help a source-build user interpret
`--historical-symbols` output as deterministic local evidence. The examples
must remain evidence-only: they must not imply bug prediction, code-quality
scoring, dependency truth, ownership analysis, complete call-graph semantics, or
provider certainty.

## Requirements

- REQ-001: Audit existing README, user guide, man page, and relevant docs for
  current historical-symbol workflow examples before editing.
- REQ-002: Add or update concise examples that show how to read historical
  symbol rows and the relationship between file hotspots and retained
  historical-symbol evidence.
- REQ-003: Explain fallback pressure in user-facing terms, including the
  distinction between fallback rows and fallback hunk pressure.
- REQ-004: Explain aggregate-bound caveats in user-facing terms, including the
  difference between checked-in fixture non-exceeded truth and synthetic
  exceeded-bound proof where relevant.
- REQ-005: Explain that historical-symbol evidence and relationship evidence
  are independent evidence streams; neither is dependency truth or complete
  call-graph truth.
- REQ-006: Preserve JSON schema, CLI flags/options, ranking/scoring,
  historical-symbol attribution semantics, provider admission, fixture golden
  data, release/tag/package/remote/network/telemetry/cache behaviour.
- REQ-007: Update validation anchors only if the examples add durable wording
  that should not drift.
- REQ-008: Keep examples project-relative and privacy-safe; do not include
  absolute local paths or private raw report output.
- REQ-009: Run `git diff --check`, `zig build test`, and `zig build validate`.
- REQ-010: Record public readiness as `no_tag_needed`; no release/tag/package
  side effects are allowed.

## Acceptance

- ACC-001: A fresh reader can follow a historical-symbol investigation workflow
  from file hotspot evidence to historical-symbol rows and caveats.
- ACC-002: Fallback pressure and aggregate-bound caveats are explained without
  suggesting nearest-symbol guessing or hidden semantic certainty.
- ACC-003: Relationship evidence is described as optional independent syntax
  evidence, not dependency graph truth or a prerequisite for historical-symbol
  interpretation.
- ACC-004: Public docs remain consistent with current validation helpers and
  fixture realism docs.
- ACC-005: No runtime, CLI, schema, fixture golden, scoring, provider admission,
  release, tag, package, remote, network, telemetry, or cache changes occur.

## Edge cases

- Existing docs may already be sufficient. In that case, deliver a tracked
  no-change or tiny docs proof explaining inspected surfaces and why no wording
  changed.
- If examples require generated command output, use checked-in deterministic
  fixtures or privacy-safe snippets only.
- If a desired example would require runtime or fixture semantic changes, stop
  and record it as a successor slice instead of expanding this feature.

## Verification

- `git diff --check`
- `zig build test`
- `zig build validate`
- `flow validate --target feature:0129`
- `flow validate --target brief:B002`
