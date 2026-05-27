# Internal historical hunk attribution engine and fixture proof

## Problem

Feature 0079 selected the architecture for true historical hunk-to-symbol
attribution, but the runtime still only has file-level Git evidence,
current-symbol evidence over HEAD or the working tree, and current-line blame
evidence over current symbol ranges. The project still cannot attribute local
Git hunks to revision-local symbols in old and new blobs.

B002 needs this capability to become language-extensible and performant without
overclaiming semantic lineage. The first runtime slice should therefore be an
internal engine and fixture proof, not a public report change. It must prove the
hard parts: no-checkout Git hunk/blob reading, a provider byte-input seam,
pre/post symbol range intersection, confidence/caveats, and deterministic
fixture evidence.

## Outcome

Implement an internal/test-only historical hunk attribution slice. The feature
should add internal code that can read bounded local Git hunk/blob evidence for
candidate files without checkout, parse historical source bytes through existing
Tree-sitter provider logic, attribute added and deleted hunk ranges to
revision-local symbols, aggregate caveated symbol evidence, and prove the
behaviour with deterministic fixtures.

The feature must not add a user-facing historical-symbol CLI, public JSON or
Markdown report fields, file scoring changes, current-symbol output changes,
current-line history behaviour changes, network access, telemetry, remote
enrichment, runtime AI judgement, or mandatory cache truth.

## Requirements

R1: Add an internal historical hunk attribution module or modules. The code must
be callable from tests and future internal integration, but no public CLI option
or public report schema may expose historical symbol results in this feature.

R2: Add a no-checkout local Git hunk/blob reader for one bounded candidate file
set. It must use local Git plumbing or equivalent local commands, not worktree
checkout, fetch, pull, network access, background upload, or a persistent cache
requirement.

R3: The Git reader must represent commit id, parent id where available,
commit timestamp when available, old path, new path, old blob id, new blob id,
change status, ordered hunks, old/new line intervals, binary or missing states,
and caveats for skipped or partial evidence.

R4: Git traversal and parsing must be deterministic. Processing order, hunk
order, sample commit order, and aggregate ordering must not depend on hash-map
or process iteration order.

R5: The first slice must enforce explicit bounds for candidate files, commits,
changed file entries, hunks, blob bytes, provider failures, and sample commits.
When a bound is exceeded, the engine must retain file-level/fallback evidence
and add a caveat rather than silently continuing unbounded work.

R6: Add a provider byte-input seam for historical snapshots. The seam must parse
source bytes identified by repo-relative path, commit id, blob id, and provider
configuration context rather than assuming the working tree exists at that
revision.

R7: The provider seam should dispatch by path through the existing Tree-sitter
provider family so supported languages can benefit automatically as their
providers expose source-byte parsing. The close-out proof may use one language
fixture first, but the dispatch seam must not hard-code hotspot scoring or
history semantics per language.

R8: Keep current-only provider contracts separate. Existing current-symbol
public evidence must remain current-only and must not gain lineage, ownership,
dependency, snippet, author, or scoring fields. Historical attribution may use
new internal revision-local symbol records or an internal wrapper around provider
source parsing.

R9: Attribute deleted old-line intervals to symbols parsed from the pre-image
old blob, and added new-line intervals to symbols parsed from the post-image new
blob. Treat modified lines as deleted-side plus added-side evidence and only join
sides when conservative identity evidence permits.

R10: A hunk may attribute to multiple symbols when changed intervals intersect
multiple ranges. When no safe symbol intersection exists, the engine must route
evidence to a file/module/unattributed fallback with lower confidence; it must
not choose the nearest symbol.

R11: Internal aggregate records must include parent file path, symbol kind and
name when available, revision-local range, current/historical/deleted/unknown
status, change count, churn-like added/deleted line pressure when available,
recency or latest timestamp when available, bounded sample commit ids, provider
state, confidence, caveats, fallback counts, and deterministic sort inputs.

R12: Bounded sample commits must include commit ids only. They must not include
commit messages, authors, emails, remotes, source snippets, parser diagnostics,
absolute local paths, private repository names, ownership metrics, productivity
metrics, bug-prediction claims, or code-quality scoring claims.

R13: Fixture proof must use generated local repositories with deterministic
commits and public-safe contents. Committed expected evidence should assert
shape, counts, confidence, caveats, and ordering, not raw private reports or
private source snippets.

R14: Fixture proof must cover at least: simple function edit, deleted symbol or
deleted file, file rename plus edit, unsupported or provider-failure fallback,
binary skip, large file skip, no-symbol/unattributed fallback, and deterministic
ordering across repeated runs.

R15: Existing CLI behaviour, public table/JSON/Markdown reports, explain output,
current project-symbol reports, current-line history reports, file-level scoring,
scoping, and privacy/prohibited-claim validation must remain unchanged except
for any necessary internal test/build surfaces.

R16: The feature may add a targeted Zig build test step or proof target for the
internal engine. If a new test target is added, it must be included in the normal
local validation path or be directly exercised by close-out commands.

R17: Documentation changes are optional. If public docs are touched, wording must
preserve the evidence-only tone and clearly state that historical symbol output
is not yet a user-facing report surface.

## Non-goals

- No user-facing historical symbol CLI, flag, report field, export schema, or
  man-page surface.
- No public scoring replacement or file-ranking changes.
- No semantic symbol lineage proof, cross-language resolution, reference graph,
  call graph, dependency propagation, package semantic analysis, type checking,
  macro expansion, or ownership inference.
- No LSP, ctags, network service, runtime LLM, hosted enrichment, telemetry,
  upload, or remote index dependency.
- No persistent cache as product truth. A process-local batch optimisation is
  acceptable only if the no-cache path remains correct.
- No worktree checkout of every historical commit.
- No private raw report output, absolute local paths, remotes, authors, emails,
  commit messages, parser diagnostics, source snippets, or private repository
  names in committed artefacts.

## Edge cases

E1: A hunk touches imports, comments, whitespace, module declarations, generated
regions, or other lines outside parsed symbols. The engine must attribute this
to fallback/unattributed evidence with a caveat.

E2: A hunk deletes a symbol that does not exist in the post-image or at HEAD.
The engine must parse the pre-image when available and mark the symbol as
historical-only/deleted, or fall back if pre-image parsing fails.

E3: A hunk adds a new symbol. The engine must parse the post-image and attribute
added line intervals to the new revision-local symbol when ranges intersect.

E4: A commit renames a file and edits a symbol. The engine may use file rename
edges for file lineage and candidate discovery, but must not claim semantic
symbol lineage from the rename alone.

E5: Duplicate or nested symbol names appear in one file. The engine must use
range and nesting/context when available, split or lower confidence when not,
and avoid name-only merges.

E6: A provider cannot parse a historical blob because syntax is invalid,
unsupported, too large, or otherwise unavailable. The engine must preserve file
or hunk fallback evidence and caveat provider failure without exposing parser
diagnostics.

E7: A changed file is binary, missing from local objects, too large, filtered by
scope, or unsupported. The engine must skip symbol parsing for that side and
record deterministic fallback/caveat evidence.

E8: Merge commits or large commits exceed the first-slice policy. The engine
must skip or simplify according to an explicit local policy and report the caveat
internally instead of expanding scope by momentum.

E9: A shallow or partial repository lacks needed objects. The engine must not
auto-fetch and must report incomplete evidence or missing blob caveats.

E10: Repeated runs over the same fixture produce equal evidence. Sorting and
bounded samples must remain stable.

## Verification notes

Close-out evidence should include:

- `git diff --check`.
- `zig fmt --check build.zig src tests`.
- Targeted internal historical attribution proof command if the feature adds one.
- `zig build test`.
- `zig build validate`.
- Fixture proof that covers the required edit/delete/rename/provider failure,
  binary, large, unattributed, and deterministic-ordering cases.
- A reviewer check that no public CLI/report/schema/scoring behaviour changed.
- A reviewer check that provider and historical evidence stay local-only,
  deterministic, caveated, and privacy-safe.
