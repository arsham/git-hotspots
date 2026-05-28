# Symbol relationship architecture spike

## Problem

`git-hotspots` can now expose current symbol evidence, historical
hunk-to-symbol attribution, and an opt-in historical symbol hotspot report.
The next B002 capability question is how to answer: "which symbols are
referenced by, used by, or otherwise related to hot places?"

That question is useful for investigation and agent handoff, but it is also
risky. Relation evidence can easily be mistaken for a full call graph,
dependency graph, type-aware semantic truth, ownership, bug prediction, or
code-quality scoring. The project needs a provider-neutral architecture before
adding runtime relation analysis or public CLI output.

## Outcome

Produce a documentation-only architecture spike at
`docs/symbol-relationship-architecture.md`. The document should define a
local-first, deterministic, provider-neutral relation evidence model that can
attach future reference/use/dependency-like evidence to existing file,
current-symbol, and historical-symbol hotspot results without changing scoring
truth or public runtime behaviour in this feature.

## Requirements

R1: Deliver `docs/symbol-relationship-architecture.md` as the only product
artefact. The spike must not add CLI flags, report fields, runtime provider
execution, scoring changes, fixtures, cache files, dependencies, or release
packaging changes.

R2: Define relation evidence as investigation context attached to existing
hotspot evidence. The document must explicitly state that relation evidence is
not bug prediction, code-quality scoring, maintainer judgement, ownership,
author productivity, or proof of semantic dependency correctness.

R3: Keep the architecture provider-neutral. Language-specific providers may
emit relation candidates later, but common aggregation, confidence, caveats,
sorting, output semantics, and fallback behaviour must stay shared.

R4: Define a relation provider input and output contract that can work with
current working-tree symbols and future historical snapshot inputs without
requiring checkout, network access, telemetry, runtime LLM judgement, global
LSP services, mandatory cache, or remote enrichment.

R5: Define supported first-class relation kinds and their semantics. At
minimum compare or classify references, calls, imports/includes,
contains/nesting, file co-change adjacency, and unknown/unresolved relations;
the document must distinguish syntactic evidence from type-aware or
runtime-dispatched certainty.

R6: Define stable relation endpoints. Endpoints must be able to reference file
hotspots, current symbols, historical symbol observations, and report-level
symbol identities while preserving confidence caveats when a symbol is renamed,
moved, deleted, unsupported, or only historically observed.

R7: Define relation confidence, freshness, failure state, and caveat handling.
Unsupported languages, provider parse failures, ambiguous dynamic constructs,
missing blobs, partial/shallow history, macro/generated code, and cross-language
edges must degrade deterministically rather than fabricating precision.

R8: Define deterministic aggregation and sorting rules. Output order, sampled
edges, and summary counts must not depend on hash-map, filesystem, provider, or
process iteration order.

R9: Define how future relation evidence should attach to existing public
surfaces without changing current feature behaviour: file hotspots remain
ranking truth, historical symbol hotspots remain evidence attached to retained
file candidates, and relation evidence remains optional additive context.

R10: Define performance constraints and limits for a future implementation:
bounded candidate sets, no whole-repository relation graph by default, no
per-commit whole-tree parsing by default, explicit caps for files/symbols/edges,
and visible caveats when limits are reached.

R11: Compare candidate implementation approaches, including tree-sitter local
syntax references, LSP references, ctags-like indexing, dependency/package
data, co-change adjacency, and hybrid provider approaches. The selected first
runtime slice should be narrow and local-only.

R12: Recommend the next implementation feature after the spike, including
public/non-public scope, likely files, fixture strategy, real-repository smoke
requirements, and escalation triggers.

R13: Keep all examples project-relative or synthetic. The document must not
include raw private report output, absolute local paths, remotes, author names,
emails, commit messages, parser diagnostics, or source snippets from private
repositories.

R14: Update B002 only to record the durable architecture decision and feature
link. Do not close B002 unless the operator explicitly asks.

## Non-goals

- No runtime relation provider implementation.
- No public CLI flag, JSON schema, table, Markdown, or explain output changes.
- No full call graph, dependency graph, package graph, type checking, macro
  expansion, cross-language resolution, or dynamic dispatch proof.
- No semantic proof of references, usage, ownership, blame, lineage, or impact.
- No scoring replacement or relation-based file/symbol ranking.
- No cache product truth, hosted service, network provider, telemetry, runtime
  LLM, or remote index.
- No browser-visible UI work.

## Edge cases

E1: A provider can see a syntactic reference but cannot resolve the target. The
architecture must preserve an unresolved relation with explicit caveats rather
than inventing a target.

E2: A symbol is historical-only or deleted. Relation endpoints may reference the
historical observation, but must not claim the current code still contains that
symbol.

E3: A relation crosses a file rename or symbol move. The architecture may carry
file-lineage or identity hints, but must not claim semantic continuity without
evidence.

E4: A language has no relation provider. Existing file and symbol hotspot
reports must still work, with relation evidence absent or explicitly
unsupported.

E5: Dynamic languages, macro-heavy files, generated files, or partial syntax
should lower confidence and add caveats rather than failing the full analysis.

E6: Relation candidate counts become too large. The future runtime design must
cap candidates deterministically and expose omitted counts/caveats.

E7: Co-change adjacency is available but semantic references are not. The
document must classify co-change as historical adjacency, not use/reference
truth.

## Verification notes

Close-out evidence should include:

- `git diff --check`.
- Markdown formatting review for `docs/symbol-relationship-architecture.md`.
- `flow validate --target feature:0083`.
- `flow validate --target brief:B002`.
- `zig build validate` to ensure docs/prohibited-claim/runtime-dependency checks
  still pass.
- Independent reviewer verification that the architecture is documentation-only,
  local-first, provider-neutral, evidence-only, and ready to support a narrow
  implementation successor.
