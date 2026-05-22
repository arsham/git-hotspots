# Feature 0018: Rename-aware file lineage

## Summary

Make file-level hotspot evidence aware of local Git rename edges. When Git emits
an unambiguous rename in the existing history stream, accepted in-scope history
from the old path should aggregate into the canonical current path row instead
of producing duplicate old-path and new-path hotspots.

This feature is deliberately file-level only. It does not infer symbol moves,
semantic ownership, copies, splits, merges, or content similarity beyond Git's
local rename detection.

## Problem

The current engine already runs `git log --numstat --find-renames=40%` and
normalizes rename rows to the newer path. Older commits before the rename can
still aggregate under the old path. This splits evidence for renamed files,
weakens `--inspect current/path`, and makes reports less faithful to Git's own
rename evidence.

## Goals

- Aggregate accepted Git-detected old-path history into the canonical current
  path row.
- Avoid duplicate ranked rows for old paths that are fully absorbed into a
  lineage.
- Preserve deterministic scoring inputs: frequency, churn, recency, co-change,
  size, confidence, caveats, and bounded evidence.
- Expose rename lineage metadata and caveats in a deterministic, privacy-safe
  way.
- Keep scope filters honest so excluded or out-of-include old-path evidence does
  not leak into included current-path reports.

## Non-goals

- Symbol, function, class, or AST-level lineage.
- Tree-sitter, LSP, ctags, provider APIs, or cache.
- Git copy detection, split/merge detection, or content-similarity matching.
- New scoring formulas or predictive claims.
- Commit messages, author metrics, source snippets, diffs, remote calls,
  telemetry, auto-fetch, CI, release packaging, or public third-party case
  studies.

## Semantics

### Rename source

Only local Git rename rows emitted by the existing `git log --numstat
--find-renames=40%` stream may form lineage edges.

The engine must not perform additional similarity scans, contact remotes, inspect
source contents for movement, or infer semantic ownership.

### Canonical path

For an accepted lineage, `result.path` is the canonical path: the newest path
observed for that lineage in the analysed history stream. When that path exists
at HEAD, it is the current file path. If the path no longer exists at HEAD, the
row keeps the existing deleted/not-present caveat and `current_size: null`.

### Scope ordering

Scope filters define the evidence universe.

- Each observed path contribution is eligible only when that observed path
  passes the active `--scope`, `--include-prefix`, and `--exclude-prefix`
  filters.
- A rename edge is accepted only when both old and new paths pass the active
  filters.
- Excludes continue to win over includes.
- Out-of-scope or excluded old-path evidence must not be pulled into an included
  current path.
- When a rename edge is detected but cannot be accepted because of scope, the
  report may disclose a partial-lineage caveat, but must not leak excluded paths
  into result rows, co-change rows, Markdown evidence, or validation summaries.

### Inspect behaviour

- `--inspect current/path` returns the canonical lineage row when present.
- `--inspect old/path` resolves to the canonical lineage row only when `old/path`
  is an accepted in-scope lineage alias.
- Alias inspection preserves `inspect.requested_path = old/path` and sets
  `inspect.matched_path = current/path`.
- If an old path is not an accepted alias in the active scope, inspection fails
  with the existing clear not-found behaviour.

### Co-change behaviour

Co-change evidence should use canonical lineage paths for accepted aliases.
Old/current names for the same accepted lineage must not create self co-changes
or duplicate old/current co-change pairs. Existing co-change count bounds remain
in force.

### Evidence and caveats

Bounded evidence commits remain commit-hash-only and deterministic. Reports must
not include commit messages, authors, source snippets, raw diffs, remote URLs, or
absolute local paths.

Caveats must remain honest when lineage is incomplete because of shallow or
partial history, active scope filters, deleted files, or unsupported rename
forms.

## Output contract

### JSON

JSON output may add lineage metadata to result rows without removing existing
fields. The additive metadata should be deterministic and bounded. Expected
content includes:

- canonical/current path;
- prior accepted paths;
- rename count or accepted edge count;
- a partial/truncated flag or caveat when applicable.

Existing JSON fields must remain present. A breaking schema change requires
re-shaping before implementation.

### Markdown

Markdown output should show lineage details in the row evidence section. It must
escape paths deterministically and avoid raw private output. The wording should
frame lineage as Git rename evidence, not as proof that the same semantic code
entity survived.

### Table

Table output should visibly indicate lineage presence, for example with a compact
lineage marker or caveat. It should not dump noisy alias lists in the table.

## Requirements

- Simple rename `old.txt => new.txt` aggregates old-path and new-path accepted
  history into one canonical row.
- Braced rename syntax such as `src/{old.zig => new.zig}` aggregates correctly.
- Chained rename `a.txt => b.txt => c.txt` collapses into one accepted lineage
  when every edge is in scope.
- Rename plus edit in the same commit counts once for the renamed file and keeps
  the edit churn.
- A renamed file later deleted remains reportable with the existing deleted-file
  caveat when it has enough history to rank or is inspected.
- Accepted old-path aliases do not appear as duplicate ranked rows.
- `--inspect` by current path and by accepted old-path alias both work as
  specified.
- Scope-crossing renames do not leak excluded or out-of-include old-path
  evidence into included canonical paths.
- Default project scope continues excluding `.flow/`; `--scope all` preserves
  full local Git-history evidence.
- Co-change rows use canonical accepted lineage paths, do not self-reference the
  same lineage, and remain deterministic.
- Table, JSON, and Markdown outputs remain deterministic across repeated runs.
- `--progress` remains stderr-only and does not change stdout bytes.
- Shallow, partial, and dirty-worktree caveats remain honest and local-only.

## Edge cases

- Rename rows split across streaming parser chunks.
- CRLF numstat lines.
- Binary rename rows with `-` additions/deletions.
- Git-quoted paths containing tabs, spaces, unicode, or glob-like characters.
- Braced renames with common prefixes and suffixes.
- Scope-crossing renames involving `.flow/`, `src/`, and `vendor/` fixture paths.
- Alias cycles or ambiguous lineage should fail conservatively or avoid
  aggregation; they must not create infinite loops or duplicate rows.

## Verification

Required validation commands:

```sh
zig build test
git diff --check
zig build validate
zig build validate -Dcloseout=true -Dsmoke-repo=<approved-local-repo> -Dsmoke-label=sibling-local-repo
```

Validation must prove:

- fixture coverage for simple, braced, chained, rename-plus-edit,
  deleted-after-rename, and scope-crossing renames;
- inspect current and accepted alias behaviour;
- no duplicate old-path rows for absorbed lineages;
- no excluded paths in result paths, co-change paths, Markdown evidence, or
  validation summaries;
- deterministic table, JSON, and Markdown output;
- JSON validity;
- privacy/prohibited-claim scans;
- real-repo smoke on this repository and `sibling-local-repo` using labels and
  bounded counts only.

Close-out must not commit raw sibling reports, private paths, private repo names,
remotes, authors, commit messages, source snippets, or absolute local paths.
