# Opt-in symbol relationship report

## Summary

Expose symbol relationship evidence through an explicit opt-in public report
after the internal provider proof and aggregation integration are closed. The
report must be additive, bounded, deterministic, caveated, and privacy-safe.
Default output remains unchanged.

Relationship evidence is an investigation prompt. Public wording must not claim
call-graph truth, dependency proof, ownership, code quality, developer
performance, bug prediction, or impact certainty.

## Requirements

- REQ-001: Feature 0086 depends on features 0084 and 0085 and must not execute
  before both internal relation slices are closed.
- REQ-002: Add an explicit opt-in CLI/report surface for relationship evidence;
  default command output must remain unchanged.
- REQ-003: If the opt-in flag has prerequisites or invalid combinations, the CLI
  must produce actionable diagnostics without dumping full usage text.
- REQ-004: JSON output must expose bounded relation evidence with source
  endpoint, target endpoint or unresolved target, relation kind, direction when
  meaningful, evidence basis, confidence/freshness/failure state, caveats,
  provider identity, deterministic ordering, and omitted counts where relevant.
- REQ-005: Table output must include a readable bounded relation summary without
  crowding or replacing existing file/symbol hotspot evidence.
- REQ-006: Markdown output must include a caveated bounded relation section or
  subsection that is deterministic and privacy-safe.
- REQ-007: Public output must keep relation evidence additive and must not alter
  file or symbol scoring, ranking, default sorting, or existing report fields
  except for explicitly opt-in additions.
- REQ-008: README, docs/user-guide.md, man/git-hotspots.1,
  tests/integration.sh, tools/validate.sh, and relevant fixtures must be updated
  together when CLI/report wording changes.
- REQ-009: docs/developer-guide.md must be updated if public reporting changes
  provider or internal extension expectations.
- REQ-010: Public wording must describe relation evidence as local, caveated
  investigation context and must avoid bug prediction, ownership, code-quality
  judgement, maintainer judgement, developer metrics, and semantic certainty.
- REQ-011: Golden fixtures must prove deterministic JSON, table, and Markdown
  output for relation evidence and default-output non-drift without opt-in.
- REQ-012: Tests must cover unsupported relation provider, unresolved target,
  cap reached, provider failure, and no relation evidence available.
- REQ-013: Validation must include docs/man surface checks, prohibited-claim
  scan, CLI misuse matrix, JSON validity, Markdown semantic/privacy assertions,
  and deterministic fixture checks.
- REQ-014: Close-out must include a real-repository smoke on this repository and
  one privacy-safe sibling/local repo when available, or a durable skip reason
  when unavailable.
- REQ-015: Smoke evidence may include labels, command shapes, pass/fail status,
  bounded counts, caveat counts, and elapsed time only. It must not include raw
  private report output, absolute private paths, source snippets, authors,
  emails, remotes, or commit messages.
- REQ-016: The feature must not add network access, telemetry, remote
  enrichment, runtime LLM judgement, hosted services, mandatory cache truth, or
  package publishing.
- REQ-017: B002 must remain linked and valid as the public follow-up after 0084
  and 0085.
- REQ-018: `git diff --check`, `zig fmt --check build.zig src tests`,
  `zig build test`, and `zig build validate` must pass before close-out.
- REQ-019: `flow validate --target feature:0086` and
  `flow validate --target brief:B002` must pass before close-out.

## Edge cases

- User requests relation output without required symbol or provider inputs.
- Relation provider is unsupported or unavailable for all retained candidates.
- Some candidates have relation evidence while others have caveats only.
- Relation cap is reached and omitted counts must be shown.
- Output contains unresolved target strings.
- Existing historical symbol report is enabled together with relationship
  reporting.
- Repository is shallow, partial, dirty, or scoped by include/exclude filters.
- Sibling/local smoke repository is unavailable.

## Verification notes

Close-out requires independent review. The reviewer should verify public surface
coordination across CLI/help/docs/man/tests/fixtures/validation, default-output
non-drift, deterministic opt-in output, privacy-safe evidence, and evidence-only
language.
