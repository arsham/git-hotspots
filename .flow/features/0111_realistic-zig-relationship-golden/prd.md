# Realistic Zig relationship golden

## Overview

Add deterministic fixture and golden coverage that better represents real Zig
relationship output. The current checked-in Zig relationship golden is small and
contains only two `contains` records, while the 0110 sample realism audit showed
this repository's Zig lane produces mixed relation kinds, unresolved or unknown
evidence, human display omissions, and provider-cap omission state.

This feature is a fixture and validation representativeness slice. It must not
change runtime behaviour or relationship semantics.

## Requirements

- REQ-001: Add or adjust a deterministic Zig relationship fixture/golden that
  covers mixed Zig relation kinds beyond only `contains` when stable evidence is
  available.
- REQ-002: The fixture/golden must cover unresolved or unknown relationship
  evidence when stable evidence is available.
- REQ-003: The fixture/golden must cover human display omission with a bounded
  `--symbol-limit` or equivalent existing validation path.
- REQ-004: The fixture/golden must cover provider-cap omission if it can be made
  deterministic without relying on private repository shape or unstable counts.
- REQ-005: If provider-cap omission cannot be stabilised in a public fixture,
  record the explicit reason and preserve the strongest deterministic subset.
- REQ-006: JSON schema and existing relationship record fields must remain
  unchanged.
- REQ-007: Runtime provider algorithms, relationship semantics, caps, sorting,
  scoring, ranking, and confidence behaviour must remain unchanged.
- REQ-008: CLI flags, option names, help contract, cache behaviour, network
  behaviour, telemetry, release state, tags, remotes, package artefacts, and
  publishing behaviour must remain unchanged.
- REQ-009: Update integration or validation assertions only as needed to prove
  the new Zig golden remains deterministic and representative.
- REQ-010: The new or updated golden must be deterministic across repeated local
  validation runs.
- REQ-011: Documentation changes are optional and should be limited to fixture
  or validation notes if needed; public user docs should not claim stronger Zig
  semantic truth.
- REQ-012: Validation must include `git diff --check`, `zig build test`, and
  `zig build validate`; reviewers must discover and run credible project gates
  before close-out.

## Acceptance

- A realistic Zig relationship golden or fixture update exists and is committed.
- The new coverage represents at least one realistic gap identified by
  `docs/relationship-output-sample-realism-audit.md`.
- If provider-cap omission is not covered, the reason is explicit and the
  feature still improves Zig fixture representativeness.
- Existing JSON schema and public CLI behaviour are unchanged.
- Validation passes.

## Edge cases

- If the natural this-repo dogfood output is too volatile for a checked-in
  golden, use a smaller deterministic fixture that preserves the same evidence
  categories.
- If fixture setup cannot trigger provider-cap omission without brittle counts,
  prefer stable mixed-kind and uncertainty coverage over fragile cap coverage.
- Do not use private paths, repository names, remotes, author identities, parser
  diagnostics, or raw private reports as committed evidence.

## Verification

- `git diff --check`
- `zig build test`
- `zig build validate`
- Optional repeated fixture command comparison if the implementation adds a new
  golden-generation path.
