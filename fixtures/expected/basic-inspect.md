# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.1
- Head commit: f577978a22dd1db4fa1052dc677288d6325fc95c
- Range: None
- Commit count: 4
- Shallow history: false
- Partial history: false
- Dirty worktree: false
- Auto fetch: false
- Paths: repo-relative

## Scope

- Selected scope: all
- Filters active: false
- Include prefixes: None
- Exclude prefixes: None
- Outside include path count: 0
- Outside include change count: 0
- Excluded path count: 0
- Excluded change count: 0

## Inspect

- Requested path: src/app.txt
- Matched path: src/app.txt
- Rank in scoped evidence universe: 1

## Caveats

- None

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- |
| 1 | src/app.txt | 55.2 | 3 | 4 | high | 167229fed167 |

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
