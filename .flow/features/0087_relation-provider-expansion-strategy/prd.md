# Relation provider expansion strategy

## Problem

`git-hotspots` has a provider-neutral relationship architecture, a Python
relation proof, internal aggregation, and an opt-in public relationship report.
The next expansion should not add languages opportunistically without a durable
rubric, because relation evidence varies by grammar, language semantics,
existing fixtures, and validation cost.

## Outcome

Produce a short strategy document that ranks near-term relationship provider
expansion, records the shared admission rubric, and confirms the serial
implementation order for the next batch. The feature is planning/documentation
only and must not change runtime behaviour, CLI output, scoring, fixtures, or
provider implementation.

## Requirements

R1: Add `docs/relation-provider-expansion-strategy.md` as the primary product
artefact for this feature.

R2: Compare TypeScript, JavaScript, Rust, Go, Lua, Zig, and Python follow-up
expansion using a shared rubric: existing parser support, current-symbol
coverage, likely relation kinds, fixture complexity, runtime risk, public value,
real-repo smoke availability, and caveat burden.

R3: Select a serial batch order and explain why TypeScript/JavaScript and Rust
are the next implementation candidates, unless evidence from the comparison
justifies a different order.

R4: Define the minimum acceptance bar for a new relationship provider: local
Tree-sitter or equivalent local source, provider-neutral relation candidates,
contains/reference/call/import_include where supported, unresolved/unknown
fallbacks, deterministic sorting, caps, caveats, unsupported/failure behaviour,
and no scoring effect.

R5: Define the common validation bar for provider expansion: grammar proof when
needed, query/provider unit proof, integration fixture proof, public report
fixture drift checks when public support changes, `zig build test`,
`zig build validate`, and at least one privacy-safe real-repo or documented skip
reason.

R6: Define when a provider expansion must remain internal and when it may update
public report capability claims.

R7: Update B002 only with the durable provider-expansion batch decision and
feature links. Do not close B002.

R8: Do not add runtime provider code, public CLI flags, report fields, scoring
changes, cache truth, network access, telemetry, package publication, or
browser-visible UI work.

## Non-goals

- No new relationship provider implementation.
- No public output or documentation claim that a language is supported before
  its implementation feature closes.
- No full call graph, type checker, package graph, semantic dependency proof,
  ownership signal, code-quality score, developer metric, or bug prediction.
- No cache, remote enrichment, network provider, telemetry, or runtime LLM.

## Edge cases

E1: If TypeScript and JavaScript share implementation surfaces, the strategy
must state whether they should ship together or separately and why.

E2: If Rust support is valuable but semantically harder, the strategy must
capture which relation kinds are acceptable for a syntax-only proof and which
must remain caveated.

E3: If a language has current-symbol support but weak relation syntax coverage,
the rubric must allow it to remain unsupported for relationships.

E4: If public documentation is updated later, the strategy must require the
provider capability matrix and validation harness to prevent overclaim drift.

## Verification notes

Close-out evidence should include:

- `git diff --check`.
- Markdown review for `docs/relation-provider-expansion-strategy.md`.
- `flow validate --target feature:0087`.
- `flow validate --target brief:B002`.
- `zig build validate`.
- Independent reviewer verification that the feature is planning-only and that
  the selected batch order is justified by evidence.
