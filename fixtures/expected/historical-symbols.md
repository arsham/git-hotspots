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

## Project symbols

Symbols are opt-in current working-tree enrichment for retained ranked file hotspots only. They do not change score, file order, lineage, confidence, or file-level Git evidence.

- Files with supported provider reports: 3
- Total symbols: 3
- Shown symbols: 2
- Omitted symbols: 1
- Human display limit: 2 (explicit)
- Unsupported ranked files: 1
- Unavailable ranked files: 1
- Provider failures: 0
- Provider skipped: 0
- Sort basis: parent file rank, then current-line Git evidence/provider order

| File rank | File | Score | Provider | Failure | Name | Kind | Lines | Confidence | Current-line Git evidence |
| ---: | --- | ---: | --- | --- | --- | --- | ---: | --- | --- |
| 1 | src/example.zig | 46.3 | tree\-sitter\-zig | ok | alpha | function | 5-5 | high | - |
| 1 | src/example.zig | 46.3 | tree\-sitter\-zig | ok | zebra | function | 1-3 | high | - |

## Historical symbols

Historical symbols are opt-in true historical hunk attribution for retained ranked-file candidates only. They do not change score, file order, lineage, confidence, or file-level Git evidence.

- Candidate paths: 4
- Retained candidate paths: 4
- Aggregate records: 6
- Shown records: 2
- Omitted records: 4
- Human display limit: 2 (explicit)
- Aggregate record bound: 128
- Aggregate record bound exceeded: false
- Fallback records: 2
- Fallback count: 2
- Provider states: ok=4, unavailable=0, unsupported=1, failed=0, timed_out=0, skipped=1
- Sort basis: historical aggregate sort key: evidence path, symbol kind/name/status/range; attached parent rank is reported but does not change file ranking
- Caveats:
  - historical symbols are opt\-in true historical hunk attribution over retained ranked\-file candidates only
  - provider\-supported languages only; unsupported, binary, large, missing, provider\-failed, merge, and unattributed evidence may fall back to file\-level records
  - no semantic symbol lineage, rename/move/split/merge proof, reference/use analysis, maintainer attribution, bug prediction, scoring replacement, or developer metrics
  - local Git history only; no checkout, network access, auto\-fetch, telemetry, remote enrichment, cache truth, or runtime LLM judgement

| File rank | File | Evidence path | Score | Name | Kind | Revision lines | Status | Changes | Added pressure | Deleted pressure | Latest timestamp | Provider state | Confidence | Fallbacks | Sample commits | Caveats |
| ---: | --- | --- | ---: | --- | --- | ---: | --- | ---: | ---: | ---: | ---: | --- | --- | ---: | --- | --- |
| 1 | src/example.zig | src/example.zig | 46.3 | alpha | function | 3-3 | historical | 1 | 3 | 0 | 1777593600 | ok | high | 0 | 68512f487cd1a83c99b3fee9b07fb05e3ab24fe8 | current working\-tree enrichment only; file\-level Git evidence remains product truth; supported subset: named Zig function declarations only; range convention: one\-based inclusive lines |
| 1 | src/example.zig | src/example.zig | 46.3 | zebra | function | 1-1 | historical | 2 | 3 | 1 | 1777680000 | ok | high | 0 | 5e8784e66dbf456b6e994af7e5eac03329ea47cd, 68512f487cd1a83c99b3fee9b07fb05e3ab24fe8 | current working\-tree enrichment only; file\-level Git evidence remains product truth; supported subset: named Zig function declarations only; range convention: one\-based inclusive lines |

## Caveats

- None

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/example.zig | 46.3 | 2 | 7 | medium | no | 5e8784e66dbf |
| 2 | src/link.zig | 35.0 | 1 | 1 | low | no | 68512f487cd1 |
| 3 | src/readme.txt | 35.0 | 1 | 1 | low | no | 68512f487cd1 |
| 4 | src/target.zig | 35.0 | 1 | 1 | low | no | 68512f487cd1 |

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

### 2. src/link.zig

- Score breakdown: total=35.040, frequency=10.000, churn=0.040, recency=19.000, cochange=6.000
- Changes: 1
- Additions: 1
- Deletions: 0
- Current size: 24
- Confidence: low
- Last commit: 68512f487cd1
- Lineage: None
- Top co-changes:
  - src/example.zig (count=1)
  - src/readme.txt (count=1)
  - src/target.zig (count=1)
- Evidence commits:
  - commit=68512f487cd1 timestamp=1777593600 additions=1 deletions=0
- Row caveats:
  - None

### 3. src/readme.txt

- Score breakdown: total=35.040, frequency=10.000, churn=0.040, recency=19.000, cochange=6.000
- Changes: 1
- Additions: 1
- Deletions: 0
- Current size: 8
- Confidence: low
- Last commit: 68512f487cd1
- Lineage: None
- Top co-changes:
  - src/example.zig (count=1)
  - src/link.zig (count=1)
  - src/target.zig (count=1)
- Evidence commits:
  - commit=68512f487cd1 timestamp=1777593600 additions=1 deletions=0
- Row caveats:
  - None

### 4. src/target.zig

- Score breakdown: total=35.040, frequency=10.000, churn=0.040, recency=19.000, cochange=6.000
- Changes: 1
- Additions: 1
- Deletions: 0
- Current size: 24
- Confidence: low
- Last commit: 68512f487cd1
- Lineage: None
- Top co-changes:
  - src/example.zig (count=1)
  - src/link.zig (count=1)
  - src/readme.txt (count=1)
- Evidence commits:
  - commit=68512f487cd1 timestamp=1777593600 additions=1 deletions=0
- Row caveats:
  - None
