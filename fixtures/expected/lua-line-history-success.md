# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.4
- Head commit: 5fcc64c39359f84831609a0cbcffaa114938f572
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

- Requested path: src/example.lua
- Matched path: src/example.lua
- Rank in scoped evidence universe: 1

## Symbols

Symbols are opt-in current working-tree enrichment only. They do not change score, file order, lineage, confidence, or file-level Git evidence.

- Provider: tree\-sitter\-lua
- State: current-only
- Freshness: fresh
- Failure: ok
- Confidence: high
- Total symbols: 10
- Shown symbols: 10
- Omitted symbols: 0
- Human display limit: 25 (default)
- Sort basis: shown first by current-line Git evidence summary
- Caveats:
  - current working\-tree enrichment only; file\-level Git evidence remains product truth
  - supported subset: module roots, function declarations, colon methods, module\-level local/global function assignments, module\-level locals, stable table constructor fields, and stable dot table function assignments
  - range convention: one\-based inclusive lines; qualified Lua names and method names are bare terminal identifiers
  - provider order: module symbol first, then deterministic source order by symbol node start byte
  - module names are repo\-relative .lua paths; package, require, runtime module resolution, metatables, LSP, and symbol history are out of scope
  - dynamic table keys, dependency graphs, runtime execution, generated\-source policy, scoring, and semantic moves are out of scope

| Name | Kind | Lines | Confidence | Current-line Git evidence |
| --- | --- | ---: | --- | --- |
| src/example.lua | module | 1-33 | high | Current-line Git evidence: commits=1; lines=33; unblamable=1; freshness=partial; failure=ok; confidence=medium; caveats=current\-line Git evidence has unblamable lines in this symbol range |
| exports | variable | 4-15 | high | Current-line Git evidence: commits=1; lines=12; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| local\_worker | function | 17-22 | high | Current-line Git evidence: commits=1; lines=6; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| Nested | variable | 10-14 | high | Current-line Git evidence: commits=1; lines=5; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| build | function | 6-9 | high | Current-line Git evidence: commits=1; lines=4; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| make\_thing | function | 24-26 | high | Current-line Git evidence: commits=1; lines=3; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| run | method | 28-30 | high | Current-line Git evidence: commits=1; lines=3; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| CONFIG | other | 2-2 | high | Current-line Git evidence: commits=1; lines=1; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| answer | variable | 5-5 | high | Current-line Git evidence: commits=1; lines=1; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| mutable\_value | variable | 3-3 | high | Current-line Git evidence: commits=1; lines=1; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |

## Caveats

- Git rename lineage is conservative: local \-\-find\-renames=40% file edges only; copies, splits, merges, and symbol moves are not tracked

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/example.lua | 53.3 | 2 | 32 | medium | yes | 5fcc64c39359 |

## Evidence

### 1. src/example.lua

- Score breakdown: total=53.280, frequency=20.000, churn=1.280, recency=20.000, cochange=12.000
- Changes: 2
- Additions: 32
- Deletions: 0
- Current size: 554
- Confidence: medium
- Last commit: 5fcc64c39359
- Lineage: Git rename edges only; no copy, split, merge, symbol, or semantic move tracking
  - Accepted aliases: src/old\-example.lua
- Top co-changes:
  - src/missing.lua (count=2)
  - src/dynamic\_table\_assignment.lua (count=1)
  - src/embedded\_dsl.lua (count=1)
  - src/empty.lua (count=1)
  - src/generated.lua (count=1)
- Evidence commits:
  - commit=5fcc64c39359 timestamp=1777680000 additions=0 deletions=0
  - commit=980cd9bb1af4 timestamp=1777593600 additions=32 deletions=0
- Row caveats:
  - None
