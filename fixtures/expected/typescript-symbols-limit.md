# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.3
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

- Requested path: src/example.ts
- Matched path: src/example.ts
- Rank in scoped evidence universe: 1

## Symbols

Symbols are opt-in current working-tree enrichment only. They do not change score, file order, lineage, confidence, or file-level Git evidence.

- Provider: tree\-sitter\-typescript
- State: current-only
- Freshness: fresh
- Failure: ok
- Confidence: high
- Total symbols: 14
- Shown symbols: 4
- Omitted symbols: 10
- Human display limit: 4 (explicit)
- Sort basis: shown first by provider order
- Caveats:
  - current working\-tree enrichment only; file\-level Git evidence remains product truth
  - supported subset: module roots, class declarations, function declarations, direct class methods, module\-level simple bindings, interfaces, type aliases, enums, namespaces, and deterministic TSX component\-shaped bindings
  - range convention: one\-based inclusive lines; method names are bare property identifiers
  - provider order: module symbol first, then deterministic source order by symbol node start byte
  - module names are repo\-relative .ts/.mts/.cts/.tsx paths; package, workspace, Node, module\-resolution, tsconfig, type checking, LSP, and symbol line history are out of scope
  - imports, exports, dependency graphs, generated\-source policy, scoring, semantic moves, custom queries, cache, network, telemetry, and upload are out of scope
  - current\-only

| Name | Kind | Lines | Confidence |
| --- | --- | ---: | --- |
| src/example.ts | module | 1-31 | high |
| EXPORTED\_FLAG | other | 2-2 | high |
| mutableCount | variable | 3-3 | high |
| compute | function | 5-10 | high |

## Caveats

- Git rename lineage is conservative: local \-\-find\-renames=40% file edges only; copies, splits, merges, and symbol moves are not tracked

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/example.ts | 53.2 | 2 | 30 | medium | yes | 0ad0fc932456 |

## Evidence

### 1. src/example.ts

- Score breakdown: total=53.200, frequency=20.000, churn=1.200, recency=20.000, cochange=12.000
- Changes: 2
- Additions: 30
- Deletions: 0
- Current size: 579
- Confidence: medium
- Last commit: 0ad0fc932456
- Lineage: Git rename edges only; no copy, split, merge, symbol, or semantic move tracking
  - Accepted aliases: src/old\-example.ts
- Top co-changes:
  - src/missing.ts (count=2)
  - src/common\_case.cts (count=1)
  - src/component.tsx (count=1)
  - src/empty.ts (count=1)
  - src/generated.min.ts (count=1)
- Evidence commits:
  - commit=0ad0fc932456 timestamp=1777680000 additions=0 deletions=0
  - commit=fac98f944612 timestamp=1777593600 additions=30 deletions=0
- Row caveats:
  - None
