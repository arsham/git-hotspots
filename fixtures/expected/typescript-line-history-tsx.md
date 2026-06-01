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
- Shown symbols: 8
- Omitted symbols: 0
- Human display limit: 25 (default)
- Sort basis: shown first by current-line Git evidence summary
- Caveats:
  - current working\-tree enrichment only; file\-level Git evidence remains product truth
  - supported subset: module roots, class declarations, function declarations, direct class methods, module\-level simple bindings, interfaces, type aliases, enums, namespaces, and deterministic TSX component\-shaped bindings
  - range convention: one\-based inclusive lines; method names are bare property identifiers
  - provider order: module symbol first, then deterministic source order by symbol node start byte
  - module names are repo\-relative .ts/.mts/.cts/.tsx paths; package, workspace, Node, module\-resolution, tsconfig, type checking, LSP, and true symbol history are out of scope
  - imports, exports, dependency graphs, generated\-source policy, scoring, semantic moves, custom queries, cache, network, telemetry, and upload are out of scope
  - current\-only
  - TSX JSX syntax and JSX components are query\-covered structurally without React, DOM, package, or type analysis

| Name | Kind | Lines | Confidence | Current-line Git evidence |
| --- | --- | ---: | --- | --- |
| src/component.tsx | module | 1-19 | high | Current-line Git evidence: commits=1; lines=19; unblamable=1; freshness=partial; failure=ok; confidence=medium; caveats=current\-line Git evidence has unblamable lines in this symbol range |
| ClassWidget | class | 11-15 | high | Current-line Git evidence: commits=1; lines=5; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| Panel | function | 5-7 | high | Current-line Git evidence: commits=1; lines=3; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| Props | type | 1-3 | high | Current-line Git evidence: commits=1; lines=3; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| render | method | 12-14 | high | Current-line Git evidence: commits=1; lines=3; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| DisplayMode | type | 18-18 | high | Current-line Git evidence: commits=1; lines=1; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| InlineWidget | function | 9-9 | high | Current-line Git evidence: commits=1; lines=1; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| PanelProps | type | 17-17 | high | Current-line Git evidence: commits=1; lines=1; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |

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
