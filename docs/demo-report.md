# Public demo report snapshot

This is a static public demo snapshot generated from this repository only. It
shows file-level Git-history evidence for where a maintainer might inspect
first; rows are investigation prompts, not judgements about people or source
health.

## Snapshot metadata

- Source commit: 881d42f3b400efc166282b0c0710c871b94ed515
- Command shape: `./zig-out/bin/git-hotspots --repo . --scope project --limit 10 --format markdown`
- Subject repository: this public repository
- Output format: Markdown
- Scope: project
- Path display: repo-relative

## How to read this

Use the rows below as local Git-history prompts for deciding what to inspect
first. Scores combine file-level history signals such as change frequency,
churn, recency, and co-change evidence. They are:

- Not bug predictions.
- Not objective code-quality ratings or risk labels.
- Not maintainer assessments or developer rankings.
- Not ownership analysis or productivity analysis.

## Not shown

The project scope filters generated/cache/build-style prefixes such as `.flow/`,
`.zig-cache/`, `zig-out/`, `target/`, `node_modules/`, `dist/`, `build/`, and
`coverage/` from result paths and evidence details. This snapshot does not show
private, sibling, or third-party repository output.

<!-- BEGIN GENERATED DEMO REPORT -->
# git-hotspots report

File-level Git-history investigation prompts, not bug predictions or code-quality ratings.

## Run summary

- Tool: git-hotspots 0.1.0-alpha.3
- Head commit: 881d42f3b400efc166282b0c0710c871b94ed515
- Range: None
- Commit count: 104
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
- Excluded path count: 72
- Excluded change count: 201

## Caveats

- None

## Top hotspots

| Rank | Path | Score | Changes | Churn | Confidence | Lineage | Last commit |
| ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | src/main.zig | 235.2 | 16 | 881 | high | no | 5e7a7de1ac25 |
| 2 | README.md | 231.2 | 17 | 534 | high | no | 990ba5b13646 |
| 3 | tests/integration.sh | 224.2 | 15 | 856 | high | no | 5e7a7de1ac25 |
| 4 | tools/validate.sh | 210.0 | 13 | 1438 | high | no | 5e7a7de1ac25 |
| 5 | src/report.zig | 182.2 | 11 | 805 | high | no | 5e7a7de1ac25 |
| 6 | src/git.zig | 169.9 | 9 | 1451 | high | no | 990ba5b13646 |
| 7 | src/model.zig | 166.5 | 12 | 162 | high | no | 5e7a7de1ac25 |
| 8 | fixtures/expected/scope\-filtered.md | 122.5 | 6 | 587 | high | no | 731eed18bc94 |
| 9 | fixtures/expected/basic.json | 121.8 | 8 | 69 | high | no | 731eed18bc94 |
| 10 | src/explain.zig | 115.9 | 7 | 151 | high | no | 990ba5b13646 |

## Evidence

### 1. src/main.zig

- Score breakdown: total=235.218, frequency=160.000, churn=35.240, recency=19.978, cochange=20.000
- Changes: 16
- Additions: 807
- Deletions: 74
- Current size: 39264
- Confidence: high
- Last commit: 5e7a7de1ac25
- Lineage: None
- Top co-changes:
  - tests/integration.sh (count=15)
  - README.md (count=14)
  - src/model.zig (count=12)
  - tools/validate.sh (count=12)
  - src/report.zig (count=11)
- Evidence commits:
  - commit=5e7a7de1ac25 timestamp=1779583086 additions=41 deletions=4
  - commit=990ba5b13646 timestamp=1779574701 additions=31 deletions=4
  - commit=0766c491eabe timestamp=1779569359 additions=37 deletions=4
- Row caveats:
  - None

### 2. README.md

- Score breakdown: total=231.241, frequency=170.000, churn=21.360, recency=19.881, cochange=20.000
- Changes: 17
- Additions: 411
- Deletions: 123
- Current size: 12424
- Confidence: high
- Last commit: 990ba5b13646
- Lineage: None
- Top co-changes:
  - src/main.zig (count=14)
  - tests/integration.sh (count=14)
  - tools/validate.sh (count=12)
  - src/model.zig (count=11)
  - src/report.zig (count=10)
- Evidence commits:
  - commit=990ba5b13646 timestamp=1779574701 additions=12 deletions=2
  - commit=0766c491eabe timestamp=1779569359 additions=28 deletions=11
  - commit=731eed18bc94 timestamp=1779499551 additions=21 deletions=20
- Row caveats:
  - None

### 3. tests/integration.sh

- Score breakdown: total=224.218, frequency=150.000, churn=34.240, recency=19.978, cochange=20.000
- Changes: 15
- Additions: 779
- Deletions: 77
- Current size: 53948
- Confidence: high
- Last commit: 5e7a7de1ac25
- Lineage: None
- Top co-changes:
  - src/main.zig (count=15)
  - README.md (count=14)
  - src/model.zig (count=12)
  - tools/validate.sh (count=12)
  - src/report.zig (count=11)
- Evidence commits:
  - commit=5e7a7de1ac25 timestamp=1779583086 additions=29 deletions=1
  - commit=990ba5b13646 timestamp=1779574701 additions=46 deletions=0
  - commit=0766c491eabe timestamp=1779569359 additions=14 deletions=0
- Row caveats:
  - None

### 4. tools/validate.sh

- Score breakdown: total=209.978, frequency=130.000, churn=40.000, recency=19.978, cochange=20.000
- Changes: 13
- Additions: 1308
- Deletions: 130
- Current size: 73059
- Confidence: high
- Last commit: 5e7a7de1ac25
- Lineage: None
- Top co-changes:
  - README.md (count=12)
  - src/main.zig (count=12)
  - tests/integration.sh (count=12)
  - src/model.zig (count=9)
  - src/report.zig (count=8)
- Evidence commits:
  - commit=5e7a7de1ac25 timestamp=1779583086 additions=35 deletions=8
  - commit=0766c491eabe timestamp=1779569359 additions=49 deletions=5
  - commit=731eed18bc94 timestamp=1779499551 additions=112 deletions=43
- Row caveats:
  - None

### 5. src/report.zig

- Score breakdown: total=182.178, frequency=110.000, churn=32.200, recency=19.978, cochange=20.000
- Changes: 11
- Additions: 769
- Deletions: 36
- Current size: 39182
- Confidence: high
- Last commit: 5e7a7de1ac25
- Lineage: None
- Top co-changes:
  - src/main.zig (count=11)
  - tests/integration.sh (count=11)
  - README.md (count=10)
  - src/model.zig (count=10)
  - tools/validate.sh (count=8)
- Evidence commits:
  - commit=5e7a7de1ac25 timestamp=1779583086 additions=165 deletions=18
  - commit=990ba5b13646 timestamp=1779574701 additions=71 deletions=3
  - commit=0766c491eabe timestamp=1779569359 additions=106 deletions=0
- Row caveats:
  - None

### 6. src/git.zig

- Score breakdown: total=169.881, frequency=90.000, churn=40.000, recency=19.881, cochange=20.000
- Changes: 9
- Additions: 1379
- Deletions: 72
- Current size: 56512
- Confidence: high
- Last commit: 990ba5b13646
- Lineage: None
- Top co-changes:
  - README.md (count=8)
  - src/main.zig (count=8)
  - src/model.zig (count=8)
  - tests/integration.sh (count=8)
  - src/report.zig (count=7)
- Evidence commits:
  - commit=990ba5b13646 timestamp=1779574701 additions=306 deletions=0
  - commit=9ebbdb5e566b timestamp=1779493044 additions=257 deletions=6
  - commit=88ddd0f76ab0 timestamp=1779485817 additions=215 deletions=30
- Row caveats:
  - None

### 7. src/model.zig

- Score breakdown: total=166.458, frequency=120.000, churn=6.480, recency=19.978, cochange=20.000
- Changes: 12
- Additions: 160
- Deletions: 2
- Current size: 4807
- Confidence: high
- Last commit: 5e7a7de1ac25
- Lineage: None
- Top co-changes:
  - src/main.zig (count=12)
  - tests/integration.sh (count=12)
  - README.md (count=11)
  - src/report.zig (count=10)
  - tools/validate.sh (count=9)
- Evidence commits:
  - commit=5e7a7de1ac25 timestamp=1779583086 additions=9 deletions=0
  - commit=990ba5b13646 timestamp=1779574701 additions=7 deletions=0
  - commit=0766c491eabe timestamp=1779569359 additions=16 deletions=0
- Row caveats:
  - None

### 8. fixtures/expected/scope\-filtered.md

- Score breakdown: total=122.492, frequency=60.000, churn=23.480, recency=19.012, cochange=20.000
- Changes: 6
- Additions: 428
- Deletions: 159
- Current size: 8162
- Confidence: high
- Last commit: 731eed18bc94
- Lineage: None
- Top co-changes:
  - README.md (count=6)
  - fixtures/expected/basic.md (count=6)
  - src/main.zig (count=6)
  - tests/integration.sh (count=6)
  - fixtures/expected/basic.json (count=5)
- Evidence commits:
  - commit=731eed18bc94 timestamp=1779499551 additions=149 deletions=56
  - commit=9ebbdb5e566b timestamp=1779493044 additions=93 deletions=102
  - commit=384e64fb7602 timestamp=1779475719 additions=1 deletions=0
- Row caveats:
  - None

### 9. fixtures/expected/basic.json

- Score breakdown: total=121.772, frequency=80.000, churn=2.760, recency=19.012, cochange=20.000
- Changes: 8
- Additions: 64
- Deletions: 5
- Current size: 4141
- Confidence: high
- Last commit: 731eed18bc94
- Lineage: None
- Top co-changes:
  - README.md (count=8)
  - src/main.zig (count=8)
  - tests/integration.sh (count=8)
  - fixtures/expected/basic.md (count=6)
  - fixtures/expected/scope\-filtered.json (count=6)
- Evidence commits:
  - commit=731eed18bc94 timestamp=1779499551 additions=1 deletions=1
  - commit=9ebbdb5e566b timestamp=1779493044 additions=4 deletions=0
  - commit=1e87a00bb99f timestamp=1779489408 additions=1 deletions=1
- Row caveats:
  - None

### 10. src/explain.zig

- Score breakdown: total=115.921, frequency=70.000, churn=6.040, recency=19.881, cochange=20.000
- Changes: 7
- Additions: 143
- Deletions: 8
- Current size: 5904
- Confidence: high
- Last commit: 990ba5b13646
- Lineage: None
- Top co-changes:
  - README.md (count=7)
  - fixtures/expected/explain.txt (count=7)
  - src/main.zig (count=7)
  - tests/integration.sh (count=7)
  - src/model.zig (count=5)
- Evidence commits:
  - commit=990ba5b13646 timestamp=1779574701 additions=9 deletions=0
  - commit=0766c491eabe timestamp=1779569359 additions=14 deletions=0
  - commit=731eed18bc94 timestamp=1779499551 additions=6 deletions=3
- Row caveats:
  - None
<!-- END GENERATED DEMO REPORT -->
