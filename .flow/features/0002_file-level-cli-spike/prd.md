# Feature 0002 PRD: File-level CLI spike

## Purpose

Build the first executable proof for `git-hotspots`: a small Zig CLI that turns
local Git history into deterministic, explainable file-level hotspot reports.

This feature exists to validate the core evidence loop before provider, cache,
release, or integration work. The result should be useful enough to run on real
repositories, but still clearly labelled as a spike-quality first layer.

## Source alignment

- Capability brief: `B001 Local-first hotspot intelligence CLI`.
- Previous feature: `0001 Project goals and planning briefs`.
- Public thesis: deterministic, local-first hotspot intelligence CLI for
  developers and coding agents.
- Tagline: "Before you refactor, ask Git where the pain is."

## Requirements

### R1. Minimal command surface

The CLI must expose one executable command surface:

```text
git-hotspots [--repo PATH] [--limit N] [--format table|json] [--since REV]
```

Defaults:

- `--repo .`
- `--limit 10`
- `--format table`
- full reachable history up to `HEAD` when `--since` is omitted

`--since REV` means analyse commits reachable from `HEAD` after the supplied Git
revision, equivalent to a `REV..HEAD` range for the spike. If the supplied
revision is invalid, the command must fail clearly.

### R2. Local-only execution

The CLI must analyse only local repository data. It must not fetch, pull, push,
contact remotes, upload data, use telemetry, or perform remote enrichment.

The spike may shell out to the local `git` executable. It must not introduce
libgit2, a database, a cache, provider runtimes, or network-capable services.

### R3. Repository discovery and history metadata

The CLI must resolve the target repository from `--repo` and record analysis
metadata for JSON output:

- repository label or path as provided/project-relative where possible;
- `HEAD` commit oid when available;
- analysed range description;
- analysed commit count;
- earliest seen commit oid when available;
- shallow history flag;
- partial/promisor history flag when Git exposes it;
- `auto_fetch: false`.

Non-git directories, bare repositories, empty repositories, and repositories
without commits must fail or report clearly without panic.

### R4. First Git command stream

The first implementation should use local Git CLI commands equivalent to this
stream:

```text
git -C <repo> rev-parse --is-inside-work-tree
git -C <repo> rev-parse --show-toplevel
git -C <repo> rev-parse --verify HEAD^{commit}
git -C <repo> rev-parse --is-shallow-repository
git -C <repo> config --get extensions.partialclone
git -C <repo> ls-tree -r -z -l HEAD
git -C <repo> log --date-order --numstat -z --find-renames --find-copies \
  --format=format:%x1e%H%x1f%ct%x1f%P <range>
```

The runner may adjust flags only to preserve the same contract more safely on
the installed Git version. Any adjustment must be covered by tests and recorded
in code comments or docs.

### R5. File aggregate model

The implementation must aggregate file-level evidence by project-relative path.
For each path, collect at least:

- change count: number of commits touching the path;
- additions;
- deletions;
- churn: additions plus deletions;
- last changed commit and timestamp evidence;
- current size in bytes from `HEAD` tree when available;
- co-change count or summary;
- caveats;
- bounded evidence examples.

Binary files, deleted files, renamed files, huge commits, and missing current
sizes should produce caveats rather than crashes.

### R6. Co-change cap

Co-change must stay bounded. For each commit, co-change pair expansion should be
skipped or capped when the changed-file count exceeds a documented threshold.
The initial threshold may be simple, such as 200 changed files per commit.
Skipped or capped commits must add a caveat to affected results or analysis
metadata.

### R7. First scoring formula

The first scoring formula must be integer, deterministic, and documented in code
or docs. It is a spike heuristic, not a claim of objective risk.

Initial formula:

```text
change_points  = change_count * 100
churn_points   = min(churn, 10000) / 10
recency_points = analysed_commit_count == 0
                 ? 0
                 : (last_changed_order * 100) / analysed_commit_count
cochange_points = min(co_change_count, 100)
size_points     = current_size_bytes == null
                  ? 0
                  : min(current_size_bytes / 1024, 100)
score = change_points + churn_points + recency_points + cochange_points + size_points
```

`last_changed_order` is the one-based order of the newest commit touching the
path within the analysed commit stream. This makes recency relative to analysed
history rather than wall clock.

Tie-breakers:

1. score descending;
2. path ascending bytewise or Unicode scalar order, but consistently documented;
3. no unstable iteration-order ties.

### R8. Confidence and caveats

Each result must include a confidence label and caveats.

Suggested initial confidence:

- `high`: complete local history, current file size available, no severe caveat;
- `medium`: shallow or partial history, binary-only churn gaps, rename/delete
  ambiguity, missing current size, or large commit co-change cap;
- `low`: evidence is too incomplete for normal ranking but still reportable.

Output copy must frame hotspots as investigation prompts. It must not claim bug
prediction, code-quality scoring, developer ranking, or maintainer judgement.

### R9. JSON output contract

`--format json` is the canonical validation output. It must be deterministic for
repeated runs against the same repo/ref/config/tool version.

Minimum JSON shape:

```json
{
  "schema_version": "git-hotspots.file-report.v0",
  "tool_version": "dev",
  "analysis": {
    "repo": ".",
    "head": "<oid>",
    "range": "<description>",
    "history": {
      "is_shallow": false,
      "is_partial": false,
      "auto_fetch": false,
      "analysed_commit_count": 0,
      "earliest_seen_commit": null
    }
  },
  "results": [
    {
      "rank": 1,
      "path": "src/example.zig",
      "score": 0,
      "metrics": {
        "change_count": 0,
        "churn": 0,
        "additions": 0,
        "deletions": 0,
        "last_changed": null,
        "current_size": null,
        "co_change_count": 0
      },
      "confidence": "medium",
      "caveats": [],
      "evidence": []
    }
  ]
}
```

Fields may be added only if they are deterministic, local, and covered by tests.
Default JSON must not include author names, author emails, absolute local paths,
remote URLs, telemetry identifiers, or source snippets.

### R10. Table output

Default table output must render from the same report model as JSON. It should
show enough evidence to be useful without pretending the score is a quality
judgement.

At minimum, include rank, path, score, change count, churn, current size when
available, confidence, and a compact caveat indicator or summary.

### R11. Fixture strategy

Tests should generate Git fixture repositories in temporary directories rather
than checking in `.git` directories.

Fixture generation must use fixed commit timestamps and dummy local author data
so tests are deterministic.

Minimum fixture coverage:

- basic hot versus cold file ranking;
- churn versus frequency separation;
- recency tie and score tie-break behaviour;
- co-change evidence and cap behaviour;
- rename, delete, and binary file cases;
- shallow clone or simulated shallow-history behaviour;
- empty and non-git failure paths;
- paths with spaces and unicode;
- large commit caveat behaviour.

### R12. Documentation and help text

README or CLI help may be updated only to explain the current spike honestly:

- command usage;
- local-only default;
- JSON/table output;
- limitations;
- hotspots as investigation prompts.

Docs must not introduce monetisation plans, hosted product strategy, unsupported
provider promises, bug-prediction claims, code-quality scoring claims, or
developer ranking language.

## Edge cases

Implementation and tests should account for:

- non-git directories;
- bare repositories;
- empty repositories and repositories with no commits;
- detached `HEAD`;
- shallow clones;
- partial/promisor clones;
- linked worktrees where practical;
- merge commits;
- large initial imports;
- generated/vendor-like mass changes as large-commit caveats, not special
  product judgement;
- renames and deletes;
- binary files where numstat churn is unavailable;
- paths with spaces, tabs, unicode, and unusual separators;
- equal scores and equal timestamps;
- dirty worktrees, which should not silently affect history-derived results.

## Verification

Close-out evidence should include these commands or equivalent platform-safe
variants after implementation exists:

```bash
zig fmt --check build.zig src tests
zig build test
zig build
git diff --check
```

Determinism proof:

```bash
./zig-out/bin/git-hotspots --repo fixtures/basic --format json > /tmp/git-hotspots-a.json
./zig-out/bin/git-hotspots --repo fixtures/basic --format json > /tmp/git-hotspots-b.json
diff -u /tmp/git-hotspots-a.json /tmp/git-hotspots-b.json
```

Privacy/local-first scan:

```bash
./zig-out/bin/git-hotspots --repo fixtures/basic --format json \
  | jq -e 'all(.results[]; (.path | startswith("/") | not))'

rg -n "fetch|pull|push|telemetry|http|author_email|author_name" \
  src tests README.md
```

Shallow handling proof:

```bash
./zig-out/bin/git-hotspots --repo fixtures/shallow --format json \
  | jq -e '.analysis.history.is_shallow == true and .analysis.history.auto_fetch == false'
```

Performance smoke:

```bash
/usr/bin/time -v ./zig-out/bin/git-hotspots --repo fixtures/medium --format json >/tmp/git-hotspots-medium.json
```

Flow validation:

```bash
flow validate --target feature:0002 --format json
```

If `jq`, `/usr/bin/time`, or `rg` are unavailable in an execution environment,
the runner must record the replacement command and evidence.

## Stop and reshape triggers

Stop and return to shaping if implementation appears to require:

- changing away from Zig without an explicit tooling decision;
- libgit2 or another embedded Git library;
- cache or database schema;
- tree-sitter, LSP, ctags, or provider API design;
- author identity metrics;
- network access, remote fetching, telemetry, or upload behaviour;
- Markdown report templating, GitHub Actions, release automation, or hosted
  product work;
- scoring language that implies bug prediction, objective quality judgement, or
  developer ranking.
