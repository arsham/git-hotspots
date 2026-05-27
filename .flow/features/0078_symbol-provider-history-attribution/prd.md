# Project-level current-symbol hotspot evidence

## Problem

`git-hotspots` can already report deterministic file hotspots and can enrich one
inspected file with current working-tree Tree-sitter symbols. That leaves symbol
evidence useful but too local: users must first know which hot file to inspect,
then run a second command for one path.

The next step should make symbol evidence available from the normal ranked
hotspot report while staying honest about the current implementation boundary.
The feature should not claim true historical symbol lineage or hunk-to-symbol
attribution yet. It should surface current symbols inside the already-ranked hot
files, and when requested, attach current-line Git evidence from HEAD line
ranges. This gives humans and agents symbol-level investigation prompts without
making provider output the product truth.

## Outcome

Allow project analysis commands to use `--symbols`, optionally with
`--symbol-line-history`, without `--inspect`. The command first computes the
normal file-level hotspot ranking, then extracts current symbols only for the
ranked file results that have supported providers. Reports expose a
project-level current-symbol hotspot section that is sorted from deterministic
local evidence and clearly tied back to the parent file hotspot row.

The result is a bounded first implementation slice for B002:

- file-level Git history remains the scoring and ranking source of truth;
- current symbols are additive evidence for the ranked hot files;
- current-line Git evidence is derived from local `git blame --incremental` over
  current HEAD symbol line ranges when requested;
- unsupported languages, provider failures, large files, dirty files, shallow
  history, and partial history degrade with caveats rather than fabricated
  precision;
- adding a future language provider to the shared current-symbol provider
  selection path automatically makes project-level symbol reports eligible for
  that language; and
- true historical hunk-to-symbol attribution, rename or move lineage, reference
  graphs, and symbol relationship analysis remain later features.

## Requirements

R1: Permit `--symbols` in normal project analysis without requiring
`--inspect`. The command shape `git-hotspots --repo . --limit N --symbols` must
be valid and must keep the same file-level result set that would have been
produced without `--symbols`.

R2: Permit `--symbol-line-history` with project-level `--symbols`. The command
shape `git-hotspots --repo . --symbols --symbol-line-history` must attach
current-line Git evidence to current symbol ranges for eligible ranked files.
It must still reject `--symbol-line-history` when `--symbols` is absent.

R3: Permit `--symbol-limit N` with project-level `--symbols`. The limit remains
a human display limit for table and Markdown output; JSON must keep complete
machine-readable symbol evidence for the analysed ranked files unless the
implementation adds an explicit and documented machine-output cap in this
feature.

R4: Preserve existing inspect behaviour. `--inspect PATH --symbols`,
`--inspect PATH --symbols --symbol-line-history`, and `--symbol-limit` in
inspect mode must continue to work with the existing current-only semantics and
without changing file score, rank, lineage, confidence, scope, or evidence.

R5: Run provider extraction only after normal file-level analysis and only for
the ranked result rows that remain after `--limit`, `--since`, scope, include,
and exclude filters. The feature must not scan the full repository for symbols
before ranking and must not parse every commit or checkout historical trees.

R6: Reuse one shared provider selection and extraction seam for inspect and
project-level symbol reports. A new language provider added to that seam should
become eligible for project-level symbol evidence without changing scoring,
history attribution, or report logic beyond provider registration and provider
specific tests.

R7: Treat supported and unsupported paths differently in project mode.
Unsupported ranked files may be counted and caveated in the project symbol
summary, but they must not produce noisy per-file provider failure rows. Ranked
files with supported extensions whose current file is missing, unreadable,
symlinked, too large, or parser-failed should produce bounded provider caveats
without source snippets, parser diagnostics, absolute local paths, remotes,
author identities, commit messages, or private repository names.

R8: Report a project-level current-symbol hotspot section for table, Markdown,
and JSON. Each symbol item must carry at least repo-relative file path, parent
file rank, parent file score or evidence reference, symbol name, kind, current
range, provider name, confidence, caveats, and current-only status. When
current-line history is requested, include line count, distinct last-touch
commit count, most recent line touch timestamp when available, unblamable line
count, sample commit ids, freshness, failure, confidence, and caveats.

R9: Keep project-level symbol ordering deterministic. The default sort should
start from parent file hotspot rank and then use existing provider order. When
current-line history is present, symbols within the same parent file should sort
by the existing current-line evidence summary before stable symbol identity.
No new semantic risk score, bug prediction, code-quality rating, ownership
metric, or developer ranking may be introduced.

R10: Preserve local-first runtime boundaries. The feature must not add network
access, telemetry, background upload, remote enrichment, cache requirements,
provider plugin loading, LSP server requirements, ctags requirements, package
manager calls, or runtime AI judgement.

R11: Preserve current file-level output contracts when `--symbols` is not
requested. Normal table, Markdown, and JSON reports without symbol flags should
remain byte-stable except for intentional fixture changes caused by validation
harness setup.

R12: Update CLI help, diagnostics, examples, README, user guide, developer
guide, manual page, and validation checks anywhere they currently say
`--symbols`, `--symbol-line-history`, or `--symbol-limit` are inspect-only.
The replacement wording must say project-level symbols are current working-tree
evidence for ranked file hotspots and not true symbol history, lineage,
scoring, ownership, reference analysis, or semantic dependency analysis.

R13: Preserve privacy-safe reporting. Public docs, fixture output, and real-repo
smoke summaries must not include absolute local paths, remotes, author
identities, commit messages, raw private reports, parser diagnostics, source
snippets, or private repository names.

R14: Leave forward-compatible seams for later relation analysis. Output should
carry stable-enough current symbol identity fields `(path, provider, kind, name,
current range)` and explicit caveats, but this feature must not implement
reference graphs, call graphs, dependency propagation, cross-language symbol
resolution, or related-symbol ranking.

## Non-goals

- No true historical hunk-to-symbol attribution across commits.
- No historical symbol renames, moves, splits, merges, nesting lineage, or
  semantic ownership.
- No parsing of Git blobs across every commit, no worktree checkout per commit,
  and no full-repository symbol indexing before file ranking.
- No new language provider implementation unless required only for test fixture
  support; existing supported Tree-sitter providers are the provider base.
- No LSP, ctags, Cargo, package graph, module resolution, dependency graph,
  macro expansion, cfg or feature evaluation, type checking, or relation graph.
- No scoring replacement and no change to file hotspot score, rank, confidence,
  co-change evidence, file lineage, include or exclude filters, or default
  no-symbol output.
- No network, telemetry, upload, remote enrichment, cache requirement, hosted
  service, or runtime model judgement.

## Edge cases

E1: A ranked result is an unsupported file type, such as Markdown. Project
symbol reporting skips per-file provider output for that row, increments an
unsupported count, and keeps the file hotspot row unchanged.

E2: A supported ranked result is deleted at HEAD or missing from the working
tree. The project symbol section reports bounded provider caveats for that path
and emits no symbols for it.

E3: A supported ranked result is larger than the provider bounded-file policy,
not a regular file, symlinked, or unreadable. The provider reports unavailable
or skipped evidence with caveats and no private path or source detail.

E4: The worktree is dirty globally or the specific file is dirty. File-level
ranking still uses committed history. Current-line Git evidence is skipped or
lower-confidence for affected symbol ranges with visible caveats.

E5: Repository history is shallow or partial. File-level caveats remain, and
current-line symbol evidence is marked partial or lower-confidence where the
existing line-history rules require it.

E6: A provider succeeds but emits zero symbols. The report keeps provider state
and caveats so the absence of symbols is distinguishable from unsupported
language or provider failure.

E7: A provider returns byte ranges instead of line ranges. Current-line Git
evidence is skipped for that symbol or provider with caveats rather than
inventing line history.

E8: The user combines `--inspect PATH --symbols` with project-level flags. The
presence of `--inspect` selects inspect mode; existing inspect output semantics
remain the compatibility baseline.

E9: A future provider is added to the shared provider selection path. Project
symbol reports should pick it up through the shared path, but provider-specific
fixtures and docs still need to be added with that provider feature.

E10: Project mode produces many symbols across the selected ranked files. Human
output applies the display limit and reports omitted counts; JSON keeps the
complete analysed evidence unless an explicit machine cap is accepted in this
feature.

## Verification notes

Close-out evidence should include:

- `git diff --check`.
- `zig fmt --check build.zig src tests`.
- `zig build test`.
- `zig build validate`.
- `zig build validate-all` because provider lanes, CLI contracts, docs, and
  proof aggregation are affected.
- Focused unit tests for project-level symbol collection, shared provider
  selection, unsupported-path skip counts, provider failure caveats, dirty-file
  line-history degradation, and deterministic symbol ordering.
- Integration tests for valid project-level `--symbols`,
  `--symbols --symbol-line-history`, and `--symbol-limit` command shapes in
  table, Markdown, and JSON formats.
- Regression tests proving old invalid combinations remain invalid, especially
  `--symbol-line-history` without `--symbols` and `--symbol-limit` without
  `--symbols`.
- Fixture checks proving no-symbol output is unchanged when symbol flags are not
  used.
- Documentation and help validation proving README, user guide, developer
  guide, man page, `--help`, and `--explain` agree on the current-only,
  project-level symbol boundary.
- Privacy and prohibited-claim scans over new fixtures, docs, and expected
  outputs.
- Real-repository smoke evidence on this repository and one suitable sibling or
  local repository when available, recorded with privacy-safe labels, bounded
  counts, and no raw private report dump.

Review should prove that project-level symbol evidence is useful, deterministic,
bounded, local-only, and additive to file hotspots, while clearly not claiming
true historical symbol attribution or semantic relationship analysis.
