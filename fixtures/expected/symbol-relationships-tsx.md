# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.4
- Head commit: 0ad0fc9324566103938191cf69e66f8b13cd54c3
- Range: None
- Commit count: 2
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

- Requested path: src/component.tsx
- Matched path: src/component.tsx
- Rank in scoped evidence universe: 3

## Symbols

Symbols are opt-in current working-tree enrichment only. They do not change score, file order, lineage, confidence, or file-level Git evidence.

- Provider: tree\-sitter\-tsx
- State: current-only
- Freshness: fresh
- Failure: ok
- Confidence: high
- Total symbols: 8
- Shown symbols: 6
- Omitted symbols: 2
- Human display limit: 6 (explicit)
- Sort basis: shown first by provider order
- Caveats:
  - current working\-tree enrichment only; file\-level Git evidence remains product truth
  - supported subset: module roots, class declarations, function declarations, direct class methods, module\-level simple bindings, interfaces, type aliases, enums, namespaces, and deterministic TSX component\-shaped bindings
  - range convention: one\-based inclusive lines; method names are bare property identifiers
  - provider order: module symbol first, then deterministic source order by symbol node start byte
  - module names are repo\-relative .ts/.mts/.cts/.tsx paths; package, workspace, Node, module\-resolution, tsconfig, type checking, LSP, and symbol line history are out of scope
  - imports, exports, dependency graphs, generated\-source policy, scoring, semantic moves, custom queries, cache, network, telemetry, and upload are out of scope
  - current\-only
  - TSX JSX syntax and JSX components are query\-covered structurally without React, DOM, package, or type analysis

| Name | Kind | Lines | Confidence |
| --- | --- | ---: | --- |
| src/component.tsx | module | 1-19 | high |
| Props | type | 1-3 | high |
| Panel | function | 5-7 | high |
| InlineWidget | function | 9-9 | high |
| ClassWidget | class | 11-15 | high |
| render | method | 12-14 | high |

## Symbol relationships

Symbol relationships are opt-in bounded local provider evidence for retained ranked-file candidates only. They do not change score, file order, lineage, confidence, or file-level Git evidence, and they are not call-graph truth, dependency proof, ownership, developer metrics, or bug prediction.

- Candidate files: 1
- Retained candidate files: 1
- Current symbol candidates: 8
- Provider reports: 1
- Relation records: 17
- Shown records: 6
- Records hidden by human display limit: 11
- Human display limit: 6 (explicit)
- Relation record bound: 1024
- Relation record bound exceeded: false
- Bound-omitted records: 0
- Sort basis: source endpoint, target endpoint, kind, direction, provider, evidence basis
- Caveats:
  - candidate relation evidence only; file\-level Git evidence remains product truth
  - bounded TypeScript/TSX syntax proof: contains, local direct identifier references, direct calls, imports/includes, unresolved identifiers, type\-only syntax caveats, and member/computed/JSX syntax caveats
  - unresolved and external\-string endpoints are caveated; no local target mapping is fabricated
  - symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction
- Relationship evidence summary: emitted=17 kinds=contains:7,reference:1,unknown:7,unresolved:2 unknown=7 unresolved=2 unresolved_targets=9 human_display_sample_omitted=11

| Kind | Direction | Source endpoint | Target endpoint | Unresolved target | Provider | Provider input | Freshness | Failure | Confidence | Evidence basis | Caveat refs |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| contains | source_to_target | file:src/component.tsx | symbol:src/component.tsx:ClassWidget:class | false | tree\-sitter\-tsx\-relations | working\-tree:src/component.tsx | fresh | ok | medium | tsx definition containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/component.tsx | symbol:src/component.tsx:DisplayMode:type | false | tree\-sitter\-tsx\-relations | working\-tree:src/component.tsx | fresh | ok | medium | tsx definition containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/component.tsx | symbol:src/component.tsx:InlineWidget:function | false | tree\-sitter\-tsx\-relations | working\-tree:src/component.tsx | fresh | ok | medium | tsx definition containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/component.tsx | symbol:src/component.tsx:Panel:function | false | tree\-sitter\-tsx\-relations | working\-tree:src/component.tsx | fresh | ok | medium | tsx definition containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/component.tsx | symbol:src/component.tsx:PanelProps:type | false | tree\-sitter\-tsx\-relations | working\-tree:src/component.tsx | fresh | ok | medium | tsx definition containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/component.tsx | symbol:src/component.tsx:Props:type | false | tree\-sitter\-tsx\-relations | working\-tree:src/component.tsx | fresh | ok | medium | tsx definition containment | C1, C2, C3, C4 |

- Row caveat references:
  - C1: candidate relation evidence only; file\-level Git evidence remains product truth
  - C2: bounded TypeScript/TSX syntax proof: contains, local direct identifier references, direct calls, imports/includes, unresolved identifiers, type\-only syntax caveats, and member/computed/JSX syntax caveats
  - C3: unresolved and external\-string endpoints are caveated; no local target mapping is fabricated
  - C4: symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction

## Caveats

- Git rename lineage is conservative: local \-\-find\-renames=40% file edges only; copies, splits, merges, and symbol moves are not tracked

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/component.tsx | 39.7 | 1 | 18 | low | no | fac98f944612 |

## Evidence

### 1. src/component.tsx

- Score breakdown: total=39.720, frequency=10.000, churn=0.720, recency=19.000, cochange=10.000
- Changes: 1
- Additions: 18
- Deletions: 0
- Current size: 291
- Confidence: low
- Last commit: fac98f944612
- Lineage: None
- Top co-changes:
  - src/common\_case.cts (count=1)
  - src/empty.ts (count=1)
  - src/example.ts (count=1)
  - src/generated.min.ts (count=1)
  - src/invalid\_partial.ts (count=1)
- Evidence commits:
  - commit=fac98f944612 timestamp=1777593600 additions=18 deletions=0
- Row caveats:
  - None
