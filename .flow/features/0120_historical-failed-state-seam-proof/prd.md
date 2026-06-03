# Historical failed-state seam proof

## Problem

The historical provider-state fixture gap audit found that checked-in
historical-symbol goldens cover `ok`, `unsupported`, and `skipped`, but not
`failed`, `timed_out`, or `unavailable`. It identified `failed` as the only
plausible deterministic missing state, but the concrete fixture seam is not yet
proven.

## Requirements

- REQ-001: Produce a docs-only/read-only seam proof for historical
  `provider_state: failed` fixture feasibility.
- REQ-002: Inspect the relevant fixture setup, historical attribution path, and
  provider failure paths without changing runtime behaviour or goldens.
- REQ-003: Decide whether a deterministic `failed` fixture can be implemented
  without runtime injection, wall-clock timing, or environment-dependent
  provider absence.
- REQ-004: If feasible, define the smallest follow-up fixture/golden slice,
  including likely files, expected state, validation commands, and protected
  surfaces.
- REQ-005: If infeasible, record why `failed` remains uncovered and what seam
  would be needed later.
- REQ-006: Preserve `timed_out` and `unavailable` as uncovered states unless a
  future feature explicitly shapes deterministic coverage.
- REQ-007: Do not change fixture goldens, runtime/provider code, CLI flags,
  JSON schema, scoring, ranking, provider admission, cache, network, telemetry,
  release, tag, package, or remote behaviour.
- REQ-008: Validation must include `git diff --check` and `zig build validate`.

## Acceptance

- `docs/historical-failed-state-seam-proof.md` records the investigated seam and
  the feasibility decision.
- The proof explicitly says whether a deterministic `provider_state: failed`
  fixture is feasible now.
- The proof includes either a concrete follow-up implementation slice or a clear
  rationale for leaving `failed` uncovered.
- No runtime, fixture golden, CLI, schema, provider-admission, scoring/ranking,
  release/tag/package/remote/network/telemetry/cache change is made.

## Edge cases

- Do not treat a hand-authored golden row as proof.
- Do not rely on wall-clock timeout, missing local dependencies, absolute paths,
  parser diagnostics, raw report dumps, remotes, author identities, emails, or
  commit messages.
- If the seam depends on changing provider behaviour, record that as follow-up
  planning instead of implementing it here.

## Verification

- `git diff --check`
- `zig build validate`
- Privacy scan through the standard validation ladder.
