# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.3
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
- Shown symbols: 6
- Omitted symbols: 7
- Human display limit: 6 (explicit)
- Sort basis: shown first by provider order
- Caveats:
  - current working\-tree enrichment only; file\-level Git evidence remains product truth
  - supported subset: module roots, class declarations, function declarations, direct class methods, module\-level simple bindings, and deterministic named CommonJS exports
  - range convention: one\-based inclusive lines; method names are bare property identifiers
  - provider order: module symbol first, then deterministic source order by symbol node start byte
  - module names are repo\-relative .js/.mjs/.cjs/.jsx paths; package, workspace, Node, module\-resolution, TypeScript, TSX, LSP, and symbol history are out of scope
  - dynamic property names, imports, dependency graphs, generated\-source policy, scoring, and semantic moves are out of scope

| Name | Kind | Lines | Confidence |
| --- | --- | ---: | --- |
| src/example.mjs | module | 1-34 | high |
| EXPORTED\_CONSTANT | other | 2-2 | high |
| mutableValue | variable | 3-3 | high |
| legacyValue | variable | 4-4 | high |
| topFunction | function | 6-11 | high |
| innerFunction | function | 7-9 | high |

## Symbol relationships

Symbol relationships are opt-in bounded local provider evidence for retained ranked-file candidates only. They do not change score, file order, lineage, confidence, or file-level Git evidence, and they are not call-graph truth, dependency proof, ownership, developer metrics, or bug prediction.

- Candidate files: 1
- Retained candidate files: 1
- Current symbol candidates: 13
- Provider reports: 1
- Relation records: 17
- Shown records: 6
- Omitted records: 11
- Human display limit: 6 (explicit)
- Relation record bound: 1024
- Relation record bound exceeded: false
- Bound-omitted records: 0
- Sort basis: source endpoint, target endpoint, kind, direction, provider, evidence basis
- Caveats:
  - candidate relation evidence only; file\-level Git evidence remains product truth
  - bounded JavaScript syntax proof: contains, local direct identifier references, direct calls, imports/includes, unresolved identifiers, and member/computed syntax caveats
  - unresolved and external\-string endpoints are caveated; no local target mapping is fabricated
  - symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction

| Kind | Direction | Source endpoint | Target endpoint | Unresolved target | Provider | Provider input | Freshness | Failure | Confidence | Evidence basis | Caveat refs |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| import_include | source_to_target | file:src/example.mjs | external:<tag\>\[safe\]\(link\) | false | tree\-sitter\-javascript\-relations | working\-tree:src/example.mjs | fresh | ok | medium | javascript import/include syntax | C1, C2, C3, C4, C5 |
| contains | source_to_target | file:src/example.mjs | symbol:src/example.mjs:EXPORTED\_CONSTANT:other | false | tree\-sitter\-javascript\-relations | working\-tree:src/example.mjs | fresh | ok | medium | javascript definition containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/example.mjs | symbol:src/example.mjs:ExportedClass:class | false | tree\-sitter\-javascript\-relations | working\-tree:src/example.mjs | fresh | ok | medium | javascript definition containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/example.mjs | symbol:src/example.mjs:LocalClass:class | false | tree\-sitter\-javascript\-relations | working\-tree:src/example.mjs | fresh | ok | medium | javascript definition containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/example.mjs | symbol:src/example.mjs:café:function | false | tree\-sitter\-javascript\-relations | working\-tree:src/example.mjs | fresh | ok | medium | javascript definition containment | C1, C2, C3, C4 |
| contains | source_to_target | file:src/example.mjs | symbol:src/example.mjs:ignoredObject:variable | false | tree\-sitter\-javascript\-relations | working\-tree:src/example.mjs | fresh | ok | medium | javascript definition containment | C1, C2, C3, C4 |

- Row caveat references:
  - C1: candidate relation evidence only; file\-level Git evidence remains product truth
  - C2: bounded JavaScript syntax proof: contains, local direct identifier references, direct calls, imports/includes, unresolved identifiers, and member/computed syntax caveats
  - C3: unresolved and external\-string endpoints are caveated; no local target mapping is fabricated
  - C4: symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction
  - C5: import/include target is an external string; Node, package, workspace, bundler, and local module resolution are out of scope

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
