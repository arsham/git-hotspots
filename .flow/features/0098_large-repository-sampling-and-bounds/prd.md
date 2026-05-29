# Large repository sampling and bounds

## Summary

Harden large-repository behaviour for symbol and relationship evidence. The
feature should prove bounded candidate selection, sampling, and diagnostics when
repos or histories exceed safe local budgets.

## Requirements

- REQ-001: Depend on 0096 and 0097 being closed.
- REQ-002: Define bounded candidate-selection behaviour for large file counts,
  large commit counts, and large changed-file sets.
- REQ-003: Preserve deterministic ordering when limits truncate candidate sets.
- REQ-004: Report truncation, sampling, skipped providers, and capped evidence
  as caveats rather than silently omitting them.
- REQ-005: Keep defaults local-first and offline; do not fetch missing history
  or contact remotes.
- REQ-006: Avoid cache as product truth; the feature may prepare cache-friendly
  seams but must work without cache.
- REQ-007: Add fixture or generated local-repo evidence for large-file and
  large-history bounds without committing raw private report output.
- REQ-008: Add privacy-safe real-repo smoke or a durable skip reason when no
  suitable sibling repo is available.
- REQ-009: Ensure large-repo safeguards cover file hotspots, current symbols,
  historical symbols, and relationship enrichment where applicable.
- REQ-010: User-facing diagnostics must be actionable and not framed as quality
  judgement or bug prediction.
- REQ-011: `zig build test` passes.
- REQ-012: `zig build validate` passes.
- REQ-013: `git diff --check` passes.

## Edge cases

- Shallow repositories should stay explicitly scoped.
- Binary or generated-looking files should not force provider parsing.
- One capped provider must not prevent other candidate rows from completing.
- Repeated runs over the same fixture must be deterministic.

## Verification notes

Close-out requires bounded elapsed/count evidence and proof that truncation or
sampling caveats appear in relevant output without ranking drift outside the
bounded evidence path.
