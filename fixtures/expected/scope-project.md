# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.1
- Head commit: 0fafb8d95c608858ec42de2ea9276c38c79b8866
- Range: None
- Commit count: 5
- Shallow history: false
- Partial history: false
- Dirty worktree: false
- Auto fetch: false
- Paths: repo-relative

## Scope

- Selected scope: project
- Filters active: true
- Include prefixes: None
- Exclude prefixes: .flow/
- Outside include path count: 0
- Outside include change count: 0
- Excluded path count: 2
- Excluded change count: 5

## Caveats

- None

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- |
| 1 | src/vendor\_adapter.zig | 64.1 | 3 | 3 | high | 0fafb8d95c60 |
| 2 | src/app.txt | 62.2 | 3 | 6 | high | 0fafb8d95c60 |
| 3 | vendor/lib.txt | 51.1 | 2 | 2 | medium | e573d3171435 |
| 4 | glob/\[literal\]\*.txt | 36.0 | 1 | 1 | low | af64dae377af |
| 5 | src/old.zig | 36.0 | 1 | 1 | low | af64dae377af |
| 6 | weird/tab\tname.txt | 36.0 | 1 | 1 | low | af64dae377af |
| 7 | src/new.zig | 29.0 | 1 | 0 | low | 06afcb1401d6 |

## Evidence

### 1. src/vendor\_adapter.zig

- Score breakdown: total=64.120, frequency=30.000, churn=0.120, recency=20.000, cochange=14.000
- Changes: 3
- Additions: 3
- Deletions: 0
- Current size: 38
- Confidence: high
- Last commit: 0fafb8d95c60
- Top co-changes:
  - src/app.txt (count=2)
  - vendor/lib.txt (count=2)
  - glob/\[literal\]\*.txt (count=1)
  - src/old.zig (count=1)
  - weird/tab\tname.txt (count=1)
- Evidence commits:
  - commit=0fafb8d95c60 timestamp=1772668800 additions=1 deletions=0
  - commit=e573d3171435 timestamp=1772582400 additions=1 deletions=0
  - commit=af64dae377af timestamp=1772323200 additions=1 deletions=0
- Row caveats:
  - None

### 2. src/app.txt

- Score breakdown: total=62.240, frequency=30.000, churn=0.240, recency=20.000, cochange=12.000
- Changes: 3
- Additions: 5
- Deletions: 1
- Current size: 39
- Confidence: high
- Last commit: 0fafb8d95c60
- Top co-changes:
  - src/vendor\_adapter.zig (count=2)
  - glob/\[literal\]\*.txt (count=1)
  - src/new.zig (count=1)
  - src/old.zig (count=1)
  - vendor/lib.txt (count=1)
- Evidence commits:
  - commit=0fafb8d95c60 timestamp=1772668800 additions=1 deletions=0
  - commit=06afcb1401d6 timestamp=1772409600 additions=3 deletions=1
  - commit=af64dae377af timestamp=1772323200 additions=1 deletions=0
- Row caveats:
  - None

### 3. vendor/lib.txt

- Score breakdown: total=51.080, frequency=20.000, churn=0.080, recency=19.000, cochange=12.000
- Changes: 2
- Additions: 2
- Deletions: 0
- Current size: 22
- Confidence: medium
- Last commit: e573d3171435
- Top co-changes:
  - src/vendor\_adapter.zig (count=2)
  - glob/\[literal\]\*.txt (count=1)
  - src/app.txt (count=1)
  - src/old.zig (count=1)
  - weird/tab\tname.txt (count=1)
- Evidence commits:
  - commit=e573d3171435 timestamp=1772582400 additions=1 deletions=0
  - commit=af64dae377af timestamp=1772323200 additions=1 deletions=0
- Row caveats:
  - None

### 4. glob/\[literal\]\*.txt

- Score breakdown: total=36.040, frequency=10.000, churn=0.040, recency=16.000, cochange=10.000
- Changes: 1
- Additions: 1
- Deletions: 0
- Current size: 13
- Confidence: low
- Last commit: af64dae377af
- Top co-changes:
  - src/app.txt (count=1)
  - src/old.zig (count=1)
  - src/vendor\_adapter.zig (count=1)
  - vendor/lib.txt (count=1)
  - weird/tab\tname.txt (count=1)
- Evidence commits:
  - commit=af64dae377af timestamp=1772323200 additions=1 deletions=0
- Row caveats:
  - None

### 5. src/old.zig

- Score breakdown: total=36.040, frequency=10.000, churn=0.040, recency=16.000, cochange=10.000
- Changes: 1
- Additions: 1
- Deletions: 0
- Current size: None
- Confidence: low
- Last commit: af64dae377af
- Top co-changes:
  - glob/\[literal\]\*.txt (count=1)
  - src/app.txt (count=1)
  - src/vendor\_adapter.zig (count=1)
  - vendor/lib.txt (count=1)
  - weird/tab\tname.txt (count=1)
- Evidence commits:
  - commit=af64dae377af timestamp=1772323200 additions=1 deletions=0
- Row caveats:
  - path is deleted or not present at HEAD

### 6. weird/tab\tname.txt

- Score breakdown: total=36.040, frequency=10.000, churn=0.040, recency=16.000, cochange=10.000
- Changes: 1
- Additions: 1
- Deletions: 0
- Current size: 11
- Confidence: low
- Last commit: af64dae377af
- Top co-changes:
  - glob/\[literal\]\*.txt (count=1)
  - src/app.txt (count=1)
  - src/old.zig (count=1)
  - src/vendor\_adapter.zig (count=1)
  - vendor/lib.txt (count=1)
- Evidence commits:
  - commit=af64dae377af timestamp=1772323200 additions=1 deletions=0
- Row caveats:
  - None

### 7. src/new.zig

- Score breakdown: total=29.000, frequency=10.000, churn=0.000, recency=17.000, cochange=2.000
- Changes: 1
- Additions: 0
- Deletions: 0
- Current size: 9
- Confidence: low
- Last commit: 06afcb1401d6
- Top co-changes:
  - src/app.txt (count=1)
- Evidence commits:
  - commit=06afcb1401d6 timestamp=1772409600 additions=0 deletions=0
- Row caveats:
  - None
