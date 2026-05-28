# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.1
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
- Shown symbols: 4
- Omitted symbols: 7
- Human display limit: 4 (explicit)
- Sort basis: shown first by provider order
- Caveats:
  - current working\-tree enrichment only; file\-level Git evidence remains product truth
  - supported subset: module roots, class and function definitions, direct class methods, nested definitions, and module\-level simple assignments
  - range convention: one\-based inclusive lines; decorated definitions include decorators
  - provider order: module symbol first, then deterministic source order by symbol node start byte
  - module names are repo\-relative .py paths; qualified Python names, imports, package discovery, virtualenvs, notebooks, and LSP analysis are out of scope
  - dynamic assignments, tuple/list destructuring, dependency graphs, generated\-source policy, scoring, and symbol or function moves are out of scope

| Name | Kind | Lines | Confidence |
| --- | --- | ---: | --- |
| src/example.py | module | 1-35 | high |
| CONSTANT | other | 5-5 | high |
| mutable\_value | variable | 6-6 | high |
| top\_function | function | 10-20 | high |

## Symbol relationships

Symbol relationships are opt-in bounded local provider evidence for retained ranked-file candidates only. They do not change score, file order, lineage, confidence, or file-level Git evidence, and they are not call-graph truth, dependency proof, ownership, developer metrics, or bug prediction.

- Candidate files: 1
- Retained candidate files: 1
- Current symbol candidates: 11
- Provider reports: 1
- Relation records: 20
- Shown records: 4
- Omitted records: 16
- Human display limit: 4 (explicit)
- Relation record bound: 1024
- Relation record bound exceeded: false
- Bound-omitted records: 0
- Sort basis: source endpoint, target endpoint, kind, direction, provider, evidence basis
- Caveats:
  - candidate relation evidence only; file\-level Git evidence remains product truth
  - bounded Python syntax proof: contains, local direct identifier references, direct calls, imports, unresolved identifiers, and ambiguous attribute syntax
  - unresolved and external\-string endpoints are caveated; no local target mapping is fabricated
  - symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction

| Kind | Direction | Source endpoint | Target endpoint | Unresolved target | Provider | Provider input | Freshness | Failure | Confidence | Evidence basis | Caveats |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| contains | source_to_target | file:src/example.py | symbol:src/example.py:CONSTANT:other | false | tree\-sitter\-python\-relations | working\-tree:src/example.py | fresh | ok | medium | python definition containment | candidate relation evidence only; file\-level Git evidence remains product truth; bounded Python syntax proof: contains, local direct identifier references, direct calls, imports, unresolved identifiers, and ambiguous attribute syntax; unresolved and external\-string endpoints are caveated; no local target mapping is fabricated; symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction |
| contains | source_to_target | file:src/example.py | symbol:src/example.py:Outer:class | false | tree\-sitter\-python\-relations | working\-tree:src/example.py | fresh | ok | medium | python definition containment | candidate relation evidence only; file\-level Git evidence remains product truth; bounded Python syntax proof: contains, local direct identifier references, direct calls, imports, unresolved identifiers, and ambiguous attribute syntax; unresolved and external\-string endpoints are caveated; no local target mapping is fabricated; symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction |
| contains | source_to_target | file:src/example.py | symbol:src/example.py:café:function | false | tree\-sitter\-python\-relations | working\-tree:src/example.py | fresh | ok | medium | python definition containment | candidate relation evidence only; file\-level Git evidence remains product truth; bounded Python syntax proof: contains, local direct identifier references, direct calls, imports, unresolved identifiers, and ambiguous attribute syntax; unresolved and external\-string endpoints are caveated; no local target mapping is fabricated; symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction |
| contains | source_to_target | file:src/example.py | symbol:src/example.py:mutable\_value:variable | false | tree\-sitter\-python\-relations | working\-tree:src/example.py | fresh | ok | medium | python definition containment | candidate relation evidence only; file\-level Git evidence remains product truth; bounded Python syntax proof: contains, local direct identifier references, direct calls, imports, unresolved identifiers, and ambiguous attribute syntax; unresolved and external\-string endpoints are caveated; no local target mapping is fabricated; symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction |

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
