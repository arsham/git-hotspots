# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.3
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
- Shown symbols: 6
- Omitted symbols: 4
- Human display limit: 6 (explicit)
- Sort basis: shown first by provider order
- Caveats:
  - current working\-tree enrichment only; file\-level Git evidence remains product truth
  - supported subset: module roots, function declarations, colon methods, module\-level local/global function assignments, module\-level locals, stable table constructor fields, and stable dot table function assignments
  - range convention: one\-based inclusive lines; qualified Lua names and method names are bare terminal identifiers
  - provider order: module symbol first, then deterministic source order by symbol node start byte
  - module names are repo\-relative .lua paths; package, require, runtime module resolution, metatables, LSP, and symbol history are out of scope
  - dynamic table keys, dependency graphs, runtime execution, generated\-source policy, scoring, and semantic moves are out of scope

| Name | Kind | Lines | Confidence |
| --- | --- | ---: | --- |
| src/example.lua | module | 1-33 | high |
| CONFIG | other | 2-2 | high |
| mutable\_value | variable | 3-3 | high |
| exports | variable | 4-15 | high |
| answer | variable | 5-5 | high |
| build | function | 6-9 | high |

## Symbol relationships

Symbol relationships are opt-in bounded local provider evidence for retained ranked-file candidates only. They do not change score, file order, lineage, confidence, or file-level Git evidence, and they are not call-graph truth, dependency proof, ownership, developer metrics, or bug prediction.

- Candidate files: 1
- Retained candidate files: 1
- Current symbol candidates: 10
- Provider reports: 1
- Relation records: 16
- Shown records: 6
- Omitted records: 10
- Human display limit: 6 (explicit)
- Relation record bound: 1024
- Relation record bound exceeded: false
- Bound-omitted records: 0
- Sort basis: source endpoint, target endpoint, kind, direction, provider, evidence basis
- Caveats:
  - candidate relation evidence only; file\-level Git evidence remains product truth
  - bounded Lua syntax evidence: contains, require\-like imports, direct calls, table/member reference\-like syntax, unresolved identifiers, and unknown relation\-like syntax
  - unresolved and external\-string endpoints are caveated; no module loader, package.path, metatable, dynamic table, runtime mutation, generated\-source, or semantic dependency identity is fabricated
  - symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction
- Relationship evidence summary: emitted=16 kinds=contains:9,reference:1,call:2,unknown:2,unresolved:2 unknown=2 unresolved=2 unresolved_targets=5 display_limit_omitted=10

| Kind | Direction | Source endpoint | Target endpoint | Unresolved target | Provider | Provider input | Freshness | Failure | Confidence | Evidence basis | Caveat refs |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| contains | source_to_target | file:src/example.lua | symbol:src/example.lua:CONFIG:other | false | tree\-sitter\-lua\-relations | working\-tree:src/example.lua | fresh | ok | medium | lua module\-level symbol containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/example.lua | symbol:src/example.lua:Nested:variable | false | tree\-sitter\-lua\-relations | working\-tree:src/example.lua | fresh | ok | medium | lua module\-level symbol containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/example.lua | symbol:src/example.lua:answer:variable | false | tree\-sitter\-lua\-relations | working\-tree:src/example.lua | fresh | ok | medium | lua module\-level symbol containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/example.lua | symbol:src/example.lua:build:function | false | tree\-sitter\-lua\-relations | working\-tree:src/example.lua | fresh | ok | medium | lua module\-level symbol containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/example.lua | symbol:src/example.lua:exports:variable | false | tree\-sitter\-lua\-relations | working\-tree:src/example.lua | fresh | ok | medium | lua module\-level symbol containment | C1, C2, C3, C4 |
| reference | source_to_target | file:src/example.lua | symbol:src/example.lua:exports:variable | false | tree\-sitter\-lua\-relations | working\-tree:src/example.lua | fresh | ok | medium | lua identifier reference syntax | C1, C2, C3, C4 |

- Row caveat references:
  - C1: candidate relation evidence only; file\-level Git evidence remains product truth
  - C2: bounded Lua syntax evidence: contains, require\-like imports, direct calls, table/member reference\-like syntax, unresolved identifiers, and unknown relation\-like syntax
  - C3: unresolved and external\-string endpoints are caveated; no module loader, package.path, metatable, dynamic table, runtime mutation, generated\-source, or semantic dependency identity is fabricated
  - C4: symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction

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
