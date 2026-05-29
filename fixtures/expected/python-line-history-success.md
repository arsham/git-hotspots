# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.3
- Head commit: cfc3a2ced6a5cdb7e9ca4d67902844a29dd39128
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

- Requested path: src/example.py
- Matched path: src/example.py
- Rank in scoped evidence universe: 1

## Symbols

Symbols are opt-in current working-tree enrichment only. They do not change score, file order, lineage, confidence, or file-level Git evidence.

- Provider: tree\-sitter\-python
- State: current-only
- Freshness: fresh
- Failure: ok
- Confidence: high
- Total symbols: 11
- Shown symbols: 11
- Omitted symbols: 0
- Human display limit: 25 (default)
- Sort basis: shown first by current-line Git evidence summary
- Caveats:
  - current working\-tree enrichment only; file\-level Git evidence remains product truth
  - supported subset: module roots, class and function definitions, direct class methods, nested definitions, and module\-level simple assignments
  - range convention: one\-based inclusive lines; decorated definitions include decorators
  - provider order: module symbol first, then deterministic source order by symbol node start byte
  - module names are repo\-relative .py paths; qualified Python names, imports, package discovery, virtualenvs, notebooks, and LSP analysis are out of scope
  - dynamic assignments, tuple/list destructuring, dependency graphs, generated\-source policy, scoring, and symbol or function moves are out of scope

| Name | Kind | Lines | Confidence | Current-line Git evidence |
| --- | --- | ---: | --- | --- |
| src/example.py | module | 1-35 | high | Current-line Git evidence: commits=1; lines=35; unblamable=1; freshness=partial; failure=ok; confidence=medium; caveats=current\-line Git evidence has unblamable lines in this symbol range |
| top\_function | function | 10-20 | high | Current-line Git evidence: commits=1; lines=11; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| Outer | class | 22-31 | high | Current-line Git evidence: commits=1; lines=10; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| method | method | 27-31 | high | Current-line Git evidence: commits=1; lines=5; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| InnerClass | class | 17-18 | high | Current-line Git evidence: commits=1; lines=2; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| Nested | class | 24-25 | high | Current-line Git evidence: commits=1; lines=2; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| café | function | 33-34 | high | Current-line Git evidence: commits=1; lines=2; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| inner\_function | function | 14-15 | high | Current-line Git evidence: commits=1; lines=2; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| method\_inner | function | 29-30 | high | Current-line Git evidence: commits=1; lines=2; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| CONSTANT | other | 5-5 | high | Current-line Git evidence: commits=1; lines=1; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |
| mutable\_value | variable | 6-6 | high | Current-line Git evidence: commits=1; lines=1; unblamable=0; freshness=fresh; failure=ok; confidence=high; caveats=none |

## Caveats

- Git rename lineage is conservative: local \-\-find\-renames=40% file edges only; copies, splits, merges, and symbol moves are not tracked

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/example.py | 53.4 | 2 | 34 | medium | yes | cfc3a2ced6a5 |

## Evidence

### 1. src/example.py

- Score breakdown: total=53.360, frequency=20.000, churn=1.360, recency=20.000, cochange=12.000
- Changes: 2
- Additions: 34
- Deletions: 0
- Current size: 565
- Confidence: medium
- Last commit: cfc3a2ced6a5
- Lineage: Git rename edges only; no copy, split, merge, symbol, or semantic move tracking
  - Accepted aliases: src/old\_example.py
- Top co-changes:
  - src/missing.py (count=2)
  - src/empty.py (count=1)
  - src/generated.py (count=1)
  - src/invalid\_partial.py (count=1)
  - src/large.py (count=1)
- Evidence commits:
  - commit=cfc3a2ced6a5 timestamp=1777680000 additions=0 deletions=0
  - commit=36220374db4b timestamp=1777593600 additions=34 deletions=0
- Row caveats:
  - None
