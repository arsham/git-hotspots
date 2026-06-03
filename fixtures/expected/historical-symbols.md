# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.4
- Head commit: 1f4a60fcd8e7b98f2c8cb68d75d25c25b0c402d9
- Range: None
- Commit count: 3
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

- Files with supported provider reports: 4
- Total symbols: 3
- Shown symbols: 2
- Omitted symbols: 1
- Human display limit: 2 (explicit)
- Unsupported ranked files: 1
- Unavailable ranked files: 1
- Provider failures: 1
- Provider skipped: 0
- Sort basis: parent file rank, then current-line Git evidence/provider order

| File rank | File | Score | Provider | Failure | Name | Kind | Lines | Confidence | Current-line Git evidence |
| ---: | --- | ---: | --- | --- | --- | --- | ---: | --- | --- |
| 1 | src/example.zig | 46.8 | tree\-sitter\-zig | ok | alpha | function | 15-15 | high | - |
| 1 | src/example.zig | 46.8 | tree\-sitter\-zig | ok | zebra | function | 5-7 | high | - |

## Historical symbols

Historical symbols are opt-in true historical hunk attribution for retained ranked-file candidates only. They do not change score, file order, lineage, confidence, or file-level Git evidence.

- Candidate paths: 5
- Retained candidate paths: 5
- Aggregate records: 8
- Shown records: 2
- Omitted records: 6
- Human display limit: 2 (explicit)
- Aggregate record bound: 128
- Aggregate record bound exceeded: false
- Fallback records: 4
- Fallback count: 7
- Provider states: ok=4, unavailable=0, unsupported=1, failed=1, timed_out=0, skipped=2
- Sort basis: historical aggregate sort key: evidence path, symbol kind/name/status/range; attached parent rank is reported but does not change file ranking
- Caveats:
  - historical symbols are opt\-in true historical hunk attribution over retained ranked\-file candidates only
  - provider\-supported languages only; unsupported, binary, large, missing, provider\-failed, merge, and unattributed evidence may fall back to file\-level records
  - no semantic symbol lineage, rename/move/split/merge proof, reference/use analysis, maintainer attribution, bug prediction, scoring replacement, or developer metrics
  - local Git history only; no checkout, network access, auto\-fetch, telemetry, remote enrichment, cache truth, or runtime LLM judgement

| File rank | File | Evidence path | Score | Name | Kind | Revision lines | Status | Changes | Added pressure | Deleted pressure | Latest timestamp | Provider state | Confidence | Fallbacks | Sample commits | Caveats |
| ---: | --- | --- | ---: | --- | --- | ---: | --- | ---: | ---: | ---: | ---: | --- | --- | ---: | --- | --- |
| 5 | src/broken.zig | src/broken.zig | 30.0 | file fallback | - | - | unknown | 1 | 1 | 0 | 1777680000 | failed | low | 1 | 1f4a60fcd8e7b98f2c8cb68d75d25c25b0c402d9 | provider could not parse revision\-local source; fallback retained |
| 1 | src/example.zig | src/example.zig | 46.8 | file fallback | - | - | unknown | 4 | 2 | 2 | 1777680000 | skipped | low | 4 | f614c7a5973c9616d0474b0433ef6a0f1eaa6355 | unattributed hunk fallback; no nearest\-symbol guessing |

## Caveats

- None

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/example.zig | 46.8 | 2 | 21 | medium | no | f614c7a5973c |
| 2 | src/link.zig | 35.0 | 1 | 1 | low | no | f900be851f50 |
| 3 | src/readme.txt | 35.0 | 1 | 1 | low | no | f900be851f50 |
| 4 | src/target.zig | 35.0 | 1 | 1 | low | no | f900be851f50 |
| 5 | src/broken.zig | 30.0 | 1 | 1 | low | no | 1f4a60fcd8e7 |

## Evidence

### 1. src/example.zig

- Score breakdown: total=46.840, frequency=20.000, churn=0.840, recency=20.000, cochange=6.000
- Changes: 2
- Additions: 18
- Deletions: 3
- Current size: 102
- Confidence: medium
- Last commit: f614c7a5973c
- Lineage: None
- Top co-changes:
  - src/link.zig (count=1)
  - src/readme.txt (count=1)
  - src/target.zig (count=1)
- Evidence commits:
  - commit=f614c7a5973c timestamp=1777680000 additions=5 deletions=3
  - commit=f900be851f50 timestamp=1777593600 additions=13 deletions=0
- Row caveats:
  - None

### 2. src/link.zig

- Score breakdown: total=35.040, frequency=10.000, churn=0.040, recency=19.000, cochange=6.000
- Changes: 1
- Additions: 1
- Deletions: 0
- Current size: 24
- Confidence: low
- Last commit: f900be851f50
- Lineage: None
- Top co-changes:
  - src/example.zig (count=1)
  - src/readme.txt (count=1)
  - src/target.zig (count=1)
- Evidence commits:
  - commit=f900be851f50 timestamp=1777593600 additions=1 deletions=0
- Row caveats:
  - None

### 3. src/readme.txt

- Score breakdown: total=35.040, frequency=10.000, churn=0.040, recency=19.000, cochange=6.000
- Changes: 1
- Additions: 1
- Deletions: 0
- Current size: 8
- Confidence: low
- Last commit: f900be851f50
- Lineage: None
- Top co-changes:
  - src/example.zig (count=1)
  - src/link.zig (count=1)
  - src/target.zig (count=1)
- Evidence commits:
  - commit=f900be851f50 timestamp=1777593600 additions=1 deletions=0
- Row caveats:
  - None

### 4. src/target.zig

- Score breakdown: total=35.040, frequency=10.000, churn=0.040, recency=19.000, cochange=6.000
- Changes: 1
- Additions: 1
- Deletions: 0
- Current size: 24
- Confidence: low
- Last commit: f900be851f50
- Lineage: None
- Top co-changes:
  - src/example.zig (count=1)
  - src/link.zig (count=1)
  - src/readme.txt (count=1)
- Evidence commits:
  - commit=f900be851f50 timestamp=1777593600 additions=1 deletions=0
- Row caveats:
  - None

### 5. src/broken.zig

- Score breakdown: total=30.040, frequency=10.000, churn=0.040, recency=20.000, cochange=0.000
- Changes: 1
- Additions: 1
- Deletions: 0
- Current size: 23
- Confidence: low
- Last commit: 1f4a60fcd8e7
- Lineage: None
- Top co-changes:
  - None
- Evidence commits:
  - commit=1f4a60fcd8e7 timestamp=1777680000 additions=1 deletions=0
- Row caveats:
  - None
