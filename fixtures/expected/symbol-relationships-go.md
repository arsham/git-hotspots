# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.3
- Head commit: 9efa83ac497f0c5f670110aadf8354388b3ccb9a
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

- Requested path: src/example.go
- Matched path: src/example.go
- Rank in scoped evidence universe: 1

## Symbols

Symbols are opt-in current working-tree enrichment only. They do not change score, file order, lineage, confidence, or file-level Git evidence.

- Provider: tree\-sitter\-go
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
  - supported subset: package clauses, top\-level functions, methods, struct/interface type specs, and top\-level const/var names
  - range convention: one\-based inclusive lines from the enclosing Go declaration
  - build tags, generated\-file markers, package loading, and cgo are not evaluated
  - method names are bare identifiers; receiver\-qualified naming is out of scope

| Name | Kind | Lines | Confidence |
| --- | --- | ---: | --- |
| Alpha | other | 3-6 | high |
| Beta | other | 3-6 | high |
| Gamma | variable | 8-8 | high |
| Method | method | 17-17 | high |
| Runner | type | 15-15 | high |
| Service | type | 14-14 | high |

## Symbol relationships

Symbol relationships are opt-in bounded local provider evidence for retained ranked-file candidates only. They do not change score, file order, lineage, confidence, or file-level Git evidence, and they are not call-graph truth, dependency proof, ownership, developer metrics, or bug prediction.

- Candidate files: 1
- Retained candidate files: 1
- Current symbol candidates: 8
- Provider reports: 1
- Relation records: 8
- Shown records: 6
- Records hidden by human display limit: 2
- Human display limit: 6 (explicit)
- Relation record bound: 1024
- Relation record bound exceeded: false
- Bound-omitted records: 0
- Sort basis: source endpoint, target endpoint, kind, direction, provider, evidence basis
- Caveats:
  - candidate relation evidence only; file\-level Git evidence remains product truth
  - bounded Go syntax evidence: contains, import includes, direct identifier calls, selector\-like syntax, unresolved identifiers, and unknown relation\-like syntax
  - unresolved and external\-string endpoints are caveated; no package, module, type, interface, method\-set, build\-tag, generated\-source, cgo, vendored, or semantic dependency identity is fabricated
  - symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction
- Relationship evidence summary: emitted=8 kinds=contains:8 human_display_sample_omitted=2

| Kind | Direction | Source endpoint | Target endpoint | Unresolved target | Provider | Provider input | Freshness | Failure | Confidence | Evidence basis | Caveat refs |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| contains | source_to_target | file:src/example.go | symbol:src/example.go:Alpha:other | false | tree\-sitter\-go\-relations | working\-tree:src/example.go | fresh | ok | medium | go top\-level declaration containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/example.go | symbol:src/example.go:Beta:other | false | tree\-sitter\-go\-relations | working\-tree:src/example.go | fresh | ok | medium | go top\-level declaration containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/example.go | symbol:src/example.go:Gamma:variable | false | tree\-sitter\-go\-relations | working\-tree:src/example.go | fresh | ok | medium | go top\-level declaration containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/example.go | symbol:src/example.go:Method:method | false | tree\-sitter\-go\-relations | working\-tree:src/example.go | fresh | ok | medium | go top\-level declaration containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/example.go | symbol:src/example.go:Runner:type | false | tree\-sitter\-go\-relations | working\-tree:src/example.go | fresh | ok | medium | go top\-level declaration containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/example.go | symbol:src/example.go:Service:type | false | tree\-sitter\-go\-relations | working\-tree:src/example.go | fresh | ok | medium | go top\-level declaration containment | C1, C2, C3, C4 |

- Row caveat references:
  - C1: candidate relation evidence only; file\-level Git evidence remains product truth
  - C2: bounded Go syntax evidence: contains, import includes, direct identifier calls, selector\-like syntax, unresolved identifiers, and unknown relation\-like syntax
  - C3: unresolved and external\-string endpoints are caveated; no package, module, type, interface, method\-set, build\-tag, generated\-source, cgo, vendored, or semantic dependency identity is fabricated
  - C4: symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction

## Caveats

- Git rename lineage is conservative: local \-\-find\-renames=40% file edges only; copies, splits, merges, and symbol moves are not tracked

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/example.go | 52.8 | 2 | 19 | medium | yes | 9efa83ac497f |

## Evidence

### 1. src/example.go

- Score breakdown: total=52.760, frequency=20.000, churn=0.760, recency=20.000, cochange=12.000
- Changes: 2
- Additions: 18
- Deletions: 1
- Current size: 182
- Confidence: medium
- Last commit: 9efa83ac497f
- Lineage: Git rename edges only; no copy, split, merge, symbol, or semantic move tracking
  - Accepted aliases: src/old\-example.go
- Top co-changes:
  - src/missing.go (count=2)
  - src/broken.go (count=1)
  - src/caveated.go (count=1)
  - src/empty.go (count=1)
  - src/large.go (count=1)
- Evidence commits:
  - commit=9efa83ac497f timestamp=1777680000 additions=3 deletions=1
  - commit=06dd28088837 timestamp=1777593600 additions=15 deletions=0
- Row caveats:
  - None
