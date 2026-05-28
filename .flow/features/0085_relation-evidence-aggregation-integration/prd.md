# Relation evidence aggregation integration

## Summary

Wire internal relation candidates into the bounded analysis pipeline after the
provider proof exists. The feature attaches relation evidence to retained file
and current-symbol candidates internally, proves deterministic aggregation and
performance limits, and keeps all public CLI/report surfaces unchanged.

This is a prerequisite for public relation reporting. It must preserve the
project rule that file-level Git evidence remains product truth and relation
evidence is optional caveated context.

## Requirements

- REQ-001: Feature 0085 depends on feature 0084 and must not execute before the
  internal relation provider proof is closed.
- REQ-002: Integrate relation candidates into the internal analysis pipeline for
  bounded retained file candidates and available current-symbol evidence.
- REQ-003: Candidate selection must be bounded by retained hotspot results,
  inspect scope, or another explicit local candidate set; it must not perform
  whole-repository relation graph discovery by default.
- REQ-004: Shared aggregation must own deduplication, caveat merging, omitted
  counts, cap handling, failure retention, and deterministic sorting.
- REQ-005: Aggregation must preserve unresolved endpoints and provider failures
  instead of dropping them or fabricating precision.
- REQ-006: `co_change` or future adjacency evidence must remain separate from
  `reference`, `call`, `import_include`, and `contains` relation kinds.
- REQ-007: Relation evidence remains internal/test-only in this feature; public
  table, JSON, Markdown, explain, help, README, man page, and user guide output
  must not expose it yet.
- REQ-008: Existing public scoring, ranking, default output, and historical
  symbol report behaviour must not change.
- REQ-009: Aggregation must expose or record bounded caveats for unsupported
  language, provider failure, stale or partial evidence, cap reached, oversized
  input, and filtered scope.
- REQ-010: Tests must prove deterministic ordering independent of map,
  filesystem, provider, or process iteration order.
- REQ-011: Tests must prove relation aggregation absent/unsupported cases still
  leave file and symbol hotspot evidence usable.
- REQ-012: Real-repository smoke must be run on this repository, and on one
  privacy-safe sibling/local repo when available. Evidence must include only
  labels, command shapes, pass/fail status, bounded counts, caveat counts, and
  elapsed time.
- REQ-013: No raw private reports, absolute private paths, source snippets,
  authors, emails, remotes, or commit messages may be committed or printed as
  validation proof.
- REQ-014: The feature must not add network access, telemetry, remote
  enrichment, runtime LLM judgement, hosted services, mandatory cache truth, or
  global LSP requirements.
- REQ-015: B002 must remain linked and valid as the follow-up slice after 0084.
- REQ-016: `git diff --check`, `zig fmt --check build.zig src tests`,
  `zig build test`, and `zig build validate` must pass before close-out.
- REQ-017: `flow validate --target feature:0085` and
  `flow validate --target brief:B002` must pass before close-out.

## Edge cases

- No relation provider succeeds for any retained candidate.
- Some provider outputs are unsupported while others succeed.
- Multiple providers or passes report the same candidate with different caveats.
- Relation caps truncate candidates for one file while other files remain
  complete.
- Candidate files are filtered by scope or include/exclude rules.
- Current-symbol evidence is absent but file-level candidates still exist.
- Historical symbol evidence is present but relation evidence is current-only.
- Real-repository smoke finds no safe sibling repository.

## Verification notes

Close-out requires independent review. The reviewer should check that relation
aggregation is internal-only, bounded, deterministic, privacy-safe, and unable to
change existing public output or ranking. Real-repo smoke evidence must be
privacy-safe and must not include raw report dumps.
