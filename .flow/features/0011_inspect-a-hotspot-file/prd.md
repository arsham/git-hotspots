# Feature 0011: Inspect a hotspot file

## Summary

Add a bounded single-file drilldown mode for the existing file-level hotspot
engine. The feature lets a user ask why one repo-relative file is hot without
introducing source-aware providers, cache, blame, authors, commit messages,
source snippets, or judgemental claims.

Chosen CLI surface:

```sh
git-hotspots --inspect PATH [--repo PATH] [--since REV] [--include-prefix PATH]... [--exclude-prefix PATH]... [--format table|json|markdown]
```

`--inspect PATH` is a flag, not a subcommand. This keeps the current CLI parser
small while giving the public feature the right product word.

## Requirements

1. Add repeatable-compatible analysis support for one optional `--inspect PATH`
   target. The target is an exact repo-relative Git path using `/` separators.
2. Validate inspect paths with the same safety posture as prefix filters:
   reject empty paths, absolute POSIX paths, Windows drive-rooted paths, leading
   backslash paths, `..` segments, and control characters.
3. Do not implement glob, pathspec, gitignore, regex, fuzzy, basename, or
   multi-file matching semantics for inspect.
4. Allow `--inspect PATH` with `--repo`, `--since`, `--include-prefix`,
   `--exclude-prefix`, and `--format table|json|markdown`.
5. Reject `--inspect PATH` with `--explain` and `--version` using clear stderr.
6. Reject `--limit` when `--inspect` is present. This avoids implying that a
   user-selected target can be hidden by top-N truncation.
7. Apply normal include/exclude scope filtering before inspect target selection.
   A target outside include scope or removed by exclude scope must not appear in
   results or co-change evidence.
8. Aggregate Git history, compute co-change evidence, score all in-scope files,
   and sort/rank before selecting the inspect target. Select before normal
   limit truncation so below-top-N targets remain inspectable.
9. Successful inspect output must contain exactly one result row in table,
   JSON, and Markdown formats.
10. Inspect output must reuse existing file-level evidence fields: score
    breakdown, change count, additions, deletions, churn, last-changed commit,
    last-changed timestamp, current size, co-changes, confidence, caveats, and
    bounded evidence commits.
11. JSON inspect output must be additive and deterministic. It should include
    inspect-specific metadata such as requested path, matched path, and rank in
    the scoped evidence universe without breaking normal report JSON.
12. Markdown inspect output must remain deterministic, escaped, and privacy-safe.
    It should keep the same investigation-prompt framing as normal reports.
13. If the inspect target has no matching Git-history evidence in the selected
    scope, exit non-zero with clear, non-judgemental stderr and no panic.
14. Inspect must preserve deleted/not-present-at-HEAD caveats, binary/non-text
    caveats, large-commit caveats, shallow/partial/dirty global caveats, and
    scope metadata.
15. Normal ranked reports must remain byte-stable except intentional help/docs
    updates and any explicitly accepted additive internal model changes.

## Acceptance

- `git-hotspots --help` documents `--inspect PATH` as an exact repo-relative
  file drilldown flag.
- `git-hotspots --inspect src/app.txt --format table|json|markdown` succeeds on
  the basic fixture and emits exactly one result row.
- Inspect JSON for a target file matches the equivalent row from a full JSON
  analysis under the same repo, range, and scope for score breakdown, changes,
  churn, recency, current size, co-changes, confidence, caveats, and bounded
  evidence commits.
- Inspect target selection is independent of normal `--limit` truncation because
  `--limit` is rejected with `--inspect`.
- Include/exclude filters affect inspect consistently and do not leak
  out-of-scope paths into results or co-change lists.
- Exact path behaviour is documented and tested for renamed, deleted, binary,
  unicode, spaces, glob-like, tab-escaped, and markdown-special paths.
- Missing/invalid inspect targets and invalid flag combinations fail with clear
  stderr and non-zero exit status.
- Existing table, JSON, Markdown, `--explain`, `--version`, prefix-filter, and
  fixture golden outputs remain stable except intentional help/docs additions.
- No scoring formula, Git traversal semantics, report ranking, confidence
  thresholds, network posture, telemetry posture, provider/cache behaviour,
  author metrics, or source-content exposure changes.
- `zig build validate` covers inspect fixture goldens, determinism, error cases,
  privacy scans, and real-repo smoke.

## Edge cases

- Target path exists in history but is below the default top 10.
- Target path has no matching history in the selected range.
- Target path is valid but outside `--include-prefix` scope.
- Target path is valid but removed by `--exclude-prefix` scope.
- Target path is deleted or not present at HEAD.
- Target path has binary/non-text churn.
- Target path comes from normalized Git rename syntax, including braced rename
  syntax.
- Target path contains spaces, unicode, markdown-sensitive characters, glob-like
  literals, or Git-quoted tab escapes.
- Repository is non-git, bare, empty, shallow, partial, detached, dirty, or uses
  a linked worktree.
- `--since` is invalid.
- `--inspect` is combined with `--explain`, `--version`, or `--limit`.

## Verification

Required local gates:

```sh
zig fmt --check build.zig src tests
zig build test
zig build validate
git diff --check
git status --short --branch
```

Required fixture checks:

```sh
./zig-out/bin/git-hotspots --repo fixtures/basic --inspect src/app.txt --format json
./zig-out/bin/git-hotspots --repo fixtures/basic --inspect src/app.txt --format markdown
./zig-out/bin/git-hotspots --repo fixtures/basic --inspect src/app.txt --format table
./zig-out/bin/git-hotspots --repo fixtures/scope --exclude-prefix .flow/ --inspect src/vendor_adapter.zig --format json
./zig-out/bin/git-hotspots --repo fixtures/scope --include-prefix src/ --inspect src/new.zig --format json
./zig-out/bin/git-hotspots --repo fixtures/edge --inspect 'glob/[literal]*.txt' --format markdown
```

Close-out validation must use the existing privacy-safe real-repo workflow:

```sh
zig build validate -Dcloseout=true -Dsmoke-repo=<operator-provided-local-repo> -Dsmoke-label=sibling-local-repo
```

If the sibling repo is unavailable, use only an explicit approved safe skip
reason. Do not commit private repo paths, private repo names, raw private
reports, remotes, author identities, commit messages, or source snippets.

## Non-goals

- No `inspect <path>` subcommand in this feature.
- No symbol/function-level drilldown.
- No tree-sitter, LSP, ctags, dependency, blame, test, or coverage providers.
- No cache/database work.
- No source snippets, patches, diffs, commit messages, author identities, blame,
  ownership, or developer metrics.
- No recommendations that a file is bad, predicts bugs, objectively scores code
  quality, ranks maintainers, or measures developer productivity.
- No network, fetch, upload, telemetry, remote enrichment, CI, release, package,
  or hosted-product work.
