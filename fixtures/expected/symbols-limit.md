# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.4
- Head commit: 1f4a60fcd8e7b98f2c8cb68d75d25c25b0c402d9
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
- Shown symbols: 1
- Omitted symbols: 1
- Human display limit: 1 (explicit)
- Sort basis: shown first by provider order
- Caveats:
  - current working\-tree enrichment only; file\-level Git evidence remains product truth
  - supported subset: named Zig function declarations only
  - range convention: one\-based inclusive lines

| Name | Kind | Lines | Confidence |
| --- | --- | ---: | --- |
| alpha | function | 15-15 | high |

## Caveats

- None

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/example.zig | 46.8 | 2 | 21 | medium | no | f614c7a5973c |

## Evidence

### 1. src/example.zig

- Score breakdown: total=46.840, frequency=20.000, churn=0.840, recency=20.000, cochange=6.000
- Changes: 2
- Additions: 18
- Deletions: 3
- Current size: 102
- Confidence: medium
- Last commit: f614c7a5973c
- Lineage: None
- Top co-changes:
  - src/link.zig (count=1)
  - src/readme.txt (count=1)
  - src/target.zig (count=1)
- Evidence commits:
  - commit=f614c7a5973c timestamp=1777680000 additions=5 deletions=3
  - commit=f900be851f50 timestamp=1777593600 additions=13 deletions=0
- Row caveats:
  - None
