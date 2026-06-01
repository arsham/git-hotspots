# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.4
- Head commit: 0cde56197cf0d64f62a3abd892e4d7db097057c6
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

- Requested path: src/example.rs
- Matched path: src/example.rs
- Rank in scoped evidence universe: 1

## Symbols

Symbols are opt-in current working-tree enrichment only. They do not change score, file order, lineage, confidence, or file-level Git evidence.

- Provider: tree\-sitter\-rust
- State: current-only
- Freshness: fresh
- Failure: ok
- Confidence: high
- Total symbols: 21
- Shown symbols: 21
- Omitted symbols: 0
- Human display limit: 25 (default)
- Sort basis: shown first by provider order
- Caveats:
  - current working\-tree enrichment only; file\-level Git evidence remains product truth
  - supported subset: source\-file module rows, inline or external modules, freestanding functions, impl and trait methods, structs, tuple structs, unit structs, enums, traits, consts, statics, and enum variants
  - range convention: one\-based inclusive lines; Rust names are bare syntactic identifiers
  - provider order: module symbol first, then deterministic source order by symbol node start byte
  - module names are repo\-relative .rs paths; external mod declarations use bare syntactic names only
  - Cargo, package/workspace/crate graphs, module resolution, macro expansion, cfg evaluation, type checking, trait resolution, LSP, dependency graphs, generated\-source policy, scoring, cache, network, telemetry, and upload are out of scope
  - current\-only

| Name | Kind | Lines | Confidence |
| --- | --- | ---: | --- |
| src/example.rs | module | 1-46 | high |
| LIMIT | other | 3-3 | high |
| NAME | other | 4-4 | high |
| nested | module | 6-37 | high |
| Unit | type | 7-7 | high |
| Tuple | type | 8-8 | high |
| Record | type | 9-11 | high |
| Choice | type | 13-17 | high |
| First | other | 14-14 | high |
| Second | other | 15-15 | high |
| Third | other | 16-16 | high |
| Render | type | 19-24 | high |
| render | method | 20-20 | high |
| label | method | 21-23 | high |
| new | method | 27-29 | high |
| value | method | 31-33 | high |
| helper | function | 36-36 | high |
| top\_function | function | 39-39 | high |
| external | module | 41-41 | high |
| r\#async | function | 43-43 | high |
| MARKDOWN\_NAME | other | 45-45 | high |

## Caveats

- Git rename lineage is conservative: local \-\-find\-renames=40% file edges only; copies, splits, merges, and symbol moves are not tracked

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/example.rs | 53.8 | 2 | 45 | medium | yes | 0cde56197cf0 |

## Evidence

### 1. src/example.rs

- Score breakdown: total=53.800, frequency=20.000, churn=1.800, recency=20.000, cochange=12.000
- Changes: 2
- Additions: 45
- Deletions: 0
- Current size: 789
- Confidence: medium
- Last commit: 0cde56197cf0
- Lineage: Git rename edges only; no copy, split, merge, symbol, or semantic move tracking
  - Accepted aliases: src/old\-example.rs
- Top co-changes:
  - src/missing.rs (count=2)
  - src/empty.rs (count=1)
  - src/generated.rs (count=1)
  - src/invalid\_partial.rs (count=1)
  - src/large.rs (count=1)
- Evidence commits:
  - commit=0cde56197cf0 timestamp=1777680000 additions=0 deletions=0
  - commit=9d69e7c1fce7 timestamp=1777593600 additions=45 deletions=0
- Row caveats:
  - None
