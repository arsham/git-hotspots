# Feature 0020: Provider contract and symbol evidence design

## Problem

The project is approaching language-aware hotspot work, but provider boundaries
are not yet durable. Without a provider-neutral contract, the first tree-sitter
or LSP feature could accidentally become core runtime truth, harden the wrong
abstraction, alter file-level scoring, or imply unsupported symbol-history
claims.

## Outcome

Create a design-only provider and symbol evidence contract that future provider
features can use. The contract must preserve deterministic file-level Git
history as product truth, define minimum provider metadata and degradation
semantics, and bound the next tree-sitter spike before any provider code is
implemented.

## Requirements

- Add a public design note for provider and symbol evidence contracts.
- Define provider evidence envelope fields:
  - provider name;
  - provider kind;
  - provider version;
  - contract version;
  - configuration fingerprint where relevant;
  - analysed repository HEAD or input digest;
  - freshness state;
  - confidence;
  - failure state;
  - caveats;
  - local-only provenance.
- Define freshness states such as fresh, stale, partial, and unknown.
- Define failure states such as ok, unavailable, unsupported, failed, timed out,
  and skipped.
- Define how symbol evidence attaches to existing file hotspot results.
- State that symbol evidence is enrichment, not replacement product truth.
- State that provider failure must degrade gracefully and must not hide
  file-level Git evidence.
- Define a narrow future tree-sitter spike boundary:
  - one language;
  - current working-tree symbol spans only;
  - attached to existing file results;
  - confidence and caveats visible;
  - no historical symbol lineage or scoring change.
- Keep repository artefacts OSS/publicity-oriented and avoid commercial,
  hosted, pricing, or sales strategy.

## Non-goals

- No tree-sitter implementation.
- No LSP, ctags, dependency, blame, test, or coverage provider implementation.
- No runtime provider registry or plugin lifecycle.
- No provider CLI flags or configuration files.
- No dependency additions.
- No cache schema or cache coupling.
- No report schema changes.
- No scoring changes.
- No source parsing or provider execution.
- No network, telemetry, upload, remote enrichment, or background analysis.
- No bug prediction, code-quality scoring, developer ranking, or maintainer
  judgement claims.

## Acceptance criteria

- `docs/provider-symbol-evidence-contract.md` exists and captures the provider
  evidence contract, freshness, failure, confidence, symbol attachment, report
  behaviour, validation expectations, and future tree-sitter spike boundary.
- The feature is design-only: no `src/**`, `tests/**`, `fixtures/**`,
  `tools/**`, `build.zig`, dependency, CLI, or report output change is made.
- Current file-level Git evidence remains documented as the deterministic
  product truth.
- Provider output is framed as optional enrichment that can be absent,
  unavailable, stale, partial, or failed without invalidating file-level reports.
- The design note does not imply current symbol evidence exists today.
- The design note does not include commercial/SaaS/pricing/sales strategy.
- Validation proves docs-only scope, no prohibited claims, no runtime behaviour
  drift, and the existing validation gate remains green.

## Edge cases and risks

- A design note that is too detailed may prematurely harden a provider schema.
- A design note that is too vague may fail to protect the tree-sitter spike from
  becoming hidden product truth.
- Provider confidence must not be confused with code quality, risk, or bug
  likelihood.
- Provider failure states must not encourage silent omission of evidence.
- Symbol evidence must not imply historical symbol tracking before that exists.

## Verification

Close-out must include:

- `git diff --check`.
- `zig build validate`.
- A changed-path check proving only Flow metadata and docs/design artefacts
  changed.
- A scan proving no `src/**`, `tests/**`, `fixtures/**`, `tools/**`, `build.zig`,
  dependency, CLI, or report output files changed.
- A content scan for prohibited commercial/SaaS/pricing/sales strategy.
- A content scan for bug prediction, quality scoring, developer ranking, and
  maintainer-judgement claims outside explicit non-goals.
- Reviewer confirmation that the design note is provider-neutral and does not
  implement or imply current provider runtime behaviour.
