# PRD: Opt-in historical symbol hotspot report

## Problem

The project can now parse historical hunks internally and should next expose the
capability to users, but only after the internal pipeline integration from
feature 0081 proves bounded performance and public-output neutrality. The public
surface must be opt-in, additive, deterministic, local-first, and careful about
what historical symbol evidence means.

Existing `--symbols` output is current working-tree enrichment, and
`--symbol-line-history` is current-line Git evidence for HEAD ranges. Users need
a clearly separate report surface for true historical hunk-to-symbol evidence,
without changing file-level scoring truth or implying semantic lineage, bug
prediction, ownership, or code-quality judgement.

## Outcome

Add an opt-in public historical symbol hotspot report surface. The planned user
shape is `--historical-symbols` used with `--symbols`; it should run the
integrated historical symbol pipeline over retained ranked-file candidates and
render additive table, JSON, and Markdown evidence. Existing output without the
new flag must remain unchanged. Documentation, man page, help, diagnostics,
fixtures, integration tests, and validation must move together.

## Requirements

R1: Add a public opt-in `--historical-symbols` CLI flag after feature 0081 is
complete. The flag must require `--symbols` and must have a concise diagnostic
that points to a valid command shape when used alone.

R2: `--historical-symbols` must not run by default. Runs without the flag must
preserve existing CLI behaviour, public table/JSON/Markdown output, explain
text, current project-symbol output, current-line history output, file-level
scoring, and golden fixtures.

R3: `--historical-symbols` must use the feature 0081 integrated pipeline and
retained ranked-file candidates. It must not rescore files, widen the evidence
universe, ignore scope/include/exclude/inspect/range semantics, or checkout
historical commits.

R4: The report must clearly distinguish three layers: current working-tree
symbols, current-line Git evidence for HEAD ranges, and true historical hunk
attribution. It must not relabel one layer as another.

R5: Public JSON output must add an optional top-level historical symbol evidence
object only when `--historical-symbols` is enabled. The object must be additive
and include schema/basis metadata, local-only provenance, candidate and bound
summary, caveats, deterministic sort basis, and item arrays with evidence-only
fields.

R6: Public historical symbol item fields must include parent file path, parent
rank/score, symbol name/kind when available, revision-local or report-level
range where available, status, change count, added/deleted line pressure,
latest timestamp where available, bounded sample commit ids, provider state,
confidence, caveats, fallback/unattributed counts, and deterministic sort
inputs or documented sort basis.

R7: Public output must never include commit messages, authors, emails, remotes,
absolute local paths, source snippets, parser diagnostics, private repository
names, ownership/productivity metrics, bug-prediction claims, code-quality
scores, or developer rankings.

R8: Table and Markdown output must add a clearly labelled historical symbol
section only when the flag is enabled. Human rows should use the existing
`--symbol-limit` display limit unless shaping is explicitly revised; JSON may
include the complete bounded internal item set.

R9: Historical symbol report caveats must include current limitations:
provider-supported languages only, no semantic symbol lineage, no reference/use
analysis, no ownership, no bug prediction, no scoring replacement,
shallow/partial history caveats, and explicit fallback for unsupported, binary,
large, missing, provider-failed, merge, or unattributed evidence.

R10: The current file-level score remains product truth for ranking in this
feature. Historical symbol evidence is investigation evidence attached to
retained file hotspots; it must not replace file scoring or reorder file
hotspots unless a later feature explicitly reshapes scoring.

R11: The CLI parser, help text, app diagnostics, README, docs/user-guide.md,
docs/developer-guide.md, man/git-hotspots.1, tests/integration.sh,
tools/validate.sh, expected fixtures, and explain/prohibited-claim validation
must be updated together where wording or output changes.

R12: The implementation must keep runtime defaults local-first: no network,
telemetry, background upload, remote enrichment, runtime LLM judgement, or
mandatory cache. Shallow/partial history must be reported rather than repaired
by auto-fetch.

R13: The report must be deterministic across repeated runs over the same repo,
range, scope, provider versions, and bounds. Sorting and sample commits must not
depend on hash-map or process iteration order.

R14: Feature 0082 must not start unless feature 0081 is done or the orchestrator
explicitly reshapes the dependency. Dispatch should keep 0082 serially after
0081 in the batch.

R15: Close-out validation must include real-repository smoke evidence for this
repository and one suitable sibling/local repository when available, with
privacy-safe labels and bounded counts only. If no sibling is suitable, the
runner must record a caveated reason rather than inventing evidence.

R16: If output examples are added to public docs, they must use project-relative
paths or fixture paths and must not include raw private report output.

## Non-goals

- No public default-on historical symbol analysis.
- No scoring replacement, bug prediction, code-quality scoring, developer
  ranking, author productivity metric, semantic ownership, or blame assignment.
- No reference graph, call graph, dependency graph, package graph, type
  checking, macro expansion, cross-language resolution, or relation/use analysis.
- No semantic proof of symbol rename, move, split, or merge lineage.
- No persistent cache as product truth.
- No hosted service, network provider, LSP/ctags dependency, runtime LLM, or
  remote index.
- No B002 close-out unless a later operator explicitly asks for capability
  closure.

## Edge cases

E1: `--historical-symbols` is passed without `--symbols`. The CLI must fail with
exit 2 and a concise diagnostic that points to `git-hotspots --repo . --symbols
--historical-symbols`.

E2: `--historical-symbols` is combined with `--inspect`. The report should stay
bounded to the inspected ranked file and document whether project-level or
inspect-level historical symbol sections are emitted.

E3: `--historical-symbols` is combined with `--symbol-line-history`. The report
must render both layers without implying that current-line blame is true
historical symbol attribution.

E4: No historical symbols can be attributed for retained files. The report must
emit an empty/caveated historical-symbol section rather than failing or choosing
nearest symbols.

E5: Some candidates are unsupported, binary, missing, too large, shallow,
partial, or provider-failed. The report must preserve successful evidence and
summarise skipped/fallback counts.

E6: A renamed file contributes historical evidence. The report may show file
lineage context, but must not claim semantic symbol lineage from the rename.

E7: Human output is limited by `--symbol-limit`. The report must state shown and
omitted counts; JSON must make its completeness or boundedness explicit.

E8: Public report size or runtime becomes too large for common repositories. The
runner may tighten documented internal bounds and caveats, but adding broad new
public tuning flags requires planner approval.

## Verification notes

Close-out evidence should include:

- `git diff --check`.
- `zig fmt --check build.zig src tests`.
- `zig build test`.
- `zig build validate`.
- CLI misuse diagnostics for `--historical-symbols` without `--symbols` and
  invalid combinations discovered during implementation.
- Golden fixture updates for table, JSON, and Markdown with the new flag.
- Golden non-regression proof for default runs without the flag.
- Documentation/man/help/explain consistency checks.
- JSON validity and deterministic repeated-run proof.
- Provider capability matrix/prohibited-claim/privacy validation updates.
- Real-repository smoke summaries with privacy-safe labels and bounded counts.
- Independent reviewer verification of additive output, local-first behaviour,
  deterministic evidence, and no prohibited claims.
