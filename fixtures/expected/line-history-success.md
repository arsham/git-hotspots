# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.4
- Head commit: f60b6c476b88d8c0092d41831e433a942015557d
- Range: None
- Commit count: 3
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

- Requested path: src/current.zig
- Matched path: src/current.zig
- Rank in scoped evidence universe: 1

## Symbols

Symbols are opt-in current working-tree enrichment only. They do not change score, file order, lineage, confidence, or file-level Git evidence.

- Provider: tree\-sitter\-zig
- State: current-only
- Freshness: fresh
- Failure: ok
- Confidence: high
- Total symbols: 3
- Shown symbols: 3
- Omitted symbols: 0
- Human display limit: 25 (default)
- Sort basis: shown first by current-line Git evidence summary
- Caveats:
  - current working\-tree enrichment only; file\-level Git evidence remains product truth
  - supported subset: named Zig function declarations only
  - range convention: one\-based inclusive lines

| Name | Kind | Lines | Confidence | Current-line Git evidence |
| --- | --- | ---: | --- | --- |
| beta | function | 7-9 | high | Current-line Git evidence: commits=1; lines=3; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| alpha | function | 2-5 | high | Current-line Git evidence: commits=1; lines=4; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| gamma | function | 11-11 | high | Current-line Git evidence: commits=1; lines=1; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |

## Caveats

- None

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/current.zig | 60.6 | 3 | 15 | high | no | f60b6c476b88 |

## Evidence

### 1. src/current.zig

- Score breakdown: total=60.600, frequency=30.000, churn=0.600, recency=20.000, cochange=10.000
- Changes: 3
- Additions: 13
- Deletions: 2
- Current size: 164
- Confidence: high
- Last commit: f60b6c476b88
- Lineage: None
- Top co-changes:
  - src/broken.zig (count=1)
  - src/empty.zig (count=1)
  - src/link.zig (count=1)
  - src/readme.txt (count=1)
  - src/target.zig (count=1)
- Evidence commits:
  - commit=f60b6c476b88 timestamp=1780444800 additions=4 deletions=1
  - commit=924ba585871e timestamp=1780358400 additions=4 deletions=1
  - commit=539f44c2b0a8 timestamp=1780272000 additions=5 deletions=0
- Row caveats:
  - None
