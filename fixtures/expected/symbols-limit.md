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
| alpha | function | 5-5 | high |

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
