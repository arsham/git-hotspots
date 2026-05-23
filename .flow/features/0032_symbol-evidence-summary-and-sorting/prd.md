# Feature 0032: Symbol evidence summary and sorting

## Problem

Inspect-only symbol reports are now useful but too verbose for large Zig files.
A real repository inspect run produced dozens of symbols, and the high-signal
current-line Git evidence was buried in the full current-symbol list.

The tool needs a clearer human-readable symbol summary without turning symbols
into a new score, rank, risk, quality, ownership, or historical-lineage system.

## Outcome

Human table and Markdown output for:

```sh
git-hotspots --inspect PATH --symbols --symbol-line-history
```

shows a deterministic summary-first symbol view. Human rows are ordered by
existing current-line Git evidence fields and capped by a human display limit.
The report discloses total, shown, omitted, and the sort basis.

JSON remains complete and deterministic. `symbols.items` is not truncated by the
human display cap or `--symbol-limit`.

## Requirements

- Add a human symbol summary layer only for inspect symbol output.
- Apply evidence-based human ordering only when `--symbol-line-history` is
  present.
- Human ordering must use existing fields only:
  1. distinct current-line commit count descending;
  2. most recent line touched timestamp descending;
  3. line count descending;
  4. deterministic symbol name, range, and provider tie-breakers.
- Add a default human display cap for symbol rows, initially 25.
- Add an opt-in human display cap flag:

  ```sh
  --symbol-limit N
  ```

- `--symbol-limit` is valid only with `--inspect PATH --symbols`.
- `--symbol-limit` affects human table and Markdown symbol row display only.
- JSON must continue to include every symbol in `symbols.items`, regardless of
  `--symbol-limit`.
- JSON may add metadata such as total symbol count, human shown count, omitted
  count, human default limit, and human sort basis, but must not remove or
  truncate existing `symbols.items` fields.
- Human output must disclose:
  - total symbols;
  - shown symbols;
  - omitted symbols;
  - whether a default or explicit human limit was used;
  - sort basis.
- Use wording such as "shown first by current-line Git evidence summary".
- Avoid wording that implies symbol ranking, scoring, risk, code quality,
  ownership, productivity, or bug prediction.
- Plain `--symbols` without `--symbol-line-history` may use existing provider
  order and should still disclose total/shown/omitted if capped.
- Existing non-symbol reports, plain inspect reports, and default reports must
  remain byte-stable unless the feature explicitly updates relevant goldens.

## Non-goals

- No symbol scoring.
- No symbol ranking language.
- No symbol hotness claim.
- No symbol history or lineage claim.
- No `git log -L`.
- No author names, emails, commit messages, source snippets, raw blame, raw
  diffs, remotes, private paths, ownership, or productivity analytics.
- No provider execution outside `--inspect PATH --symbols`.
- No default provider execution.
- No all-file or repository-wide symbol analysis.
- No report changes for non-symbol commands.
- No cache, network, telemetry, release, or package work.

## Edge cases

- More symbols than the default human display cap.
- Exactly the default human display cap.
- Fewer symbols than the cap.
- Zero symbols.
- Unsupported non-Zig files.
- Invalid or partial Zig files.
- Symlink or non-regular `.zig` paths.
- Symbols with identical evidence counts.
- Multiline symbols.
- Markdown-sensitive and unicode symbol names.
- Symbols with current-line evidence failures or caveats.
- `--symbol-limit` with JSON output.
- Invalid `--symbol-limit` values.
- `--symbol-limit` without `--symbols`.

## Verification

- Add or update unit tests for symbol display metadata, human limit parsing, and
  deterministic human ordering.
- Add table and Markdown goldens for symbol summary display with default and
  explicit human limit behaviour.
- Add JSON validation proving `symbols.items` remains complete when
  `--symbol-limit` is supplied.
- Add deterministic repeated-output checks for affected commands.
- Preserve existing no-provider, default, plain inspect, and plain JSON output
  behaviour where the new flags are absent.
- Extend privacy/prohibited-claim scans to new docs and goldens.
- Run:

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

- Close-out evidence must use privacy-safe labels and bounded counts only.
