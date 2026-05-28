# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.1
- Head commit: 6bbf8c5b5985239e44df5d5828d4433b01373538
- Range: None
- Commit count: 1
- Shallow history: false
- Partial history: false
- Dirty worktree: false
- Auto fetch: false
- Paths: repo-relative

## Scope

- Selected scope: project
- Filters active: true
- Include prefixes: None
- Exclude prefixes: .flow/, .zig\-cache/, zig\-out/, target/, node\_modules/, dist/, build/, coverage/
- Outside include path count: 0
- Outside include change count: 0
- Excluded path count: 0
- Excluded change count: 0

## Inspect

- Requested path: src/relations.rs
- Matched path: src/relations.rs
- Rank in scoped evidence universe: 1

## Symbols

Symbols are opt-in current working-tree enrichment only. They do not change score, file order, lineage, confidence, or file-level Git evidence.

- Provider: tree\-sitter\-rust
- State: current-only
- Freshness: fresh
- Failure: ok
- Confidence: high
- Total symbols: 9
- Shown symbols: 6
- Omitted symbols: 3
- Human display limit: 6 (explicit)
- Sort basis: shown first by provider order
- Caveats:
  - current working\-tree enrichment only; file\-level Git evidence remains product truth
  - supported subset: source\-file module rows, inline or external modules, freestanding functions, impl and trait methods, structs, tuple structs, unit structs, enums, traits, consts, statics, and enum variants
  - range convention: one\-based inclusive lines; Rust names are bare syntactic identifiers
  - provider order: module symbol first, then deterministic source order by symbol node start byte
  - module names are repo\-relative .rs paths; external mod declarations use bare syntactic names only
  - Cargo, package/workspace/crate graphs, module resolution, macro expansion, cfg evaluation, type checking, trait resolution, LSP, dependency graphs, generated\-source policy, scoring, cache, network, telemetry, and upload are out of scope
  - current\-only
  - macro definitions and invocations are counted only; macro expansion output is not inferred as symbol evidence

| Name | Kind | Lines | Confidence |
| --- | --- | ---: | --- |
| src/relations.rs | module | 1-25 | high |
| LIMIT | other | 3-3 | high |
| external | module | 5-5 | high |
| inner | module | 7-16 | high |
| Record | type | 8-8 | high |
| new | method | 11-11 | high |

## Symbol relationships

Symbol relationships are opt-in bounded local provider evidence for retained ranked-file candidates only. They do not change score, file order, lineage, confidence, or file-level Git evidence, and they are not call-graph truth, dependency proof, ownership, developer metrics, or bug prediction.

- Candidate files: 1
- Retained candidate files: 1
- Current symbol candidates: 9
- Provider reports: 1
- Relation records: 23
- Shown records: 6
- Omitted records: 17
- Human display limit: 6 (explicit)
- Relation record bound: 1024
- Relation record bound exceeded: false
- Bound-omitted records: 0
- Sort basis: source endpoint, target endpoint, kind, direction, provider, evidence basis
- Caveats:
  - candidate relation evidence only; file\-level Git evidence remains product truth
  - bounded Rust syntax proof: contains, local direct identifier references, direct calls, external mod/use includes, unresolved identifiers, and ambiguous path/member syntax
  - unresolved and external\-string endpoints are caveated; no local target mapping is fabricated
  - symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction

| Kind | Direction | Source endpoint | Target endpoint | Unresolved target | Provider | Provider input | Freshness | Failure | Confidence | Evidence basis | Caveats |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| import_include | source_to_target | file:src/relations.rs | external:crate::tools::worker | false | tree\-sitter\-rust\-relations | working\-tree:src/relations.rs | fresh | ok | medium | rust use declaration syntax | candidate relation evidence only; file\-level Git evidence remains product truth; bounded Rust syntax proof: contains, local direct identifier references, direct calls, external mod/use includes, unresolved identifiers, and ambiguous path/member syntax; unresolved and external\-string endpoints are caveated; no local target mapping is fabricated; symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction; mod/use target is an external string; Cargo, crate, module, and file\-system resolution are out of scope |
| contains | source_to_target | file:src/relations.rs | symbol:src/relations.rs:LIMIT:other | false | tree\-sitter\-rust\-relations | working\-tree:src/relations.rs | fresh | ok | medium | rust definition containment | candidate relation evidence only; file\-level Git evidence remains product truth; bounded Rust syntax proof: contains, local direct identifier references, direct calls, external mod/use includes, unresolved identifiers, and ambiguous path/member syntax; unresolved and external\-string endpoints are caveated; no local target mapping is fabricated; symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction |
| contains | source_to_target | file:src/relations.rs | symbol:src/relations.rs:external:module | false | tree\-sitter\-rust\-relations | working\-tree:src/relations.rs | fresh | ok | medium | rust definition containment | candidate relation evidence only; file\-level Git evidence remains product truth; bounded Rust syntax proof: contains, local direct identifier references, direct calls, external mod/use includes, unresolved identifiers, and ambiguous path/member syntax; unresolved and external\-string endpoints are caveated; no local target mapping is fabricated; symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction |
| contains | source_to_target | file:src/relations.rs | symbol:src/relations.rs:inner:module | false | tree\-sitter\-rust\-relations | working\-tree:src/relations.rs | fresh | ok | medium | rust definition containment | candidate relation evidence only; file\-level Git evidence remains product truth; bounded Rust syntax proof: contains, local direct identifier references, direct calls, external mod/use includes, unresolved identifiers, and ambiguous path/member syntax; unresolved and external\-string endpoints are caveated; no local target mapping is fabricated; symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction |
| contains | source_to_target | file:src/relations.rs | symbol:src/relations.rs:top\_function:function | false | tree\-sitter\-rust\-relations | working\-tree:src/relations.rs | fresh | ok | medium | rust definition containment | candidate relation evidence only; file\-level Git evidence remains product truth; bounded Rust syntax proof: contains, local direct identifier references, direct calls, external mod/use includes, unresolved identifiers, and ambiguous path/member syntax; unresolved and external\-string endpoints are caveated; no local target mapping is fabricated; symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction |
| unresolved | source_to_target | file:src/relations.rs | unresolved:Generated | true | tree\-sitter\-rust\-relations | working\-tree:src/relations.rs | fresh | ok | low | rust identifier reference syntax | candidate relation evidence only; file\-level Git evidence remains product truth; bounded Rust syntax proof: contains, local direct identifier references, direct calls, external mod/use includes, unresolved identifiers, and ambiguous path/member syntax; unresolved and external\-string endpoints are caveated; no local target mapping is fabricated; symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction; target is unresolved by this bounded Rust syntax proof |

## Caveats

- None

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/relations.rs | 31.0 | 1 | 24 | low | no | 6bbf8c5b5985 |

## Evidence

### 1. src/relations.rs

- Score breakdown: total=30.960, frequency=10.000, churn=0.960, recency=20.000, cochange=0.000
- Changes: 1
- Additions: 24
- Deletions: 0
- Current size: 405
- Confidence: low
- Last commit: 6bbf8c5b5985
- Lineage: None
- Top co-changes:
  - None
- Evidence commits:
  - commit=6bbf8c5b5985 timestamp=1777766400 additions=24 deletions=0
- Row caveats:
  - None
