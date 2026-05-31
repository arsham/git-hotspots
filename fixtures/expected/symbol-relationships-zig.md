# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.3
- Head commit: 5e8784e66dbf456b6e994af7e5eac03329ea47cd
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

- Requested path: src/example.zig
- Matched path: src/example.zig
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
| alpha | function | 5-5 | high |
| zebra | function | 1-3 | high |

## Symbol relationships

Symbol relationships are opt-in bounded local provider evidence for retained ranked-file candidates only. They do not change score, file order, lineage, confidence, or file-level Git evidence, and they are not call-graph truth, dependency proof, ownership, developer metrics, or bug prediction.

- Candidate files: 1
- Retained candidate files: 1
- Current symbol candidates: 2
- Provider reports: 1
- Relation records: 2
- Shown records: 2
- Omitted records: 0
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

| Kind | Direction | Source endpoint | Target endpoint | Unresolved target | Provider | Provider input | Freshness | Failure | Confidence | Evidence basis | Caveat refs |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| contains | source_to_target | file:src/example.zig | symbol:src/example.zig:alpha:function | false | tree\-sitter\-zig\-relations | working\-tree:src/example.zig | fresh | ok | medium | zig definition containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/example.zig | symbol:src/example.zig:zebra:function | false | tree\-sitter\-zig\-relations | working\-tree:src/example.zig | fresh | ok | medium | zig definition containment | C1, C2, C3, C4 |

- Row caveat references:
  - C1: candidate relation evidence only; file\-level Git evidence remains product truth
  - C2: bounded Zig syntax proof: contains, @import strings, direct identifier calls, local identifier references, unresolved identifiers, and ambiguous member or comptime syntax
  - C3: unresolved and external\-string endpoints are caveated; no package, build graph, namespace, type, method, comptime, or generated\-code truth is fabricated
  - C4: symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction

## Caveats

- None

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/example.zig | 46.3 | 2 | 7 | medium | no | 5e8784e66dbf |

## Evidence

### 1. src/example.zig

- Score breakdown: total=46.280, frequency=20.000, churn=0.280, recency=20.000, cochange=6.000
- Changes: 2
- Additions: 6
- Deletions: 1
- Current size: 56
- Confidence: medium
- Last commit: 5e8784e66dbf
- Lineage: None
- Top co-changes:
  - src/link.zig (count=1)
  - src/readme.txt (count=1)
  - src/target.zig (count=1)
- Evidence commits:
  - commit=5e8784e66dbf timestamp=1777680000 additions=3 deletions=1
  - commit=68512f487cd1 timestamp=1777593600 additions=3 deletions=0
- Row caveats:
  - None
