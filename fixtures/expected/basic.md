# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.0.0-spike
- Head commit: f577978a22dd1db4fa1052dc677288d6325fc95c
- Range: None
- Commit count: 4
- Shallow history: false
- Partial history: false
- Dirty worktree: false
- Auto fetch: false
- Paths: repo-relative

## Scope

- Filters active: false
- Exclude prefixes: None
- Excluded path count: 0
- Excluded change count: 0

## Caveats

- None

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- |
| 1 | src/app.txt | 55.2 | 3 | 4 | high | 167229fed167 |
| 2 | src/lib.txt | 42.1 | 2 | 3 | medium | f577978a22dd |
| 3 | docs/guide.md | 31.1 | 1 | 2 | low | 167229fed167 |
| 4 | README.md | 29.0 | 1 | 1 | low | df4a28000ad3 |

## Evidence

### 1. src/app.txt

- Score breakdown: total=55.160, frequency=30.000, churn=0.160, recency=19.000, cochange=6.000
- Changes: 3
- Additions: 4
- Deletions: 0
- Current size: 19
- Confidence: high
- Last commit: 167229fed167
- Top co-changes:
  - README.md (count=1)
  - docs/guide.md (count=1)
  - src/lib.txt (count=1)
- Evidence commits:
  - commit=167229fed167 timestamp=1767398400 additions=1 deletions=0
  - commit=7dafd085378d timestamp=1767312000 additions=2 deletions=0
  - commit=df4a28000ad3 timestamp=1767225600 additions=1 deletions=0
- Row caveats:
  - None

### 2. src/lib.txt

- Score breakdown: total=42.120, frequency=20.000, churn=0.120, recency=20.000, cochange=2.000
- Changes: 2
- Additions: 3
- Deletions: 0
- Current size: 17
- Confidence: medium
- Last commit: f577978a22dd
- Top co-changes:
  - src/app.txt (count=1)
- Evidence commits:
  - commit=f577978a22dd timestamp=1767484800 additions=2 deletions=0
  - commit=7dafd085378d timestamp=1767312000 additions=1 deletions=0
- Row caveats:
  - None

### 3. docs/guide.md

- Score breakdown: total=31.080, frequency=10.000, churn=0.080, recency=19.000, cochange=2.000
- Changes: 1
- Additions: 2
- Deletions: 0
- Current size: 12
- Confidence: low
- Last commit: 167229fed167
- Top co-changes:
  - src/app.txt (count=1)
- Evidence commits:
  - commit=167229fed167 timestamp=1767398400 additions=2 deletions=0
- Row caveats:
  - None

### 4. README.md

- Score breakdown: total=29.040, frequency=10.000, churn=0.040, recency=17.000, cochange=2.000
- Changes: 1
- Additions: 1
- Deletions: 0
- Current size: 21
- Confidence: low
- Last commit: df4a28000ad3
- Top co-changes:
  - src/app.txt (count=1)
- Evidence commits:
  - commit=df4a28000ad3 timestamp=1767225600 additions=1 deletions=0
- Row caveats:
  - None
