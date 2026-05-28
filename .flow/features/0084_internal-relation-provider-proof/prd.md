# Internal relation provider proof

## Summary

Add the first internal, non-public proof that `git-hotspots` can collect symbol
relationship evidence from a bounded local provider. The feature proves the
provider-neutral relation model selected in `docs/symbol-relationship-architecture.md`
without exposing any public CLI or report surface.

Relationship evidence remains caveated investigation context. It must not alter
file or symbol ranking, predict bugs, judge code quality, imply ownership, rank
developers, or claim full call-graph or dependency truth.

## Requirements

- REQ-001: Add an internal provider-neutral relation endpoint/candidate model
  that can represent file, current-symbol, report-symbol, unresolved, and
  external-string endpoints needed by the selected provider proof.
- REQ-002: Relation candidates must carry relation kind, direction when
  meaningful, evidence basis, provider envelope, confidence/freshness/failure
  state, caveats, and deterministic ordering keys.
- REQ-003: Implement one local syntax-provider proof using an existing
  Tree-sitter-backed provider family or a bounded equivalent already supported
  by the repository.
- REQ-004: The provider proof must emit `contains`, `reference`, `call`,
  `import_include`, `unresolved`, and `unknown` candidates where the selected
  language can support them honestly.
- REQ-005: Unsupported or ambiguous relation targets must remain unresolved
  endpoints with explicit caveats; the implementation must not fabricate target
  mappings.
- REQ-006: Unsupported languages, parser failures, provider unavailable states,
  oversized inputs, and cap-reached cases must degrade to caveated absent or
  partial relation evidence without breaking existing hotspot analysis.
- REQ-007: Relation evidence must remain internal/test-only or inspect-internal;
  no public table, JSON, Markdown, explain, help, README, man page, or user
  guide relation output may be added in this feature.
- REQ-008: Existing file and symbol scoring, ranking, sorting, and public output
  defaults must not change.
- REQ-009: The feature must not add network access, telemetry, remote
  enrichment, runtime LLM judgement, hosted services, mandatory cache truth, or
  global LSP service requirements.
- REQ-010: Fixture or unit tests must prove resolved syntax relation,
  unresolved target, nested `contains`, `import_include`, unsupported language,
  provider failure, cap reached, and deterministic ordering behaviour.
- REQ-011: Provider diagnostics, source snippets, author names, emails, remotes,
  absolute local paths, commit messages, and raw private report output must not
  be emitted in public or committed validation artefacts.
- REQ-012: B002 must remain linked and valid; this feature must be recorded as
  the first runtime successor after the relationship architecture spike.
- REQ-013: `zig fmt --check build.zig src tests`, `zig build test`, and
  `zig build validate` must pass before close-out.
- REQ-014: `flow validate --target feature:0084` and
  `flow validate --target brief:B002` must pass before close-out.

## Edge cases

- Provider can parse a file but cannot resolve a target name.
- Relation-like syntax is present but cannot be classified safely.
- Nested symbols produce multiple containment candidates.
- Import/include syntax names a module or path-like string without a safe local
  endpoint.
- Selected provider fails, times out, or is unavailable.
- Unsupported language is included in the candidate set.
- Candidate or edge cap truncates output.
- Source is oversized, binary-like, or skipped by policy.
- Hash-map or provider iteration order would otherwise make results unstable.

## Verification notes

Close-out requires independent review. The reviewer should verify that only
internal/test-facing relation surfaces changed, public outputs did not drift,
fixture coverage proves the edge cases above, and all relation wording remains
caveated evidence rather than semantic truth.
