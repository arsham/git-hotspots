# Historical failed-state seam proof

This record decides whether `provider_state: failed` can be covered
deterministically for the historical-symbol fixture without runtime
injection, wall-clock timing, or environment-dependent provider absence.

## Decision

Feasible now.

The historical extraction path already feeds revision-local blob bytes into the
same language parser used by working-tree source parsing, then retargets the
result to historical input. A malformed supported `.zig` blob is therefore a
content-driven way to produce `provider_state: failed` without changing runtime
behaviour or depending on a missing provider.

## Evidence

- `src/provider_selection.zig` routes historical source through
  `tree_sitter_zig.extractSource(...)` and then retargets the historical input.
- `src/tree_sitter_zig.zig` returns `provider.Failure.failed` for parser
  creation failure, parser language setup failure, parse failure, or a parsed
  tree with syntax errors in supported Zig source.
- `fixtures/expected/historical-symbols.json` currently shows `failed_count: 0`
  and no historical `failed` row.
- The checked-in audit in
  `docs/historical-provider-state-fixture-gap-audit.md` already treats `failed`
  as the only near-term candidate state.

## Smallest follow-up slice

Likely files:

- `fixtures/symbols/...` - add one malformed historical Zig blob in the fixture
  repository history.
- `fixtures/expected/historical-symbols.json`
- `fixtures/expected/historical-symbols.md`
- `fixtures/expected/historical-symbols.txt`
- Any fixture-generation test or helper that materialises the checked-in
  historical repository.

Expected state:

- one additional historical record or fallback row with `provider_state:
  failed`
- low confidence with the existing failed caveat wording
- no runtime/provider code changes, no CLI/schema changes, and no scoring or
  ranking changes

## Uncovered states

`timed_out` and `unavailable` remain uncovered here. They would need a separate
stable seam and should not be approximated with wall-clock delay or
environment-dependent provider absence.

## Boundaries

Protected surfaces stay unchanged: fixture goldens, runtime/provider code, CLI
flags, JSON schema, scoring and ranking, provider admission, release tags,
packages, remotes, network, telemetry, and cache semantics.

## Validation for the follow-up slice

- `git diff --check`
- `zig build validate`
