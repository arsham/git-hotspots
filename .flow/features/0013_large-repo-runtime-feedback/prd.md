# Feature 0013: Large-repo runtime feedback

## Summary

Add opt-in runtime feedback for long local analyses without changing report
truth or stdout output contracts.

Chosen CLI surface:

```sh
git-hotspots --progress --repo . --format json
```

`--progress` emits bounded coarse phase messages to stderr. Table, JSON, and
Markdown reports remain deterministic stdout reports. The feature does not add
cache, streaming parsing, automatic progress, performance optimisation, or
report schema timing fields.

## Requirements

1. Add an optional `--progress` analysis flag.
2. `--progress` is opt-in. Existing commands without `--progress` remain
   stderr-silent on successful analysis, except pre-existing error behaviour.
3. `--progress` is an analysis flag and must be rejected with standalone
   `--explain` and standalone `--version`.
4. `--progress --help` may show help without running analysis or emitting
   progress phases.
5. Progress output must be written only to stderr.
6. Progress output must never be written to table, JSON, or Markdown stdout.
7. Table, JSON, and Markdown stdout must remain byte-stable for the same command
   with and without `--progress`.
8. JSON output with `--progress` must remain valid JSON and must not gain timing
   or progress fields.
9. Progress messages must be bounded, line-oriented, and human-readable.
10. Progress messages must be coarse phase feedback only, such as checking the
    repository, reading Git history, scoring files, rendering the report, and
    completing the run.
11. The final progress line may include elapsed wall-clock time on stderr only.
12. Progress messages must not include repo paths, file paths, raw omitted path
    lists, commit hashes, commit messages, remotes, author identities, source
    snippets, or report rows.
13. Progress messages must not imply telemetry, network activity, remote
    enrichment, cache use, provider use, bug prediction, code-quality scoring,
    developer ranking, or productivity analytics.
14. The implementation may thread a progress sink through analysis, but it must
    not change scoring, ranking, tie-breaks, confidence thresholds, Git log
    arguments, scope filtering, include/exclude semantics, inspect selection,
    report rendering semantics, cache behaviour, provider behaviour, network
    behaviour, or telemetry behaviour.
15. The implementation must not rewrite Git history ingestion into a streaming
    parser as part of this feature. Coarse progress is acceptable because the
    current implementation buffers `git log` output.
16. Errors during analysis may be accompanied by any progress lines that were
    already emitted, but the final error must still be clear on stderr and the
    process must exit non-zero.
17. `--progress` must work with `--repo`, `--since`, `--scope`,
    `--include-prefix`, `--exclude-prefix`, `--inspect`, and all report formats.
18. `--progress --inspect PATH` must preserve inspect semantics and stdout
    shape while emitting progress only to stderr.
19. Help and README documentation must describe `--progress` as opt-in local
    stderr feedback for long runs.
20. The canonical validation workflow must cover progress enabled and disabled,
    stdout/stderr separation, JSON validity with progress enabled, deterministic
    stdout, stderr privacy scans, no progress for standalone modes, this-repo
    smoke, and sibling-local-repo close-out smoke.

## Acceptance

- `git-hotspots --help` documents `--progress`.
- `git-hotspots --progress --repo . --format table` writes a normal table to
  stdout and progress lines to stderr.
- `git-hotspots --progress --repo . --format json` writes valid JSON to stdout
  and progress lines to stderr.
- `git-hotspots --progress --repo . --format markdown` writes a normal Markdown
  report to stdout and progress lines to stderr.
- For equivalent commands, stdout with `--progress` is byte-for-byte equal to
  stdout without `--progress`.
- Successful analysis without `--progress` remains stderr-silent in fixture and
  smoke tests.
- `--progress` is rejected with `--explain` and with `--version`.
- `--help`, `--version`, and `--explain` do not emit progress phase lines.
- Progress stderr contains only bounded phase/timing lines and passes privacy
  scans.
- Progress works with scope presets, explicit prefixes, and inspect without
  changing filtering, ranking, co-change, or inspect behaviour.
- `zig build validate` includes progress-specific checks and remains the
  canonical local validation entrypoint.
- Close-out validation runs on this repo and `sibling-local-repo`, recording
  only privacy-safe labels, command shapes, pass/fail status, bounded counts,
  dirty/scope/progress flags, elapsed summary, commit count, and tracked-file
  count.

## Edge cases

- `--progress` appears before or after other analysis flags.
- `--progress` is combined with `--format table`, `--format json`, and
  `--format markdown`.
- `--progress` is combined with `--scope project`, `--scope all`, include
  prefixes, exclude prefixes, and `--inspect`.
- `--progress` is combined with invalid `--since`, invalid repo, bare repo,
  empty repo, shallow repo, partial repo, dirty worktree, detached HEAD, and
  linked worktree fixture cases.
- `--progress` with JSON output remains valid when stdout is redirected and
  stderr is captured separately.
- `--progress 2>/dev/null` still leaves valid stdout output.
- Progress stderr contains no ANSI escape sequences, carriage-return spinners,
  absolute paths, home paths, remotes, emails, author names, commit messages,
  raw source snippets, or raw report rows.
- Validation timing helpers do not mix their own timing output with application
  progress stderr in assertions.
- Large-history close-out smoke proves the feature gives user-visible feedback
  during the slow path without changing report truth.

## Verification

Required local gates:

```sh
zig fmt --check build.zig src tests
zig build test
zig build validate
git diff --check
git status --short --branch
```

Required fixture checks include command shapes equivalent to:

```sh
./zig-out/bin/git-hotspots --repo fixtures/basic --format json
./zig-out/bin/git-hotspots --repo fixtures/basic --progress --format json
./zig-out/bin/git-hotspots --repo fixtures/basic --progress --format table
./zig-out/bin/git-hotspots --repo fixtures/basic --progress --format markdown
./zig-out/bin/git-hotspots --repo fixtures/basic --progress --inspect src/app.txt --format json
./zig-out/bin/git-hotspots --repo fixtures/scope --progress --scope project --format json
./zig-out/bin/git-hotspots --progress --explain
./zig-out/bin/git-hotspots --progress --version
```

Validation must separately capture stdout and stderr. It must compare stdout for
progress-enabled and progress-disabled commands, assert progress is stderr-only,
assert JSON validity, and privacy-scan captured stderr.

Close-out validation must use the existing privacy-safe real-repo workflow:

```sh
zig build validate -Dcloseout=true -Dsmoke-repo=<operator-provided-local-repo> -Dsmoke-label=sibling-local-repo
```

If the sibling repo is unavailable, use only an explicit approved safe skip
reason. Do not commit private repo paths, private repo names, raw private
reports, remotes, author identities, commit messages, or source snippets.

## Non-goals

- No automatic progress.
- No `--quiet` flag.
- No percentages, ETAs, progress bars, spinners, carriage-return updates, or
  live commit counts.
- No timing or progress fields in JSON, Markdown, or table reports.
- No streaming Git parser rewrite.
- No cache, database, or performance optimisation.
- No change to the current Git stdout capture limit.
- No scoring, confidence, ranking, co-change, recency, scope, or inspect
  semantics changes.
- No providers, tree-sitter, LSP, ctags, dependency, blame, test, or coverage
  enrichment.
- No source snippets, diffs, commit messages, author identities, ownership,
  developer metrics, or productivity analytics.
- No network, fetch, upload, telemetry, remote enrichment, CI, release,
  package, hosted-product, or commercial planning work.
