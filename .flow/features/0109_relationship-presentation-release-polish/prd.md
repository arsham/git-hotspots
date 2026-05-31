# Relationship presentation release polish

## Summary

Polish the public documentation and validation guardrails for the completed
relationship presentation workflow. The prior slices added caveat compaction,
relationship uncertainty summaries, provider-cap wording, and deduplication
guardrails. This slice makes sure those behaviours read coherently in the
release-facing docs and examples without changing runtime behaviour.

## Requirements

- REQ-001: Review the relationship presentation story across `README.md`,
  `docs/user-guide.md`, `man/git-hotspots.1`, CLI help text fixtures, and
  validation assertions.
- REQ-002: Tighten wording only where the combined caveat compaction,
  uncertainty summary, provider-cap wording, and dedup guardrails need clearer
  user-facing explanation.
- REQ-003: Preserve the evidence-only framing: relationship output is bounded
  local syntax evidence, not call-graph truth, dependency proof, type checking,
  ownership, code-quality judgement, developer metrics, or bug prediction.
- REQ-004: Preserve CLI flags, option names, report schema, JSON fields,
  scoring, ranking, confidence, provider admission, relationship semantics,
  cap algorithms, cache behaviour, network behaviour, telemetry, release state,
  tags, remotes, packages, and publishing behaviour.
- REQ-005: If documentation wording changes, update the corresponding docs/man
  validation checks or golden fixtures so the public claims remain guarded.
- REQ-006: If no wording changes are needed for a surface, record evidence that
  it was checked and intentionally left unchanged.
- REQ-007: Do not add new runtime behaviour, examples that require network or
  remote enrichment, or claims that relationship evidence is complete semantic
  analysis.
- REQ-008: Validate the final state with `git diff --check`, `zig build test`,
  and `zig build validate`; reviewer should discover and run any stronger
  credible gates before close-out.

## Acceptance

- The combined relationship presentation workflow is coherent in README,
  user guide, man page, and validation surfaces.
- Any docs changes are narrow, factual, and consistent with current output.
- No runtime, JSON, CLI, provider, scoring, ranking, release, package, cache,
  network, or telemetry surface changes.
- Validation guards any updated public wording or examples.

## Edge cases

- If the docs are already clear, the runner may make a test/validation-only or
  no-code/no-doc evidence pass, but must record checked surfaces durably.
- If CLI help text already communicates the relationship workflow accurately,
  do not churn help output solely for wording preference.
- If a docs update would imply a behavioural contract not already implemented,
  stop and route to same-feature follow-up or replanning.

## Verification

- `git diff --check`
- `zig build test`
- `zig build validate`
- Documentation/man validation checks when docs or man text changes
- Reviewer-owned credible gate discovery before close-out
