# Relationship output sample realism audit

## Requirements

- REQ-001: Produce a docs-only audit at
  `docs/relationship-output-sample-realism-audit.md`.
- REQ-002: Sample current `--symbols --symbol-relationships` output from this
  repository and from one privacy-safe sibling/local repository when available,
  or record an explicit privacy-safe skip reason.
- REQ-003: Compare real-repository output against existing fixture/golden
  coverage for relation kind distribution, unknown and unresolved volume,
  provider-cap omissions, human-display omissions, caveat grouping, and
  duplicate-looking records.
- REQ-004: Record only privacy-safe evidence: command shapes, labels, bounded
  counts, categorical observations, and project-relative paths. Do not include
  raw private reports, absolute local paths, remotes, author identities, emails,
  parser diagnostics, or commit messages.
- REQ-005: Classify findings as no action, fixture-update candidate,
  presentation candidate, provider candidate, or replanning candidate.
- REQ-006: Recommend concrete successor slices only when supported by audit
  evidence.
- REQ-007: Preserve runtime behaviour, CLI flags, JSON schema, report fields,
  provider algorithms, provider admission, relationship semantics, scoring,
  ranking, confidence, caps, cache behaviour, network behaviour, telemetry,
  release state, tags, remotes, packages, and publishing behaviour.
- REQ-008: Do not claim call-graph truth, dependency truth, type checking,
  ownership, code quality, maintainer responsibility, developer performance, or
  bug prediction.
- REQ-009: Validate with `git diff --check`, `zig build test`, and
  `zig build validate`; reviewer should discover and run any stronger credible
  gates before close-out.

## Acceptance

- The audit document exists and is written as evidence, not product marketing.
- It states whether fixture/golden samples still represent realistic
  relationship output after the 0104-0109 presentation work.
- It includes at least this-repo dogfood evidence and either one sibling/local
  repository sample or an explicit privacy-safe skip reason.
- It includes bounded counts or categorical comparisons for relation kinds,
  unknown/unresolved records, omissions, caveats, and duplicate-looking records.
- It recommends the next slice or says no further relationship-output work is
  indicated from this audit.
- No production, CLI, schema, provider, scoring, release, package, remote,
  network, telemetry, or cache surface changes.

## Edge cases

- If no safe sibling/local repository is available, the audit must explain why
  this-repo dogfood evidence is sufficient for this pass and what a future
  external sample should check.
- If real output differs from fixtures because fixtures are intentionally small,
  classify the gap as fixture representativeness rather than a runtime bug
  unless evidence proves incorrect behaviour.
- If sampling exposes a runtime bug, stop and route to same-feature follow-up or
  replanning instead of fixing production code inside this docs-only slice.
- If all sampled outputs remain representative, close out with a no-action
  successor recommendation.

## Verification

- git diff --check
- zig build test
- zig build validate
- Reviewer-owned credible gate discovery before close-out
