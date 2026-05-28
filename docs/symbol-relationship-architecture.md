# Symbol relationship architecture

This spike defines a future relationship-evidence layer for `git-hotspots`.
It is documentation only: it changes no CLI flags, report schemas, scoring,
runtime provider execution, fixtures, dependencies, cache behaviour, or output.

Relationship evidence is optional investigation context attached to existing
file, current-symbol, and historical-symbol hotspot evidence. It helps a user
ask, "what local evidence suggests these hot places are adjacent or connected?"
It is not bug prediction, code-quality scoring, maintainer judgement,
author-productivity analysis, ownership, or proof of semantic dependency
correctness.

## Existing evidence layers

The relation layer should consume current product evidence instead of replacing
it.

| Layer | Current seam | Meaning | Relation boundary |
| --- | --- | --- | --- |
| File hotspot evidence | `src/model.zig` `Result` and Git analysis | File-level Git-history ranking remains the product truth. | Relations may attach to retained file results, but must not change file scores or ranking. |
| Current symbol evidence | `src/provider.zig` `CurrentSymbolEvidence` | Current working-tree symbol spans from optional providers. | Relations may point at current symbols when the provider can identify an endpoint, but current symbols are not lineage proof. |
| Current-line history | `CurrentLineHistoryEvidence` | Local blame-style evidence for current symbol line ranges. | Relations may reuse caveats and freshness, but must not infer authorship, ownership, or productivity. |
| Historical symbol evidence | `src/historical_symbol_attribution.zig` `AggregateRecord` | Caveated hunk-to-symbol attribution over local Git blobs. | Relations may point at historical observations, including deleted symbols, while preserving historical-only caveats. |

File-level ranking stays authoritative. Symbol and relation evidence enriches the
explanation for a retained result and can be absent without breaking existing
reports.

## Goals

- Define provider-neutral relation evidence that future language providers can
  emit without rewriting common aggregation.
- Preserve deterministic, local-first runtime defaults: no network access,
  telemetry, remote enrichment, runtime LLM judgement, mandatory cache, or
  global service dependency.
- Keep relation evidence additive to file and symbol hotspot evidence.
- Describe endpoint identities, relation kinds, confidence, freshness, failures,
  caveats, sorting, and limits before implementation.
- Select a narrow local-first runtime successor for a later feature.

## Non-goals

- No runtime relation provider implementation in this feature.
- No public CLI flag, JSON field, table column, Markdown section, explain output,
  fixture, dependency, cache, or release packaging change.
- No full call graph, dependency graph, package graph, type checker, macro
  expansion, cross-language resolver, or dynamic-dispatch proof.
- No semantic proof of references, usage, ownership, blame, lineage, impact, or
  maintainer responsibility.
- No scoring replacement and no relation-based ranking of files or symbols.
- No hosted service, network provider, telemetry, runtime LLM, remote index, or
  cache product truth.
- No browser-visible UI work.

## Relation evidence semantics

A relation candidate records bounded local evidence that one hotspot-relevant
endpoint appears adjacent to, references, contains, imports, calls, or otherwise
connects to another endpoint. The candidate is evidence about an input and a
provider result, not a fact about the program's runtime behaviour.

Every relation candidate should carry:

- source endpoint and target endpoint, with unresolved targets allowed;
- relation kind;
- direction, when meaningful;
- provider envelope and provider input identity;
- freshness, failure state, confidence, and caveats;
- local provenance and deterministic sort keys;
- sampled evidence identifiers such as commit ids or path/range coordinates,
  never source snippets, authors, emails, remotes, or commit messages.

When a provider cannot resolve a target, the architecture must preserve an
`unresolved` relation with explicit caveats rather than inventing a target. When
a language has no relation provider, existing file and symbol hotspot reports
must continue to work with relation evidence absent or marked unsupported.

## Endpoint identities

Relation endpoints need to point at existing hotspot surfaces without requiring
one universal symbol identity.

### Endpoint kinds

A future internal endpoint shape should support at least:

- `file`: a repo-relative file hotspot path and optional lineage aliases;
- `current_symbol`: a current provider symbol span attached to a retained file;
- `historical_symbol`: a revision-local or aggregate historical symbol
  observation;
- `report_symbol`: a caveated report-level symbol identity built from existing
  current or historical evidence;
- `unresolved`: a provider-observed name, path, import string, or syntactic
  target that cannot be mapped safely;
- `external`: a package, module, or library name known only as a bounded local
  string, not a remote lookup result.

Endpoint fields should be repo-relative and privacy-safe. They may include a
provider name, provider contract version, file path, symbol kind, symbol name,
line or byte range, commit id, blob id, status, confidence, and caveats. They
must not include absolute local paths, remotes, author names, emails, raw private
reports, parser diagnostics, source snippets, or commit messages.

### Current, historical, and report-level endpoints

A current symbol endpoint means the provider saw a symbol in the current
working-tree or `HEAD` input. It does not prove that earlier revisions contained
the same logical symbol.

A historical symbol endpoint means the provider saw a revision-local symbol
observation or a historical aggregate. It may reference deleted or
historical-only code, but it must not claim the current code still contains that
symbol.

A report-level symbol endpoint is a display grouping. It can link current and
historical observations when conservative identity evidence agrees, but any
rename, move, delete, unsupported language, or parse failure must lower
confidence or split endpoints. File rename hints and symbol-name similarity are
continuity hints, not semantic proof.

## Relation kinds

The first-class relation kinds should have narrow semantics so reports can stay
honest across providers.

| Kind | Meaning | Caveats |
| --- | --- | --- |
| `reference` | A local syntax provider observed a name, selector, identifier, or token that appears to refer to a target. | May be syntactic only. If target resolution is missing or ambiguous, keep an unresolved endpoint. |
| `call` | A provider observed call-like syntax from one endpoint toward another. | Does not prove dynamic dispatch, runtime receiver type, macro expansion, or execution. |
| `import_include` | A file or symbol scope imports, includes, requires, or otherwise names another module or file-like target. | Package managers, generated code, conditional imports, and aliases may lower confidence. |
| `contains` | One endpoint lexically or structurally contains another endpoint. | Nesting is provider evidence, not ownership or maintainer responsibility. |
| `co_change` | Two files or symbols changed near each other in local Git history. | Historical adjacency only. It is not dependency, reference, use, or impact truth. |
| `unknown` | The provider found relation-like evidence but cannot classify it safely. | Keep caveats visible and sort deterministically. |
| `unresolved` | A relation source is known but the target cannot be mapped safely. | Preserve the observed local string or category without fabricating an endpoint. |

Providers may later add more specific subkinds, but common aggregation should
map them back to these shared kinds until a separate public contract approves a
broader vocabulary.

## Provider-neutral input contract

Relation providers should receive bounded local inputs chosen by the common
engine. They must not discover the whole repository by default.

A future provider input can be modelled as:

```text
RelationProviderInput = {
  repo_root_identity,
  analysis_head,
  scope_fingerprint,
  candidate_files,
  current_symbol_evidence,
  historical_symbol_evidence,
  provider_config_fingerprint,
  limits,
}
```

`candidate_files` should be derived from retained file hotspots, inspected file
scope, or another explicit bounded candidate set. Current and historical symbol
evidence should be passed as optional context; a provider must be able to return
unsupported or partial evidence when that context is unavailable.

The input must not require checkout of historical commits, network access,
telemetry, remote enrichment, runtime LLM judgement, mandatory cache, global LSP
services, or source snippets in public artefacts. Providers may use local files,
local Git blobs, or local tools only when the future implementation feature
explicitly opts in and records caveats.

## Provider-neutral output contract

A future provider output can be modelled as:

```text
RelationProviderOutput = {
  provider_evidence,
  candidates,
  omitted_candidate_count,
  unsupported_file_count,
  caveats,
}

RelationCandidate = {
  source_endpoint,
  target_endpoint,
  kind,
  direction,
  evidence_basis,
  freshness,
  failure,
  confidence,
  caveats,
  deterministic_key,
}
```

`provider_evidence` should follow the existing provider envelope pattern:
provider name, kind, version, contract version, configuration fingerprint, local
input identity, freshness, failure, confidence, caveats, and local provenance.

`evidence_basis` should describe the source of evidence as bounded metadata,
such as `current-syntax`, `historical-hunk-adjacency`, `import-string`, or
`local-tool-index`. It should not contain source snippets, parser diagnostics,
authors, emails, remotes, commit messages, or absolute paths.

Unsupported languages, parse failures, ambiguous dynamic constructs, missing
blobs, shallow or partial history, macro-heavy code, generated files, and
cross-language edges should return candidates with lower confidence or visible
caveats. They should not fail the core file analysis or fabricate precision.

## Confidence, freshness, failure, and caveats

Relation confidence describes evidence quality only. It is not code quality,
bug likelihood, impact severity, ownership, or developer performance.

Suggested confidence inputs:

- endpoint type: file, current symbol, historical symbol, report symbol, or
  unresolved;
- provider support for the language and syntax form;
- whether target resolution is syntactic, type-aware, local-tool-assisted, or
  unresolved;
- whether evidence is current-only, historical-only, deleted, partial, stale, or
  fresh;
- shallow or partial history state;
- macro, generated, dynamic, vendored, or cross-language caveats;
- candidate and edge caps reached by the common engine.

Suggested freshness states should mirror provider evidence: `fresh`, `stale`,
`partial`, and `unknown`. Suggested failure states should include `ok`,
`unavailable`, `unsupported`, `failed`, `timed_out`, and `skipped`.

Caveats must be attached where a user sees the evidence. Important caveats
include unresolved target, unsupported language, parser failure, local tool
missing, stale provider input, partial history, missing blob, dynamic dispatch,
macro or generated code, path filtered by scope, candidate cap reached, and
co-change only.

## Deterministic aggregation and sorting

The common engine should aggregate relation candidates after provider output,
not inside each language provider. Providers can emit raw candidates; shared
aggregation owns limits, deduplication, caveat merging, and sorting.

Aggregation rules:

1. Normalize endpoints to repo-relative, provider-neutral identities.
2. Preserve unresolved endpoints instead of dropping them or inventing targets.
3. Merge identical candidates only when source endpoint, target endpoint,
   relation kind, direction, provider, and evidence basis all match.
4. Keep co-change adjacency in its own relation kind; never merge it into
   references, calls, imports, or contains relations.
5. Retain provider failures and caveats even when another provider succeeds.
6. Cap sampled candidates and expose omitted counts when limits are reached.
7. Sort using explicit stable keys, never hash-map, filesystem, provider, or
   process iteration order.

Suggested internal sort order:

1. parent file rank from file hotspot results;
2. source endpoint path;
3. source endpoint kind;
4. source endpoint name or empty string;
5. source endpoint range start and end;
6. relation kind;
7. direction;
8. target endpoint path or unresolved label;
9. target endpoint kind;
10. target endpoint name or empty string;
11. target endpoint range start and end;
12. provider name;
13. evidence basis;
14. deterministic candidate key.

If a future public output samples relation evidence, the sample order and
omitted counts must use the same deterministic keys.

## Attachment to existing surfaces

Future relation evidence should attach to existing public surfaces only after a
separate runtime feature approves the output contract. The attachment model
should remain additive.

- File hotspots remain ranking truth. Relation summaries can explain adjacent
  evidence for retained files, but must not alter file score.
- Current symbol evidence remains current-only. Relation evidence can connect a
  current symbol to other endpoints with caveats, but must not imply historical
  lineage.
- Historical symbol evidence remains attached to retained file candidates.
  Relation evidence can point at historical-only or deleted observations, but
  must preserve their status.
- Report-level symbols remain display identities. Relations can link to them
  only with confidence and caveats from the underlying observations.
- If no relation provider succeeds, existing file, symbol, and historical symbol
  outputs stay useful and honest.

## Performance bounds and stop conditions

A future implementation should be useful without cache and should bound relation
work by retained hotspot candidates.

Suggested first bounds:

- candidate files: retained file results or inspect scope, default cap 100;
- candidate symbols: current plus historical endpoints, default cap 1,000;
- relation candidates emitted by providers: default cap 5,000;
- sampled relations per file or symbol: default cap 10;
- per-file source bytes: default cap 1 MiB before relation parsing;
- provider runtime: bounded timeout selected by the implementation feature;
- provider failure budget: stop relation parsing after a bounded count and keep
  existing hotspot evidence;
- co-change adjacency: use existing bounded file co-change data or a small
  candidate-limited query, not a whole-repository graph by default.

Stop relation analysis and attach caveats when:

- a language has no provider;
- a provider is unavailable, fails, times out, or returns stale input;
- source is binary, oversized, generated by policy, filtered, or missing;
- shallow or partial history prevents needed local evidence;
- macro-heavy, dynamic, or cross-language constructs exceed provider support;
- candidate, symbol, edge, time, or memory limits are reached.

Cache may later improve performance, but it must remain an optimization. Product
truth must be reproducible from local Git, provider inputs, and deterministic
aggregation without requiring a persistent cache.

## Approach comparison

| Approach | Decision | Rationale |
| --- | --- | --- |
| Tree-sitter local syntax references | Select for the first runtime successor. | Existing providers already use local syntax extraction, and a narrow syntax-only relation proof can stay deterministic, local-first, and bounded. It must preserve unresolved targets where syntax cannot prove a target. |
| LSP references | Defer. | LSP can improve target resolution for some languages, but global services, workspace state, indexing, and tool availability make it too broad for the first relation slice. |
| Ctags-like indexing | Defer. | Broad local symbol indexes may be useful, but they add a second discovery surface and still need caveated target matching. |
| Dependency or package data | Defer. | Package metadata can explain import/include edges, but it does not cover symbol-level references and often needs language-specific policy. |
| Co-change adjacency | Keep as a separate relation kind. | Co-change is already aligned with local Git evidence, but it is historical adjacency only and must not masquerade as dependency truth. |
| Hybrid provider approach | Defer as the long-term shape. | Multiple providers can improve coverage later, but the first slice should prove the shared relation contract with one bounded provider family. |
| Whole-repository relation graph | Reject for the first implementation. | It expands runtime cost, output scope, and interpretation risk before the evidence contract is proven. |

## Selected first runtime successor

The next implementation feature should be an internal, non-public relation proof
for one local syntax provider family. It should not add CLI flags or public
report fields.

Recommended scope:

1. Reuse retained ranked file candidates and optional current symbol evidence as
   the candidate set.
2. Add an internal relation provider seam that can parse current source bytes for
   one existing tree-sitter-backed provider family.
3. Emit syntactic `contains`, `reference`, `call`, `import_include`,
   `unresolved`, and `unknown` candidates where the selected language can do so
   cheaply.
4. Aggregate candidates through shared provider-neutral code with deterministic
   sorting, confidence, caveats, and limits.
5. Keep output test-only or inspect-internal until a later feature approves a
   public report contract.
6. Prove fixtures for resolved syntax relation, unresolved target, nested
   contains relation, import/include relation, unsupported language, provider
   failure, cap reached, and deterministic ordering.
7. Run a real-repository smoke on this repository and, when available, one
   privacy-safe `sibling-local-repo` label. Commit only command shapes,
   pass/fail status, bounded counts, caveat counts, elapsed time, and categorical
   observations.

Likely files for that future slice include `src/provider.zig`, provider
selection/extraction code, a new internal relation aggregation module, fixtures
or synthetic test repos, and report-internal tests. Public CLI/report docs should
change only in the later output feature.

Escalate during that successor if the design requires global LSP services,
network access, checkout of historical commits, mandatory cache, public output,
scoring changes, or semantic certainty claims.

## Validation checklist for this spike

This architecture document is ready for review when it proves that:

- the feature is documentation-only and this file is the only product artefact;
- relation evidence is optional investigation context, not product truth or
  scoring input;
- relation endpoints cover file hotspots, current symbols, historical symbols,
  report-level symbols, unresolved targets, and external local strings;
- relation kinds distinguish syntax references, calls, imports/includes,
  contains/nesting, co-change adjacency, unknown, and unresolved evidence;
- provider input and output stay provider-neutral, local-first, caveated, and
  deterministic;
- freshness, failure, confidence, caveats, limits, aggregation, and sorting are
  explicit;
- co-change remains historical adjacency, not semantic dependency truth;
- examples are project-relative or synthetic and privacy-safe; and
- the selected runtime successor is narrow, local-only, internal first, and does
  not change public output in this feature.
