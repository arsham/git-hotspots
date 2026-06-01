# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.4
- Head commit: 158d6f63309fda6a5e7db0068bbbf28f265dc32f
- Range: None
- Commit count: 5
- Shallow history: false
- Partial history: false
- Dirty worktree: false
- Auto fetch: false
- Paths: repo-relative

## Scope

- Selected scope: all
- Filters active: true
- Include prefixes: None
- Exclude prefixes: .flow/, .zig\-cache/, zig\-out/, target/, node\_modules/, dist/, build/, coverage/
- Outside include path count: 0
- Outside include change count: 0
- Excluded path count: 13
- Excluded change count: 28

## Caveats

- Git rename lineage is conservative: local \-\-find\-renames=40% file edges only; copies, splits, merges, and symbol moves are not tracked
- some observed rename edges were outside active scope filters; lineage may be partial
- file candidate display limit exceeded; retained top 10 of 12 deterministically by score; use \-\-limit to widen local evidence

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/vendor\_adapter.zig | 70.1 | 3 | 3 | high | no | 158d6f63309f |
| 2 | src/app.txt | 64.2 | 3 | 6 | high | no | 158d6f63309f |
| 3 | docs/coverage.md | 57.1 | 2 | 2 | medium | no | 1806413f9ecf |
| 4 | src/buildtool.zig | 57.1 | 2 | 2 | medium | no | 1806413f9ecf |
| 5 | src/vendoradapter.zig | 57.1 | 2 | 2 | medium | no | 1806413f9ecf |
| 6 | vendor/lib.txt | 57.1 | 2 | 2 | medium | no | 1806413f9ecf |
| 7 | src/new.zig | 49.0 | 2 | 1 | medium | yes | a707ef7e560a |
| 8 | src/chain\-final.txt | 39.0 | 1 | 0 | low | partial | 1806413f9ecf |
| 9 | glob/\[literal\]\*.txt | 36.0 | 1 | 1 | low | no | b37980bad093 |
| 10 | src/chain\-start.txt | 36.0 | 1 | 1 | low | no | b37980bad093 |

## Evidence

### 1. src/vendor\_adapter.zig

- Score breakdown: total=70.120, frequency=30.000, churn=0.120, recency=20.000, cochange=20.000
- Changes: 3
- Additions: 3
- Deletions: 0
- Current size: 38
- Confidence: high
- Last commit: 158d6f63309f
- Lineage: None
- Top co-changes:
  - docs/coverage.md (count=2)
  - src/app.txt (count=2)
  - src/buildtool.zig (count=2)
  - src/vendoradapter.zig (count=2)
  - vendor/lib.txt (count=2)
- Evidence commits:
  - commit=158d6f63309f timestamp=1772668800 additions=1 deletions=0
  - commit=1806413f9ecf timestamp=1772582400 additions=1 deletions=0
  - commit=b37980bad093 timestamp=1772323200 additions=1 deletions=0
- Row caveats:
  - None

### 2. src/app.txt

- Score breakdown: total=64.240, frequency=30.000, churn=0.240, recency=20.000, cochange=14.000
- Changes: 3
- Additions: 5
- Deletions: 1
- Current size: 39
- Confidence: high
- Last commit: 158d6f63309f
- Lineage: None
- Top co-changes:
  - src/new.zig (count=2)
  - src/vendor\_adapter.zig (count=2)
  - docs/coverage.md (count=1)
  - glob/\[literal\]\*.txt (count=1)
  - src/buildtool.zig (count=1)
- Evidence commits:
  - commit=158d6f63309f timestamp=1772668800 additions=1 deletions=0
  - commit=a707ef7e560a timestamp=1772409600 additions=3 deletions=1
  - commit=b37980bad093 timestamp=1772323200 additions=1 deletions=0
- Row caveats:
  - None

### 3. docs/coverage.md

- Score breakdown: total=57.080, frequency=20.000, churn=0.080, recency=19.000, cochange=18.000
- Changes: 2
- Additions: 2
- Deletions: 0
- Current size: 36
- Confidence: medium
- Last commit: 1806413f9ecf
- Lineage: None
- Top co-changes:
  - src/buildtool.zig (count=2)
  - src/vendor\_adapter.zig (count=2)
  - src/vendoradapter.zig (count=2)
  - vendor/lib.txt (count=2)
  - glob/\[literal\]\*.txt (count=1)
- Evidence commits:
  - commit=1806413f9ecf timestamp=1772582400 additions=1 deletions=0
  - commit=b37980bad093 timestamp=1772323200 additions=1 deletions=0
- Row caveats:
  - None

### 4. src/buildtool.zig

- Score breakdown: total=57.080, frequency=20.000, churn=0.080, recency=19.000, cochange=18.000
- Changes: 2
- Additions: 2
- Deletions: 0
- Current size: 22
- Confidence: medium
- Last commit: 1806413f9ecf
- Lineage: None
- Top co-changes:
  - docs/coverage.md (count=2)
  - src/vendor\_adapter.zig (count=2)
  - src/vendoradapter.zig (count=2)
  - vendor/lib.txt (count=2)
  - glob/\[literal\]\*.txt (count=1)
- Evidence commits:
  - commit=1806413f9ecf timestamp=1772582400 additions=1 deletions=0
  - commit=b37980bad093 timestamp=1772323200 additions=1 deletions=0
- Row caveats:
  - None

### 5. src/vendoradapter.zig

- Score breakdown: total=57.080, frequency=20.000, churn=0.080, recency=19.000, cochange=18.000
- Changes: 2
- Additions: 2
- Deletions: 0
- Current size: 24
- Confidence: medium
- Last commit: 1806413f9ecf
- Lineage: None
- Top co-changes:
  - docs/coverage.md (count=2)
  - src/buildtool.zig (count=2)
  - src/vendor\_adapter.zig (count=2)
  - vendor/lib.txt (count=2)
  - glob/\[literal\]\*.txt (count=1)
- Evidence commits:
  - commit=1806413f9ecf timestamp=1772582400 additions=1 deletions=0
  - commit=b37980bad093 timestamp=1772323200 additions=1 deletions=0
- Row caveats:
  - None

### 6. vendor/lib.txt

- Score breakdown: total=57.080, frequency=20.000, churn=0.080, recency=19.000, cochange=18.000
- Changes: 2
- Additions: 2
- Deletions: 0
- Current size: 22
- Confidence: medium
- Last commit: 1806413f9ecf
- Lineage: None
- Top co-changes:
  - docs/coverage.md (count=2)
  - src/buildtool.zig (count=2)
  - src/vendor\_adapter.zig (count=2)
  - src/vendoradapter.zig (count=2)
  - glob/\[literal\]\*.txt (count=1)
- Evidence commits:
  - commit=1806413f9ecf timestamp=1772582400 additions=1 deletions=0
  - commit=b37980bad093 timestamp=1772323200 additions=1 deletions=0
- Row caveats:
  - None

### 7. src/new.zig

- Score breakdown: total=49.040, frequency=20.000, churn=0.040, recency=17.000, cochange=12.000
- Changes: 2
- Additions: 1
- Deletions: 0
- Current size: 9
- Confidence: medium
- Last commit: a707ef7e560a
- Lineage: Git rename edges only; no copy, split, merge, symbol, or semantic move tracking
  - Accepted aliases: src/old.zig
- Top co-changes:
  - src/app.txt (count=2)
  - docs/coverage.md (count=1)
  - glob/\[literal\]\*.txt (count=1)
  - src/buildtool.zig (count=1)
  - src/chain\-start.txt (count=1)
- Evidence commits:
  - commit=a707ef7e560a timestamp=1772409600 additions=0 deletions=0
  - commit=b37980bad093 timestamp=1772323200 additions=1 deletions=0
- Row caveats:
  - None

### 8. src/chain\-final.txt

- Score breakdown: total=39.000, frequency=10.000, churn=0.000, recency=19.000, cochange=10.000
- Changes: 1
- Additions: 0
- Deletions: 0
- Current size: 16
- Confidence: low
- Last commit: 1806413f9ecf
- Lineage: Git rename edges only; no copy, split, merge, symbol, or semantic move tracking
  - Caveat: lineage may be partial because at least one observed rename edge was outside active scope filters
- Top co-changes:
  - docs/coverage.md (count=1)
  - src/buildtool.zig (count=1)
  - src/vendor\_adapter.zig (count=1)
  - src/vendoradapter.zig (count=1)
  - vendor/lib.txt (count=1)
- Evidence commits:
  - commit=1806413f9ecf timestamp=1772582400 additions=0 deletions=0
- Row caveats:
  - None

### 9. glob/\[literal\]\*.txt

- Score breakdown: total=36.040, frequency=10.000, churn=0.040, recency=16.000, cochange=10.000
- Changes: 1
- Additions: 1
- Deletions: 0
- Current size: 13
- Confidence: low
- Last commit: b37980bad093
- Lineage: None
- Top co-changes:
  - docs/coverage.md (count=1)
  - src/app.txt (count=1)
  - src/buildtool.zig (count=1)
  - src/chain\-start.txt (count=1)
  - src/new.zig (count=1)
- Evidence commits:
  - commit=b37980bad093 timestamp=1772323200 additions=1 deletions=0
- Row caveats:
  - None

### 10. src/chain\-start.txt

- Score breakdown: total=36.040, frequency=10.000, churn=0.040, recency=16.000, cochange=10.000
- Changes: 1
- Additions: 1
- Deletions: 0
- Current size: None
- Confidence: low
- Last commit: b37980bad093
- Lineage: None
- Top co-changes:
  - docs/coverage.md (count=1)
  - glob/\[literal\]\*.txt (count=1)
  - src/app.txt (count=1)
  - src/buildtool.zig (count=1)
  - src/new.zig (count=1)
- Evidence commits:
  - commit=b37980bad093 timestamp=1772323200 additions=1 deletions=0
- Row caveats:
  - path is deleted or not present at HEAD
