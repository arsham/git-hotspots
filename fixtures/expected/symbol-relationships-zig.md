# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.4
- Head commit: 6cdad5590919f0e38b3fce63422129e63f8cdc91
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

- Requested path: src/relations.zig
- Matched path: src/relations.zig
- Rank in scoped evidence universe: 1

## Symbols

Symbols are opt-in current working-tree enrichment only. They do not change score, file order, lineage, confidence, or file-level Git evidence.

- Provider: tree\-sitter\-zig
- State: current-only
- Freshness: fresh
- Failure: ok
- Confidence: high
- Total symbols: 2
- Shown symbols: 2
- Omitted symbols: 0
- Human display limit: 6 (explicit)
- Sort basis: shown first by provider order
- Caveats:
  - current working\-tree enrichment only; file\-level Git evidence remains product truth
  - supported subset: named Zig function declarations only
  - range convention: one\-based inclusive lines

| Name | Kind | Lines | Confidence |
| --- | --- | ---: | --- |
| localHelper | function | 13-13 | high |
| main | function | 4-11 | high |

## Symbol relationships

Symbol relationships are opt-in bounded local provider evidence for retained ranked-file candidates only. They do not change score, file order, lineage, confidence, or file-level Git evidence, and they are not call-graph truth, dependency proof, ownership, developer metrics, or bug prediction.

- Candidate files: 1
- Retained candidate files: 1
- Current symbol candidates: 2
- Provider reports: 1
- Relation records: 14
- Shown records: 6
- Records hidden by human display limit: 8
- Human display limit: 6 (explicit)
- Relation record bound: 1024
- Relation record bound exceeded: false
- Bound-omitted records: 0
- Sort basis: source endpoint, target endpoint, kind, direction, provider, evidence basis
- Caveats:
  - candidate relation evidence only; file\-level Git evidence remains product truth
  - bounded Zig syntax proof: contains, @import strings, direct identifier calls, local identifier references, unresolved identifiers, and ambiguous member or comptime syntax
  - unresolved and external\-string endpoints are caveated; no package, build graph, namespace, type, method, comptime, or generated\-code truth is fabricated
  - symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction
- Relationship evidence summary: emitted=14 kinds=contains:5,reference:1,call:2,import_include:2,unknown:3,unresolved:1 unknown=3 unresolved=1 unresolved_targets=5 human_display_sample_omitted=8

| Kind | Direction | Source endpoint | Target endpoint | Unresolved target | Provider | Provider input | Freshness | Failure | Confidence | Evidence basis | Caveat refs |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| contains | source_to_target | file:src/relations.zig | symbol:src/relations.zig:helper:other | false | tree\-sitter\-zig\-relations | working\-tree:src/relations.zig | fresh | ok | medium | zig definition containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/relations.zig | symbol:src/relations.zig:localHelper:function | false | tree\-sitter\-zig\-relations | working\-tree:src/relations.zig | fresh | ok | medium | zig definition containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/relations.zig | symbol:src/relations.zig:main:function | false | tree\-sitter\-zig\-relations | working\-tree:src/relations.zig | fresh | ok | medium | zig definition containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/relations.zig | symbol:src/relations.zig:std:other | false | tree\-sitter\-zig\-relations | working\-tree:src/relations.zig | fresh | ok | medium | zig definition containment | C1, C2, C3, C4 |
| reference | source_to_target | symbol:src/relations.zig:\_:other | symbol:src/relations.zig:localHelper:function | false | tree\-sitter\-zig\-relations | working\-tree:src/relations.zig | fresh | ok | medium | zig identifier reference syntax | C1, C2, C3, C4 |
| unknown | none | symbol:src/relations.zig:\_:other | unresolved:@TypeOf | true | tree\-sitter\-zig\-relations | working\-tree:src/relations.zig | fresh | ok | low | zig builtin function syntax without comptime semantic proof | C1, C2, C3, C4, C5 |

- Row caveat references:
  - C1: candidate relation evidence only; file\-level Git evidence remains product truth
  - C2: bounded Zig syntax proof: contains, @import strings, direct identifier calls, local identifier references, unresolved identifiers, and ambiguous member or comptime syntax
  - C3: unresolved and external\-string endpoints are caveated; no package, build graph, namespace, type, method, comptime, or generated\-code truth is fabricated
  - C4: symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction
  - C5: relation\-like Zig syntax is present but cannot be classified safely by this proof

## Caveats

- None

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/relations.zig | 32.5 | 1 | 13 | low | no | 6cdad5590919 |

## Evidence

### 1. src/relations.zig

- Score breakdown: total=32.520, frequency=10.000, churn=0.520, recency=20.000, cochange=2.000
- Changes: 1
- Additions: 13
- Deletions: 0
- Current size: 249
- Confidence: low
- Last commit: 6cdad5590919
- Lineage: None
- Top co-changes:
  - src/helper.zig (count=1)
- Evidence commits:
  - commit=6cdad5590919 timestamp=1777766400 additions=13 deletions=0
- Row caveats:
  - None
