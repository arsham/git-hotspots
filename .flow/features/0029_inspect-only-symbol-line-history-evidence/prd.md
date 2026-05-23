# Feature 0029: Inspect-only symbol line-history evidence

## Summary

Add a narrow opt-in current-line Git evidence layer for inspected Zig symbols.
The feature extends the existing inspect-only symbol path with a separate flag:

```sh
git-hotspots --inspect PATH --symbols --symbol-line-history
```

The evidence is current-line Git evidence for current Tree-sitter symbol ranges.
It is not historical symbol lineage, not function move tracking, not a symbol
score, and not a replacement for file-level Git-history evidence.

## Problem

Feature 0028 can show current Zig function symbols for one inspected hot file,
but it does not yet answer whether the current lines inside those symbols carry
Git change evidence. Users still have to manually connect current symbols to the
file's historical pressure.

We want to provide a small bridge from current symbols to Git evidence without
claiming true symbol history. The old Rust experiment's function-history path
was expensive and semantically risky; this feature must avoid recreating that
trap.

## Goals

- Add a separate opt-in flag, `--symbol-line-history`, valid only with
  `--inspect PATH --symbols`.
- Compute current-line Git evidence for current Tree-sitter Zig function ranges
  in the inspected matched file.
- Preserve existing file-level Git scoring, ranking, confidence, co-change,
  rename-lineage, scope, and inspect semantics.
- Preserve default output and plain `--symbols` output byte-for-byte unless the
  new flag is present.
- Keep output privacy-safe: no authors, emails, commit messages, source
  snippets, raw diffs, raw blame output, remotes, private repo names, or
  absolute local paths.
- Clearly label the evidence as current-line Git evidence, not symbol history or
  symbol lineage.

## Non-goals

- No `git log -L`.
- No historical symbol lineage, function move tracking, symbol rename tracking,
  split/merge tracking, or semantic ownership.
- No symbol score, rank, quality rating, bug prediction, risk prediction,
  developer ranking, ownership analytics, productivity analytics, or technical
  debt score.
- No authors, emails, committer identities, commit messages, source snippets,
  raw diffs, raw blame output, previous filenames, remotes, private repo names,
  or absolute local paths in output or committed evidence.
- No default provider execution.
- No all-files provider execution.
- No cache, network, telemetry, upload, remote enrichment, parser generation,
  multi-language support, LSP, ctags, or provider registry expansion.
- No change to file-level scoring, ranking, scope filtering, co-change,
  confidence, or rename-lineage semantics.

## User interface

Add:

```text
--symbol-line-history
```

Rules:

- Valid only when `--inspect PATH` and `--symbols` are both present.
- Without `--inspect`, exit non-zero with deterministic stderr.
- Without `--symbols`, exit non-zero with deterministic stderr.
- Invalid with `--explain` and `--version` through the existing analysis-flag
  combination rules.
- Does not change normal `--symbols` output unless explicitly requested.

Recommended help wording:

```text
--symbol-line-history
                    With --inspect PATH --symbols only, add current-line Git
                    evidence for current Zig symbol ranges; not symbol history
                    or lineage and does not affect file score or rank
```

## Evidence semantics

The evidence basis is:

```text
matched inspect path + current Tree-sitter one-based inclusive symbol line range
```

For a clean, supported current `.zig` file, run one bounded local Git blame over
the inspected matched file and aggregate the result-line blame spans into each
current symbol range.

Preferred Git command family:

```sh
git blame --incremental -- <matched-path>
```

Implementation must parse only whitelisted data:

- commit object id from the incremental blame range header;
- result line start and span length from the incremental blame range header;
- numeric timestamp if needed from an approved timestamp-only field such as
  `author-time`.

Implementation must discard and never persist, log, render, or commit:

- `author`, `author-mail`, `committer`, `committer-mail`;
- `summary`;
- `filename` when it would expose prior paths;
- source lines;
- raw stdout or stderr.

The output should include bounded per-symbol evidence such as:

- `basis`: `current-line-range-at-head`;
- `current_only`: `true`;
- `line_count`;
- `distinct_last_touch_commit_count`;
- `most_recent_line_touched_timestamp` or `null`;
- `uncommitted_or_unblamable_line_count`;
- bounded `sample_commits` or equivalent commit-id evidence, capped and sorted
  deterministically;
- `failure`, `freshness`, `confidence`, and `caveats` for the line-history
  evidence.

Commit ids are allowed as deterministic local Git evidence. They must be bounded
and must not be accompanied by authors, messages, remotes, paths, or snippets.

## Dirty, shallow, partial, and degraded behaviour

Current symbol ranges come from the working tree. Git blame evidence comes from
local Git history. That can become ambiguous when the inspected file is dirty or
when history is incomplete.

Required behaviour:

- If the inspected matched file has staged or unstaged content changes, preserve
  file evidence and symbol evidence but degrade current-line Git evidence with a
  caveat instead of inventing pseudo-commit identities.
- Dirty unrelated files must not disable line-history evidence for the inspected
  file, although global dirty-worktree caveats may still exist.
- If the file is missing, symlinked, non-regular, too large, unsupported,
  invalid in a way that prevents symbol ranges, or provider evidence is not ok,
  preserve inspected file evidence and existing symbol/provider caveats; do not
  run blame without valid current symbol ranges.
- If the repository is shallow or partial, line-history output must disclose that
  evidence may be incomplete. Partial clone behaviour must not auto-fetch.
- If blame fails, times out, exceeds a bounded output budget, or emits data that
  cannot be parsed safely, preserve inspected file and symbol evidence and show
  line-history failure caveats.
- Inspect aliases resolve through existing `inspect.matched_path`; line-history
  evidence uses the matched current file path only and must not expose previous
  filenames or imply symbol lineage.

## Output contract

### JSON

When `--symbol-line-history` is present, each symbol item should include an
additive child such as:

```json
"current_line_history": {
  "basis": "current-line-range-at-head",
  "current_only": true,
  "line_count": 3,
  "distinct_last_touch_commit_count": 2,
  "most_recent_line_touched_timestamp": 1710000000,
  "uncommitted_or_unblamable_line_count": 0,
  "sample_commits": ["abc123..."],
  "freshness": "fresh",
  "failure": "ok",
  "confidence": "medium",
  "caveats": []
}
```

The exact field order should be deterministic and documented by fixtures.

When line-history evidence is unavailable or skipped, the JSON child should be
present with failure/caveats rather than omitting the state silently, as long as
`--symbol-line-history` was requested.

### Table

Table output should add a compact symbol line-history column or detail line only
inside the existing symbol section. It must state that this is current-line Git
evidence and does not affect file ranking.

### Markdown

Markdown should add a compact current-line Git evidence section or columns under
`## Symbols`. It must state that this is current-line evidence only, not symbol
history or lineage.

## Requirements

- `--symbol-line-history` is accepted only with `--inspect PATH --symbols`.
- Existing `--inspect`, `--symbols`, `--scope`, include/exclude, rename alias,
  and progress semantics remain unchanged unless the new flag is present.
- Plain `--symbols` table, JSON, and Markdown outputs remain byte-stable unless
  the new flag is present.
- Default reports and plain inspect reports remain byte-stable.
- Line-history evidence is computed only for the inspected matched in-scope Zig
  file.
- The implementation runs at most one blame process for the inspected matched
  file, not one blame process per symbol.
- Blame parsing uses a whitelist parser and never emits or records raw blame
  data.
- Output never includes authors, emails, commit messages, source snippets, raw
  diffs, raw blame output, previous filenames, absolute paths, remotes, private
  repo names, ownership/productivity analytics, or developer ranking.
- File score, rank, confidence, co-change, lineage, scope, and caveats remain
  file-level Git evidence and are not modified by line-history evidence.
- Current-line evidence carries visible caveats and evidence-quality confidence.
- Dirty inspected files degrade rather than inventing pseudo-commit identities.
- Partial or shallow history is disclosed.
- Unsupported/degraded cases preserve inspected file evidence.

## Acceptance

- `git-hotspots --inspect PATH --symbols --symbol-line-history` works for a
  supported clean in-scope `.zig` fixture and emits deterministic current-line
  Git evidence for each supported current function symbol.
- `--symbol-line-history` without `--inspect PATH` exits non-zero with stable
  stderr.
- `--symbol-line-history` without `--symbols` exits non-zero with stable stderr.
- Plain `--symbols` outputs stay byte-for-byte stable.
- Default, table, JSON, Markdown, and plain inspect outputs stay byte-for-byte
  stable when the new flag is absent.
- JSON output includes current-line history under each symbol item when the new
  flag is present.
- Table and Markdown output disclose current-line Git evidence without implying
  symbol history, ranking, quality, risk, ownership, or lineage.
- Fixture coverage proves distinct current function ranges, lines touched by
  different commits, lines touched by the same commit, lines outside symbols,
  shifted line numbers, and deterministic ordering.
- Degraded fixtures cover unsupported non-Zig files, empty Zig files,
  invalid/partial Zig, symlink/non-regular or missing current files, no
  supported symbols, dirty inspected file, dirty unrelated file, and inspect
  alias resolution.
- Validation proves no author, email, commit message, source snippet, raw diff,
  raw blame output, absolute path, remote, private repo name, or raw private
  report is emitted.
- Close-out validation passes on this repo and `sibling-local-repo` with
  privacy-safe label-only evidence.

## Edge cases

- Symbol range has zero lines: degrade with caveat; do not panic.
- Symbol range exceeds blame result line count: count affected lines as
  unblamable and add caveat.
- File is clean but repository has unrelated dirty files: line-history evidence
  may still run for the clean inspected file.
- File is dirty: skip or degrade line-history evidence for that file while
  preserving symbol and file evidence.
- Repository is shallow or partial: disclose incomplete evidence and avoid
  auto-fetch.
- Blame process exits non-zero: preserve file and symbol evidence and report
  line-history failure caveats.
- Blame output contains unexpected fields: ignore unapproved fields; if required
  whitelisted fields are missing, degrade safely.
- Commit id ordering ties: sort deterministically by timestamp descending, then
  commit id ascending, or another documented deterministic order.

## Verification

Required commands:

```sh
zig fmt --check build.zig src tests
zig build test
zig build
zig build validate
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
git diff --check
zig build validate -Dcloseout=true -Dsmoke-repo=<operator-provided-local-repo> -Dsmoke-label=sibling-local-repo
```

Validation must include:

- JSON, Markdown, and table golden fixtures for successful line-history output.
- Golden or semantic checks for unsupported/degraded states.
- Byte-stability checks for no-provider, plain inspect, and plain `--symbols`
  outputs when `--symbol-line-history` is absent.
- Determinism checks by running the same line-history command twice and diffing.
- Privacy/prohibited-claim scans extended to line-history docs and goldens.
- Real-repository smoke for this repo and `sibling-local-repo`, with no raw
  sibling reports or private paths committed.

## Documentation updates

Update README/help/explain/validation summary only as needed to document:

- `--symbol-line-history` is separate opt-in evidence;
- it requires `--inspect PATH --symbols`;
- evidence is current-line Git evidence for current symbol ranges;
- it is not symbol history, lineage, scoring, ranking, ownership, bug
  prediction, or code-quality assessment;
- file-level Git evidence remains product truth.
