# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.4
- Head commit: a32bd2e6bd6c31e842c28acb6aeef73fdb18850a
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
- Shown symbols: 2
- Omitted symbols: 6
- Human display limit: 2 (explicit)
- Sort basis: shown first by provider order
- Caveats:
  - current working\-tree enrichment only; file\-level Git evidence remains product truth
  - supported subset: package clauses, top\-level functions, methods, struct/interface type specs, and top\-level const/var names
  - range convention: one\-based inclusive lines from the enclosing Go declaration
  - build tags, generated\-file markers, package loading, and cgo are not evaluated
  - method names are bare identifiers; receiver\-qualified naming is out of scope

| Name | Kind | Lines | Confidence |
| --- | --- | ---: | --- |
| Alpha | other | 5-8 | high |
| Beta | other | 5-8 | high |

## Caveats

- Git rename lineage is conservative: local \-\-find\-renames=40% file edges only; copies, splits, merges, and symbol moves are not tracked

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/example.go | 53.1 | 2 | 27 | medium | yes | a32bd2e6bd6c |

## Evidence

### 1. src/example.go

- Score breakdown: total=53.080, frequency=20.000, churn=1.080, recency=20.000, cochange=12.000
- Changes: 2
- Additions: 26
- Deletions: 1
- Current size: 287
- Confidence: medium
- Last commit: a32bd2e6bd6c
- Lineage: Git rename edges only; no copy, split, merge, symbol, or semantic move tracking
  - Accepted aliases: src/old\-example.go
- Top co-changes:
  - src/missing.go (count=2)
  - src/broken.go (count=1)
  - src/caveated.go (count=1)
  - src/empty.go (count=1)
  - src/large.go (count=1)
- Evidence commits:
  - commit=a32bd2e6bd6c timestamp=1777680000 additions=3 deletions=1
  - commit=8358403565ea timestamp=1777593600 additions=23 deletions=0
- Row caveats:
  - None
