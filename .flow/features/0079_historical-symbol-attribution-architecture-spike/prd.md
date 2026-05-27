# Historical symbol attribution architecture spike

## Problem

`git-hotspots` now has two symbol layers: inspect/project current-symbol
reports over HEAD files, and optional current-line Git evidence via
`git blame --incremental` over current symbol ranges. That is useful, but it is
still not true historical symbol attribution. It can say which current symbols
sit inside hot current files; it cannot say which historical functions, methods,
types, or modules were touched by specific commits or hunks across local Git
history.

B002 asks for symbol-granular hotspot evidence that is provider-neutral,
performant, deterministic, and honest. The next step should not jump straight
into a production attribution engine. The architecture needs a bounded design
spike that proves how to use local Git history and provider output together
without checking out every commit, overclaiming rename or move lineage, or
turning provider output into semantic truth.

## Outcome

Produce a durable architecture decision and proof plan for true historical
symbol attribution. The feature should leave the repository with one concise
architecture document that future implementation features can execute against:
`docs/historical-symbol-attribution-architecture.md`.

The architecture should choose and justify a first implementation path for
historical symbol evidence. It should define the data model, Git traversal
strategy, provider seam changes, attribution semantics, confidence model,
performance bounds, validation fixtures, and non-goals needed before a runtime
engine is implemented.

The expected direction is a no-checkout, local-only pipeline:

- start from existing file-level history and scope filters;
- collect changed file revisions and hunks for candidate files;
- read historical blobs through Git plumbing such as `git cat-file --batch` or
  equivalent local commands;
- parse only relevant historical file snapshots with the registered symbol
  provider;
- intersect changed hunk ranges with revision-local symbol ranges; and
- aggregate deterministic symbol evidence with explicit confidence caveats.

The spike may include small read-only prototype probes or fixture experiments to
validate assumptions, but it must not add a user-facing historical-symbol CLI,
change file scoring, or introduce a production cache/index.

## Requirements

R1: Produce `docs/historical-symbol-attribution-architecture.md` as the primary
spike deliverable. The document must be concise, public-safe, and specific
enough that a future runner can implement the first engine slice without
needing this chat.

R2: Compare at least these attribution approaches and record why each is
accepted, rejected, or deferred:

- current-line `git blame` over HEAD ranges;
- `git log -L` or text-range history;
- checking out historical worktrees;
- parsing historical Git blobs and intersecting changed hunks with symbol
  ranges; and
- semantic identity/reference analysis through LSP, ctags, or relation
  providers.

R3: Select one recommended first implementation architecture. The selected path
must remain deterministic, local-only, and no-checkout by default. It must avoid
network access, telemetry, remote enrichment, background upload, runtime LLM
judgement, and mandatory cache truth.

R4: Define the Git-history traversal contract. It must describe which Git data
is needed, how commit order and ranges are selected, how scope/include/exclude
filters and file rename edges apply, how hunks are represented, and how shallow
or partial history degrades confidence.

R5: Define the provider seam needed for historical snapshots. The design must
explain how current providers can be reused or adapted to parse source bytes
from a `(commit, blob, path)` identity instead of only reading a working-tree
path, while preserving provider name, version, freshness, failure, confidence,
configuration fingerprint, and caveats.

R6: Define revision-local symbol identity separately from report-level symbol
identity. At minimum, cover provider, commit or blob identity, path, kind, name,
range, nesting/context when available, and confidence. The design must describe
how duplicate names, nested symbols, deleted symbols, renamed files, renamed
symbols, moved symbols, split symbols, and merged symbols lower confidence.

R7: Define hunk-to-symbol attribution semantics. The design must state how
added lines, deleted lines, modified lines, binary changes, whole-file additions
or deletions, and parse failures map to symbols or file-level fallback. It must
not fabricate symbol precision when a hunk cannot be attributed.

R8: Define symbol hotspot aggregate fields for a future report. Include change
frequency, churn-like line pressure where available, recency, sample commit ids,
provider state, evidence caveats, confidence, parent file links, historical-only
or current-symbol status, and deterministic sort inputs. The design may reuse
file scoring concepts, but must not claim a finished scoring replacement.

R9: Define performance bounds and stop conditions. The architecture must cover
candidate file limits, commit/hunk limits, file-size limits, provider failure
limits, memory ownership, streaming or batching strategy, progress reporting,
and an explicit no-cache path. Any cache discussion must be future
optimisation only.

R10: Define privacy and public-claim boundaries. Architecture and examples must
not include absolute local paths, remotes, author identities, commit messages,
source snippets from private repositories, parser diagnostics, raw private
reports, ownership/productivity metrics, bug prediction, code-quality scoring,
or developer ranking claims.

R11: Define validation fixtures for future implementation. The fixture plan
must cover at least simple function edits, nested symbols, duplicate names,
file rename, symbol rename, symbol move, deleted file, whole-file add/delete,
binary change, unsupported language, provider parse failure, large file skip,
shallow or partial history caveat, and deterministic output ordering.

R12: Define real-repository smoke expectations for future implementation. The
plan must use this repository and one suitable sibling or local repository when
available, with privacy-safe labels and bounded counts only.

R13: Identify the first runtime implementation slice after the spike. The
follow-up slice must be small enough to dispatch independently, and the spike
must state what remains deferred: relation/reference analysis, cross-language
resolution, semantic ownership, full symbol lineage, persistent cache, and broad
provider plugin infrastructure.

R14: Keep existing runtime behaviour unchanged. This spike must not alter CLI
semantics, report schemas, provider extraction behaviour, file ranking, current
symbol output, current-line history, validation fixtures, or public docs except
for adding the architecture document and any required Flow artefacts.

## Non-goals

- No user-facing historical-symbol CLI or report implementation.
- No production historical attribution engine.
- No runtime scoring changes or file-ranking changes.
- No full historical symbol lineage, semantic symbol rename tracking, or symbol
  move proof.
- No reference graph, call graph, dependency propagation, LSP dependency,
  ctags dependency, package graph, macro expansion, cfg or feature evaluation,
  type checking, or cross-language resolution.
- No checking out every commit into the worktree.
- No network access, telemetry, upload, remote enrichment, hosted service,
  runtime AI judgement, or mandatory cache.
- No private-repository raw evidence, absolute paths, source snippets, author
  identities, commit messages, or parser diagnostics in committed artefacts.

## Edge cases

E1: A hunk touches lines that do not intersect any parsed symbol. The design
must route that evidence to file-level fallback, module/file pseudo-symbol, or
an unattributed bucket with lower confidence instead of inventing a symbol.

E2: A hunk deletes a symbol that no longer exists in the post-image. The design
must parse the pre-image or mark the symbol as historical-only/deleted with
lower confidence.

E3: A hunk adds a new symbol that did not exist in the pre-image. The design
must parse the post-image and attribute added lines to the new symbol when
ranges are valid.

E4: A commit renames a file and edits a symbol in the same change. The design
must state how existing file rename edges are used, and where symbol confidence
is lowered because symbol identity is not semantically proven.

E5: A symbol is renamed without moving much code. The design must not treat the
rename as proven lineage unless the future implementation has explicit evidence;
it should define a lower-confidence matching or separate historical/current
symbols.

E6: A symbol moves within a file or across files. The design must state whether
range overlap, name/kind/nesting, or file lineage can suggest continuity and
which cases remain separate symbols.

E7: A provider cannot parse a historical blob because the historical syntax is
invalid or unsupported. The design must preserve file evidence, mark provider
failure, and lower symbol confidence.

E8: A changed file is binary, generated, too large, missing from the blob store,
or filtered by scope. The design must define skip/fallback behaviour and
caveats.

E9: Merge commits or large commits touch many files. The design must specify
whether merge diffs are included, simplified, or skipped and how large-commit
caveats propagate.

E10: A repository is shallow or partial. The design must preserve local-first
behaviour, not auto-fetch, and report incomplete evidence.

## Verification notes

Close-out evidence for this spike should include:

- `git diff --check`.
- `zig fmt --check build.zig src tests` when source or test files are touched;
  if only docs/Flow files change, state why Zig formatting is not applicable.
- `zig build test` when any Zig source, tests, build logic, or generated query
  assumptions are touched.
- `zig build validate` when docs, help, validation surfaces, or public claims
  are touched.
- Markdown/prohibited-claim review for
  `docs/historical-symbol-attribution-architecture.md`.
- Read-only prototype evidence or command transcripts, if included, summarised
  with privacy-safe labels and bounded counts only.
- A reviewer check that the architecture document clearly separates current
  symbol evidence, current-line Git evidence, and future true historical
  hunk-to-symbol attribution.
- A reviewer check that the selected architecture is no-checkout, local-only,
  provider-neutral, and performance-bounded.

Review should not require a working runtime historical attribution engine. It
should prove that the spike produced a precise, honest, implementable
architecture and next-slice plan.
