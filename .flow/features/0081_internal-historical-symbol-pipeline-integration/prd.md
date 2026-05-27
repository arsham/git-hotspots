# PRD: Internal historical symbol pipeline integration

## Problem

Feature 0080 proved the internal historical hunk attribution engine in isolated
fixture paths, but the main analysis pipeline still does not know how to feed
bounded ranked-file candidates into that engine or prove that integration stays
local-first, deterministic, privacy-safe, and public-output neutral.

Before exposing historical symbol hotspots to users, the project needs an
internal integration slice that wires the engine into the analysis data flow for
retained ranked-file candidates, records caveated internal evidence, proves
bounded performance, and demonstrates that existing CLI/report/schema/scoring
surfaces do not drift.

## Outcome

Add an internal/test-only historical symbol pipeline integration. The feature
should derive a deterministic candidate file set from existing file-level
analysis results, run the 0080 no-checkout hunk attribution engine under explicit
bounds, retain internal aggregate evidence and caveats in a future-consumable
shape, and validate the path with fixtures plus real-repository smoke evidence.
It must not expose a public CLI flag, report field, scoring change, or docs/man
promise.

## Requirements

R1: Add an internal pipeline function or module that connects existing
`model.Analysis` file results to the historical hunk attribution engine for a
bounded candidate file set. It must be callable from tests and future public
report wiring without requiring CLI-visible behaviour in this feature.

R2: Candidate selection must be deterministic and derived from retained ranked
file results after the normal repository, range, scope, include, exclude,
inspect, and limit semantics have already been applied. It must not rescore
files, widen the evidence universe, or silently include filtered paths.

R3: The integration must enforce explicit bounds for candidate files, commits,
changed file entries, hunks, blob bytes, provider failures, aggregate records,
and sample commits. Bounds must produce caveated partial evidence rather than
unbounded traversal.

R4: The integration must use only local Git history and local provider parsing.
It must not fetch, pull, contact remotes, upload source, emit telemetry, require
a persistent cache, use runtime LLM judgement, or checkout historical commits.

R5: Internal historical symbol aggregate records must preserve the 0080 evidence
semantics: parent path, symbol kind/name when available, revision-local range,
current/historical/deleted/unknown status, change count, added/deleted line
pressure, latest timestamp when available, bounded sample commit ids, provider
state, confidence, caveats, fallback counts, and deterministic sort inputs.

R6: Integration-owned caveats must include shallow or partial history,
merge/large-commit simplification, candidate or changed-file truncation,
binary/missing/large blob skips, unsupported provider or parse failures,
unattributed fallback, and internal integration disablement where applicable.

R7: The public file-level ranking and scoring pipeline must remain unchanged.
Historical symbol aggregates may be computed internally for tests/future use,
but they must not alter file scores, file order, file confidence, file caveats,
co-change evidence, or current-size evidence.

R8: Existing public CLI behaviour, help, diagnostics, table output, JSON output,
Markdown output, explain text, current project-symbol output, current-line
history output, docs, man page, and public golden fixtures must remain unchanged
unless the change is a strictly internal validation harness update.

R9: The internal integration must keep current-symbol evidence and true
historical hunk attribution separate. It must not relabel current-line blame as
true symbol history, and it must not claim semantic symbol lineage, ownership,
reference/use relations, or quality scoring.

R10: The pipeline should be future-consumable by the public report feature: one
future caller should be able to request the internal aggregate evidence without
re-running file-level analysis or rediscovering candidate paths in a separate
way.

R11: The implementation must own memory explicitly. Any new analysis or
integration structure must have deterministic cleanup, must not leak provider or
Git blob buffers, and must not store borrowed source bytes beyond their valid
lifetime.

R12: Fixture proof must exercise the integrated pipeline, not only the isolated
0080 engine. At minimum it must cover a simple edit, deleted symbol or file,
rename plus edit, unsupported/provider-failure fallback, binary skip, large
file skip, unattributed fallback, truncation caveat, and deterministic ordering.

R13: Real-repository smoke evidence must exercise the internal integration on
this repository with privacy-safe labels and bounded counts only. It must not
commit or print absolute local paths, remotes, author identities, emails, commit
messages, parser diagnostics, source snippets, or raw private report output.

R14: Validation must include a public-surface non-regression proof: normal runs
without a public historical-symbol flag must produce the same expected public
reports as before except for explicitly approved internal-test artefacts.

R15: If the runner discovers that public CLI/report output must change to prove
integration, that is a hard planner escalation rather than a local runner
decision.

## Non-goals

- No public historical-symbol CLI flag, report field, export schema, docs/man
  promise, or user-facing report section.
- No file-level scoring, ranking, confidence, caveat, co-change, or current-size
  semantics change.
- No semantic symbol lineage, rename/move proof, reference graph, call graph,
  dependency graph, package analysis, type checking, macro expansion, or
  ownership inference.
- No LSP, ctags, network service, runtime AI, hosted enrichment, telemetry,
  upload, remote index, or persistent cache requirement.
- No history rewrite, publishing, package release, or B002 close-out.

## Edge cases

E1: The candidate list contains unsupported, generated-looking, filtered,
missing, binary, or too-large files. The integration must preserve file evidence
and record internal caveats rather than widening scope or fabricating symbols.

E2: `--inspect` narrows the analysis to one ranked file. Internal candidate
selection should follow the inspected result and must not reintroduce other
ranked files.

E3: `--limit` truncates retained ranked files. Internal historical attribution
must operate on retained candidates only and record candidate truncation where
needed.

E4: The repository is shallow, partial, dirty, or has missing objects. The
integration must not auto-fetch and must retain caveated partial evidence.

E5: A provider fails after some candidates have already been processed. The
integration must retain successful aggregate evidence, count/caveat failures,
and honour the provider-failure bound.

E6: A merge commit or large commit exceeds the first-slice policy. The
integration must skip or simplify according to the 0080 engine policy and carry
that caveat forward internally.

E7: Repeated runs over the same fixture and same bounds must produce identical
aggregate ordering and bounded sample commit order.

E8: The future report feature needs a field not present in the internal model.
The runner may add internal fields if they preserve the evidence-only boundary;
public report/API exposure remains out of scope.

## Verification notes

Close-out evidence should include:

- `git diff --check`.
- `zig fmt --check build.zig src tests`.
- Targeted integrated historical symbol pipeline proof if added.
- `zig build test`.
- `zig build validate`.
- A fixture proof that exercises the integration path and required edge cases.
- A real-repository smoke summary over this repository with privacy-safe labels
  and bounded counts only.
- A public-surface non-regression check for table, JSON, Markdown, explain,
  current project symbols, and current-line history outputs.
- Independent reviewer verification that the feature remains internal-only,
  local-first, deterministic, caveated, and privacy-safe.
