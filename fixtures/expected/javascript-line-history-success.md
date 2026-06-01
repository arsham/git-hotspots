# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.4
- Head commit: 377029018206c23c5b7d9f96dad672c65e7075ac
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

- Requested path: src/example.mjs
- Matched path: src/example.mjs
- Rank in scoped evidence universe: 1

## Symbols

Symbols are opt-in current working-tree enrichment only. They do not change score, file order, lineage, confidence, or file-level Git evidence.

- Provider: tree\-sitter\-javascript
- State: current-only
- Freshness: fresh
- Failure: ok
- Confidence: high
- Total symbols: 13
- Shown symbols: 13
- Omitted symbols: 0
- Human display limit: 25 (default)
- Sort basis: shown first by current-line Git evidence summary
- Caveats:
  - current working\-tree enrichment only; file\-level Git evidence remains product truth
  - supported subset: module roots, class declarations, function declarations, direct class methods, module\-level simple bindings, and deterministic named CommonJS exports
  - range convention: one\-based inclusive lines; method names are bare property identifiers
  - provider order: module symbol first, then deterministic source order by symbol node start byte
  - module names are repo\-relative .js/.mjs/.cjs/.jsx paths; package, workspace, Node, module\-resolution, TypeScript, TSX, LSP, and symbol history are out of scope
  - dynamic property names, imports, dependency graphs, generated\-source policy, scoring, and semantic moves are out of scope

| Name | Kind | Lines | Confidence | Current-line Git evidence |
| --- | --- | ---: | --- | --- |
| src/example.mjs | module | 1-34 | high | Current-line Git evidence: commits=1; lines=34; unblamable=1; freshness=partial; failure=ok; confidence=medium; caveats=current\-line Git evidence has unblamable lines in this symbol range |
| LocalClass | class | 13-20 | high | Current-line Git evidence: commits=1; lines=8; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| methodOne | method | 14-19 | high | Current-line Git evidence: commits=1; lines=6; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| topFunction | function | 6-11 | high | Current-line Git evidence: commits=1; lines=6; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| ExportedClass | class | 22-26 | high | Current-line Git evidence: commits=1; lines=5; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| café | function | 28-30 | high | Current-line Git evidence: commits=1; lines=3; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| innerFunction | function | 7-9 | high | Current-line Git evidence: commits=1; lines=3; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| methodInner | function | 15-17 | high | Current-line Git evidence: commits=1; lines=3; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| render | method | 23-25 | high | Current-line Git evidence: commits=1; lines=3; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| EXPORTED\_CONSTANT | other | 2-2 | high | Current-line Git evidence: commits=1; lines=1; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| ignoredObject | variable | 32-32 | high | Current-line Git evidence: commits=1; lines=1; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| legacyValue | variable | 4-4 | high | Current-line Git evidence: commits=1; lines=1; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| mutableValue | variable | 3-3 | high | Current-line Git evidence: commits=1; lines=1; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |

## Caveats

- Git rename lineage is conservative: local \-\-find\-renames=40% file edges only; copies, splits, merges, and symbol moves are not tracked

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/example.mjs | 53.3 | 2 | 33 | medium | yes | 377029018206 |

## Evidence

### 1. src/example.mjs

- Score breakdown: total=53.320, frequency=20.000, churn=1.320, recency=20.000, cochange=12.000
- Changes: 2
- Additions: 33
- Deletions: 0
- Current size: 554
- Confidence: medium
- Last commit: 377029018206
- Lineage: Git rename edges only; no copy, split, merge, symbol, or semantic move tracking
  - Accepted aliases: src/old\-example.mjs
- Top co-changes:
  - src/missing.js (count=2)
  - src/anonymous\_exports.js (count=1)
  - src/commonjs.cjs (count=1)
  - src/component.jsx (count=1)
  - src/empty.js (count=1)
- Evidence commits:
  - commit=377029018206 timestamp=1777680000 additions=0 deletions=0
  - commit=26fe46508bcc timestamp=1777593600 additions=33 deletions=0
- Row caveats:
  - None
