# Public demo report snapshot

## Purpose

Create one committed public example of `git-hotspots` output so visitors can see
what the CLI produces before installing or running it.

The snapshot is evidence from this public repository only. It must be framed as
local Git-history investigation prompts, not a judgement of code quality, risk,
maintainers, contributors, or future bugs.

## Requirements

1. Add one static public demo document at `docs/demo-report.md`.
2. Use this repository only as the demo subject.
3. Generate or capture the snapshot from a clean detached source commit so the
   report does not include dirty-worktree caveats caused by Flow shaping or
   execution state.
4. Record the exact command shape used for the snapshot.
5. The primary generated report command must use project scope, Markdown output,
   and repo-relative paths:
   `./zig-out/bin/git-hotspots --repo . --scope project --limit 10 --format markdown`.
6. The document must clearly state that rows are investigation prompts from
   local Git history.
7. The document must not claim that hotspots are bug predictions, objective code
   quality ratings, risk scores, maintainer judgement, developer ranking,
   ownership analysis, productivity analysis, or source-health diagnosis.
8. The snapshot must not include private/sibling/third-party raw report output.
9. The snapshot must not include absolute local paths, remote URLs, author
   identities, emails, commit messages, source snippets, raw diffs, private
   repo names, or private labels.
10. Project-scope excluded prefixes may appear in the scope metadata or
    explanatory text, but not as result paths, evidence headings, co-change
    paths, or inspected paths.
11. The document may include a short "how to read this" note and a short "not
    shown" note.
12. README may receive at most a small discoverability link to the demo if it
    improves public navigation.
13. Do not change runtime behaviour, CLI flags, report schema, source files,
    tests, fixtures, build logic, scoring, provider behaviour, cache behaviour,
    CI, release packaging, or generated parser sources.

## Acceptance

- `docs/demo-report.md` exists and is public-facing.
- The snapshot source command and source commit are recorded in or beside the
  document.
- The generated report section is deterministic: regenerating from a clean
  detached clone at the recorded source commit produces byte-identical output
  for the generated section or full snapshot, depending on the chosen document
  structure.
- The demo report contains the expected generated sections: `Run summary`,
  `Scope`, `Caveats`, `Top hotspots`, and `Evidence`.
- The generated output reports `Dirty worktree: false`, `Auto fetch: false`,
  `Paths: repo-relative`, and `Selected scope: project`.
- Result paths, evidence headings, co-change paths, and inspect paths do not
  leak `.flow/`, `.zig-cache/`, `zig-out/`, `target/`, `node_modules/`,
  `dist/`, `build/`, or `coverage/` entries.
- Changed docs contain no commercial/SaaS/pricing/sales strategy.
- Changed docs contain no positive bug-prediction, objective quality-score,
  maintainer-judgement, developer-ranking, ownership, productivity, or risk
  claims.
- No source, test, fixture, build, runtime, provider, cache, CI, release, or
  packaging files are changed.

## Edge cases

- If the worktree is dirty, the runner must not capture the public snapshot from
  the dirty worktree. Use a clean committed source commit or clean detached
  clone instead.
- If the generated output changes while implementing the feature, record the
  exact source commit used and validate against that commit rather than relying
  on chat memory.
- If a desirable demo requires `--scope all`, sibling/private output, or
  third-party output, stop and reshape instead of committing it.
- If the generated Markdown contains an unexpected private, absolute, author,
  remote, source-snippet, or judgemental claim, stop and fix the input or
  reshape the feature.
- If adding a README link would make README feel process-heavy or promotional,
  skip the link and keep the demo document standalone.

## Verification

Run the normal project validation:

```sh
zig build validate
```

Run whitespace validation:

```sh
git diff --check
```

Validate deterministic generation from the recorded source commit. The exact
helper may differ if the document uses markers around the generated section, but
it must prove the same invariant:

```sh
test -f docs/demo-report.md
RECORDED_HEAD=$(awk -F': ' '/^- Source commit: / { print $2; exit }' docs/demo-report.md)
git cat-file -e "$RECORDED_HEAD^{commit}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git clone --quiet --no-local . "$tmp/repo"
git -C "$tmp/repo" checkout --quiet --detach "$RECORDED_HEAD"

./zig-out/bin/git-hotspots --repo "$tmp/repo" --scope project --limit 10 --format markdown > "$tmp/a.md"
./zig-out/bin/git-hotspots --repo "$tmp/repo" --scope project --limit 10 --format markdown > "$tmp/b.md"

diff -u "$tmp/a.md" "$tmp/b.md"
```

If `docs/demo-report.md` is a pure generated snapshot, diff it directly against
`$tmp/a.md`. If it contains wrapper text, extract the generated section between
stable markers and diff only that section.

Run a content/privacy scan over changed public docs. It must prove:

- expected sections are present;
- `Dirty worktree: false`, `Auto fetch: false`, `Paths: repo-relative`, and
  `Selected scope: project` are present;
- excluded project-scope prefixes do not appear as result paths, evidence
  headings, co-change paths, or inspect paths;
- no absolute local paths, remote URLs, emails, author/committer labels, commit
  messages, source snippets, private labels, raw private reports, commercial
  strategy, SaaS/pricing/sales content, positive bug-prediction claims,
  positive objective quality/risk claims, maintainer judgement, developer
  ranking, ownership analysis, or productivity claims appear.

Close-out evidence should record command exits, empty diffs, the recorded source
commit, scan result summary, and clean post-commit status. It must not commit or
print raw private reports or temporary absolute paths.
