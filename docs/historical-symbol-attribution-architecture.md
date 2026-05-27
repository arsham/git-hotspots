# Historical hunk-to-symbol attribution architecture

This spike defines a future historical hunk-to-symbol attribution engine for
`git-hotspots`. It is documentation only: it changes no CLI semantics, report
schemas, scoring, provider execution, fixtures, cache behaviour, or runtime
output.

The selected first implementation path is deterministic, local-only, and
no-checkout by default. It parses historical Git blobs, intersects changed hunks
with revision-local symbol ranges, and treats every symbol result as caveated
evidence. It does not predict defects, score code quality, rank developers,
assign ownership, or judge maintainers.

## Evidence layers

Current code already has two symbol-adjacent evidence layers. The future engine
must keep them separate from true historical hunk attribution.

| Layer | Current seam | Meaning | Limits |
| --- | --- | --- | --- |
| Current symbol evidence | `src/provider.zig` `CurrentSymbolEvidence` and `src/provider_selection.zig` `attachInspectSymbols` / `attachProjectSymbols` | Parses a current file at HEAD or in the working tree and reports symbol ranges, provider state, confidence, and caveats. | Current-only. It has no lineage, ownership, dependency, snippet, or scoring fields. |
| Current-line Git evidence | `src/git_line_history.zig` `attachCurrentLineHistory` | Runs local `git blame --incremental` for current symbol line ranges and aggregates last-touch commits at HEAD. | It explains current lines only. Deleted symbols, pre-image ranges, and historical movement are outside this layer. |
| Future historical hunk attribution | New internal engine after this spike | Reads local Git history, obtains pre/post blob bytes, parses both revisions, and intersects changed hunks with revision-local symbols. | It remains probabilistic evidence quality, not semantic lineage proof. Unattributed changes fall back to file evidence. |

Existing file-level Git traversal remains the product truth. Relevant current
seams include `src/git.zig` `analyze`, `src/git_log.zig` `streamGitLog` and
`LogParser`, `src/git_history.zig` `FileAgg`, and `src/report_symbols.zig`
`orderedHumanIndexes`. The future engine should reuse their local-first and
privacy-safe conventions without changing their public behaviour.

## Approach comparison

| Approach | Decision | Rationale |
| --- | --- | --- |
| Current-line Git blame over HEAD ranges | Reject as the historical attribution engine; keep as a separate evidence layer. | It is already useful for current symbols, but it cannot attribute deleted lines, deleted symbols, historical-only symbols, or a symbol's pre-image before edits. |
| `git log -L` or text-range history | Defer. | It can trace a text range, but ranges move and split, provider ranges are language-specific, and `-L` does not provide a provider-neutral hunk model for all changed files. It may be useful later for manual explain output. |
| Checking out historical worktrees | Reject for the first implementation. | It is slower, mutates filesystem state, interacts poorly with dirty worktrees, and expands the blast radius. A no-checkout blob path is safer and more deterministic. |
| Historical blob parsing plus hunk intersection | Accept for the first implementation. | It uses local Git object data, avoids checkout, reuses provider parsing over bytes, supports pre-image and post-image attribution, and can degrade to file-level evidence when symbol precision is unavailable. |
| Semantic identity or reference analysis through LSP, ctags, or relation providers | Defer. | These providers may later improve rename or move confidence, but the first slice must not depend on semantic services, network access, global tooling, type checking, or cross-language resolution. |

## Selected architecture

The first implementation should add an internal historical attribution engine
with this shape:

1. Start from the same repository, range, scope, include, and exclude inputs as
   file analysis. Do not add network access, fetches, background upload,
   telemetry, remote enrichment, runtime LLM judgement, or mandatory cache
   truth.
2. Traverse local commits and changed files in deterministic order.
3. For each candidate changed file, read patch hunks and raw blob identities
   from Git without checking out the commit.
4. Load pre-image and post-image source bytes with `git cat-file blob <blob>`
   when the blob exists and the file is text and within size limits.
5. Parse those bytes through a provider seam that accepts `(commit, blob, path,
   source bytes)` instead of only a working-tree path.
6. Attribute hunk ranges to revision-local symbols by intersecting deleted lines
   with pre-image symbols and added lines with post-image symbols.
7. Aggregate symbol evidence under caveated report-level identities, retaining
   file-level parent links and deterministic sorting.
8. On every unsupported, binary, filtered, missing, oversized, or parse-failed
   case, keep file evidence and emit a caveat instead of inventing symbol
   precision.

Cache may be added later as a performance optimization, but the engine must have
an explicit no-cache path. Cached values must never become product truth without
being reproducible from local Git objects and provider inputs.

## Git traversal contract

The future engine should use Git as a local object database and diff producer,
not as a checkout mechanism.

### Revision and range selection

- Use `HEAD` and optional `since..HEAD` semantics consistent with
  `src/git.zig` `analyze`.
- Validate revision inputs with local `git rev-parse --verify` before traversal.
- Detect shallow history with `git rev-parse --is-shallow-repository` and
  partial/promisor history with the existing config probe pattern in
  `src/git.zig` `detectPartialClone`.
- Never auto-fetch. Shallow or partial history lowers freshness and confidence
  and adds a visible caveat.

### Scope and filters

- Apply the same include and exclude prefix semantics used by file analysis.
- Candidate files should come from the current file result set or another
  bounded local candidate list selected by a future feature contract.
- A filtered path is not parsed for symbol attribution. Its file-level evidence
  remains available where existing analysis includes it.

### Commit order

- Process commits in chronological order for aggregation, for example with a
  local reverse log or rev-list over the validated range.
- Break ties deterministically with the full object id.
- Report sorting must not depend on process iteration order. Use explicit sort
  keys described below.

### Rename edges

- Reuse the existing conservative file rename model: local Git rename edges with
  the same similarity threshold concept as `src/git.zig` `--find-renames=40%`.
- A rename edge links file paths for candidate discovery and parent file links.
- A file rename does not prove symbol identity. If a symbol is edited in the
  same renamed file, the file lineage may raise continuity confidence only when
  name, kind, and range/context evidence also agree.
- When a rename edge crosses active filters, mark lineage partial and lower
  confidence rather than pulling filtered content into scope.

### Hunk representation

Represent each changed file entry as:

- commit id and commit timestamp;
- parent id used for the diff;
- old path and new path;
- old blob id and new blob id when present;
- change status such as add, delete, modify, rename, or binary;
- ordered hunks with old start/count and new start/count;
- added and deleted line counts where Git reports them;
- caveats for binary, large, merge, filtered, generated, missing, or parse
  failure states.

Use zero-context diff hunks where possible so old and new line intervals are
explicit. Do not store source snippets in committed reports or validation
artefacts.

### Blob access

- Read historical source with `git cat-file blob <object>` or an equivalent
  local object-read helper.
- Use the old blob for deleted lines and deleted files.
- Use the new blob for added lines and added files.
- If a blob is missing, filtered by a partial clone, too large, binary, or not a
  supported text input, skip symbol parsing for that side and add a caveat.

### Binary, generated, and large files

- Binary changes produce file-level fallback only.
- Generated or vendored paths may be skipped by future policy, but the first
  engine should only claim the policy it implements locally.
- Large files and large generated-looking one-line files must be bounded by size
  and hunk-count limits and caveated when skipped.

### Merge and large-commit caveats

- First slice: skip merge commit symbol attribution unless a future contract
  explicitly selects a parent-diff policy. Keep file evidence and emit a merge
  caveat.
- Large commits that exceed the file or hunk limit should keep file-level
  evidence, mark affected symbol attribution partial, and avoid parsing every
  file by momentum.

## Provider seam for historical snapshots

Current providers read a repo-relative path through `extractPath` functions and
return `ProviderEvidence` plus `CurrentSymbolEvidence`. The future seam should
factor provider parsing so a provider can parse source bytes from a historical
snapshot:

```text
HistoricalProviderInput = {
  repo_relative_path,
  commit_id,
  blob_id,
  source_bytes,
  config_fingerprint,
}
```

The provider output should preserve the current envelope fields from
`src/provider.zig`:

- provider name, kind, version, and contract version;
- configuration fingerprint;
- local input identity, now derived from commit/blob/path;
- freshness, failure, confidence, and caveats;
- local-only provenance.

Provider implementations may share query logic with current providers, but they
must not assume the working tree exists at that revision. Unsupported language,
invalid historical syntax, parse failure, timeout, and skipped paths must return
provider failure states and caveats. Parser diagnostics and source snippets must
not be emitted in public artefacts.

The provider seam remains provider-neutral. Tree-sitter is the likely first
parser family because current providers already map source ranges to symbols,
but LSP, ctags, dependency, relation, package, reference, type, and macro
providers are not prerequisites for the first historical engine.

## Symbol identity and confidence

### Revision-local symbol identity

A revision-local symbol identity describes one symbol observation in one blob.
It should include:

- provider name and provider contract version;
- commit id and blob id;
- repo-relative path at that revision;
- symbol kind;
- symbol name when available;
- one-based inclusive line range or byte range;
- nesting or context path when the provider can expose it deterministically;
- provider freshness, failure, confidence, and caveats;
- configuration fingerprint when provider configuration affects output.

This identity is evidence about a specific revision. It is not a claim that the
same logical symbol exists in another revision.

### Report-level symbol identity

A report-level symbol identity groups revision-local observations for display.
The first implementation should use conservative deterministic keys, for
example:

1. canonical file lineage path;
2. symbol kind;
3. symbol name;
4. nearest deterministic nesting/context when available;
5. current-symbol link when a matching current symbol exists at HEAD.

When those inputs diverge, the report should split identities or lower
confidence. It must not silently claim semantic lineage.

### Confidence-lowering cases

- Duplicate names in one file require range and nesting/context to distinguish
  identities. Without context, keep separate observations or lower confidence.
- Nested symbols require parent context when available. A nested helper and a
  top-level function with the same name must not be merged by name alone.
- Deleted symbols can be reported as historical-only or deleted when the
  pre-image provider parsed them. If pre-image parsing failed, use file-level
  fallback.
- File renames preserve file lineage only. They do not prove symbol lineage.
- Symbol renames should remain separate identities unless a later semantic
  provider supplies explicit evidence. Name/kind/range similarity can only
  lower or raise confidence within a caveated heuristic.
- Symbol moves within a file may use name, kind, nesting, and range proximity as
  a weak continuity hint. Moves across files also need file lineage evidence and
  should usually remain separate in the first slice.
- Splits and merges should not be collapsed. Attribute each hunk to the parsed
  symbol or fallback bucket it intersects.
- Parse failures, unsupported providers, stale inputs, shallow or partial
  history, binary changes, missing blobs, and large skips lower confidence.
- Historical-only and current-symbol relationships are links, not proof of full
  lineage.

## Hunk attribution semantics

Attribution uses line interval intersection. A hunk can contribute to multiple
symbols when its changed lines overlap multiple ranges. If overlap cannot be
computed safely, route the evidence to file-level fallback or an unattributed
bucket.

| Change shape | Attribution rule |
| --- | --- |
| Added lines | Parse the post-image. Attribute added new-line intervals to post-image symbols whose ranges intersect those intervals. If the hunk adds a new symbol, the post-image symbol can receive the evidence. |
| Deleted lines | Parse the pre-image. Attribute deleted old-line intervals to pre-image symbols whose ranges intersect those intervals. If the symbol no longer exists at HEAD, mark it historical-only or deleted. |
| Modified lines | Treat as deleted old-line intervals plus added new-line intervals. Attribute each side independently and join them only when identity evidence is sufficient. |
| Whole-file addition | Parse the new blob and attribute file creation pressure across parsed top-level symbols, or to a module/file pseudo-symbol when ranges are unavailable. |
| Whole-file deletion | Parse the old blob and mark parsed symbols historical-only/deleted, or fallback to the file bucket if parsing fails. |
| Binary change | Do not parse. Record binary caveat and file-level fallback only. |
| No symbol intersection | Use file-level fallback, a module/file pseudo-symbol, or an unattributed bucket with lower confidence. Do not choose the nearest symbol. |
| Provider parse failure | Preserve file evidence, mark provider failure, lower confidence, and avoid symbol precision. |

A hunk touching whitespace, imports, module declarations, comments, or generated
regions may legitimately remain unattributed at symbol level. That is an honest
result, not a failure of file-level hotspot evidence.

## Future aggregate and report shape

A future report can add symbol-level aggregates only after a separate runtime
feature approves public output. The shape should remain additive to file results
and should not replace file scoring.

Suggested symbol aggregate fields:

- parent file path, file rank, and file score link;
- report-level symbol id and revision-local evidence ids;
- symbol name, kind, current path, and historical path aliases;
- current, historical-only, deleted, or unknown status;
- change frequency from attributed hunks;
- churn-like line pressure from added/deleted lines when available;
- recency from attributed commit timestamps;
- bounded sample commit ids with no messages or authors;
- provider names, versions, freshness, failures, and confidence;
- attribution confidence and caveats;
- unattributed hunk count and fallback reason;
- deterministic sort inputs.

Suggested deterministic sort order:

1. descending attributed change frequency;
2. descending attributed line pressure;
3. descending most recent attributed timestamp;
4. parent file rank;
5. repo-relative path;
6. symbol kind;
7. symbol name;
8. range start and range end;
9. provider name.

These fields explain local evidence. They must not introduce bug prediction,
code-quality scoring, maintainer judgement, developer ranking, productivity
analytics, ownership fields, author identities, commit messages, source
snippets, remotes, or absolute local paths.

## Performance bounds and stop conditions

The first runtime slice should be useful without a cache and should fail closed
when limits are exceeded.

Suggested initial bounds for the first implementation feature:

- candidate files: default to the displayed file result set; hard cap 200 files;
- commits: hard cap 5,000 commits in the selected range for symbol attribution;
- changed file entries: hard cap 25,000 entries;
- hunks: hard cap 100,000 parsed hunks;
- per-file source bytes: hard cap 1 MiB before provider parsing;
- per-blob provider runtime: bounded timeout chosen by the implementation
  feature and recorded in caveats;
- provider failures: stop provider parsing after a configurable failure budget
  and keep file-level evidence;
- sample commits per symbol: cap at three to match existing bounded evidence
  style.

The engine should stream commit and hunk records, parse one blob side at a time,
and release source bytes after attribution. It may batch repeated blob reads
inside one process, but it must not require a persistent cache. Memory ownership
should be explicit: caller owns aggregate slices, provider owns no global state,
and blob byte buffers are freed after attribution or batch completion.

Progress reporting should reuse the existing opt-in progress style: repository
check, Git traversal, blob/provider attribution, aggregation, and rendering.
Progress must not print private paths from sibling repositories in committed
validation evidence.

Stop symbol attribution and continue with file-level evidence when:

- the repository is shallow or partial and needed objects are missing;
- a merge or large commit exceeds the selected policy;
- file, commit, hunk, size, timeout, or provider-failure limits are exceeded;
- a provider cannot parse the historical bytes;
- a scope filter excludes the path;
- a path is binary, generated by policy, unsupported, or missing.

## Validation plan for future implementation

Future fixtures should be small public Git repositories or generated local test
repos with deterministic commits and no private content. Expected outputs should
assert evidence shape, confidence, caveats, and ordering rather than raw source
snippets.

| Case | Expected proof |
| --- | --- |
| Simple function edit | Modified hunks attribute to the same function in pre/post images. |
| Nested symbols | Inner and outer symbols remain distinguishable; overlapping attribution is explicit. |
| Duplicate names | Same-name symbols do not merge without range/context evidence. |
| File rename | File lineage links old and new paths; symbol confidence is caveated. |
| Symbol rename | Old and new names are separate or lower-confidence linked; no proven lineage claim. |
| Symbol move | Within-file and cross-file moves are caveated unless explicit evidence exists. |
| Deleted file | Old blob is parsed; symbols become historical-only/deleted or fallback. |
| Whole-file add/delete | Additions use post-image symbols; deletions use pre-image symbols. |
| Binary change | Symbol parsing is skipped and file-level binary caveat is visible. |
| Unsupported language | Provider failure state is `unsupported`; file evidence remains. |
| Provider parse failure | Failure is caveated without parser diagnostics or snippets. |
| Large file skip | Size stop condition is visible and deterministic. |
| Shallow or partial history | No auto-fetch; incomplete evidence and lower confidence are visible. |
| Deterministic output ordering | Repeated runs produce stable symbol ordering and bounded samples. |
| Unattributed hunk | Hunk maps to file/module/unattributed fallback, not nearest-symbol guesswork. |
| Merge or large commit | First-slice skip or simplification policy is visible as a caveat. |
| Privacy scan | No absolute paths, remotes, authors, commit messages, private snippets, raw private reports, parser diagnostics, ownership fields, or productivity metrics. |
| Prohibited-claim scan | No bug prediction, code-quality scoring, developer ranking, maintainer judgement, or semantic lineage overclaim. |

Real-repository smoke expectations for that future feature:

- run this repository with public, repo-relative paths and bounded counts;
- run one suitable sibling or local repository when available, labelled only as
  `sibling-local-repo` or another privacy-safe label;
- commit only command shapes, pass/fail status, bounded counts, caveat counts,
  dirty/scope flags, elapsed time, and categorical observations;
- do not commit sibling paths, repository names, remotes, authors, emails,
  commit messages, source snippets, parser diagnostics, or raw reports.

## First runtime slice after this spike

The next independently dispatchable runtime slice should be an internal engine
and fixture proof, not a broad public report change:

1. Add a no-checkout Git hunk reader for one bounded candidate file set.
2. Add a provider byte-input seam for one existing tree-sitter provider family.
3. Parse pre/post blobs for text files under the size limit.
4. Attribute added and deleted hunk ranges to revision-local symbols.
5. Produce an internal test-only aggregate with confidence and caveats.
6. Prove fixtures for simple edits, deleted symbols, file rename plus edit,
   provider failure, binary skip, large skip, and deterministic ordering.

Deferred work remains explicit: relation/reference analysis, cross-language
resolution, semantic ownership, full symbol lineage, persistent cache, broad
provider plugin infrastructure, dependency/package semantic analysis, LSP/ctags
integration, macro or feature evaluation, and public report/schema design.

## Spike validation checklist

This document is sufficient for a future runner when review can confirm:

- the selected path is historical blob parsing plus hunk intersection;
- the path is deterministic, local-only, no-checkout by default,
  provider-neutral, performance-bounded, and cache-optional;
- current symbol evidence, current-line Git evidence, and future historical
  hunk attribution are clearly separated;
- Git traversal, provider input, symbol identity, attribution, confidence,
  fallback, aggregate fields, validation fixtures, and next slice are defined;
- public-safety boundaries are preserved; and
- existing runtime behaviour remains unchanged because this spike only adds this
  architecture document.
