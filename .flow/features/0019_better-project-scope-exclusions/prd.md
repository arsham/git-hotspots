# Feature 0019: Better project-scope exclusions

## Problem

The default `project` scope is now the first-run experience for `git-hotspots`.
It currently excludes only `.flow/`, which keeps this repository's Flow process
state from dominating reports but leaves other common generated or dependency
output directories to appear when they are tracked in a repository. Users can
exclude those paths explicitly, but first-run project-focused reports should
handle a small set of widely recognised root generated/dependency directories
without introducing dynamic classification or hidden judgement.

## Outcome

`--scope project` uses a finite, deterministic list of root literal built-in
exclude prefixes. The list is disclosed in help, `--explain`, README text, and
report scope metadata. `--scope all` remains the full local Git-history evidence
universe with no built-in project excludes.

Approved project-scope built-in exclude prefixes:

- `.flow/`
- `.zig-cache/`
- `zig-out/`
- `target/`
- `node_modules/`
- `dist/`
- `build/`
- `coverage/`

These are convenience exclusions for project-focused reports, not claims that
excluded files are unimportant or less correct as evidence.

## Requirements

- Omitted `--scope` continues to behave exactly like `--scope project`.
- `--scope project` applies exactly the approved built-in prefix list above.
- Built-in prefixes are repo-root literal prefixes using `/` separators.
- Built-in prefixes are deterministic and ordered as documented.
- Built-in prefixes are deduplicated with user-provided `--exclude-prefix`
  values.
- `--scope all` applies no built-in exclusions and preserves the full local
  tracked-path evidence universe.
- Explicit `--include-prefix` continues to narrow the evidence universe before
  scoring.
- Excludes continue to win over includes, including built-in project excludes.
- Filtering happens before aggregation, scoring, co-change evidence, ranking,
  `--inspect`, progress-compatible rendering, and output limiting.
- Project/default output must not include approved excluded prefixes in result
  paths, co-change paths, inspect matches, lineage aliases, Markdown headings,
  evidence sections, table rows, JSON rows, or validation summaries.
- `--scope all` may include those paths when local Git history contains them.
- `--inspect` of a default-hidden path fails under omitted scope or
  `--scope project` with the existing selected-scope not-found error.
- The same path can be inspected under `--scope all` when it has Git-history
  evidence.
- Rename lineage remains scope-honest: rename edges crossing approved excluded
  prefixes do not leak excluded aliases or evidence into project rows.
- Kept rows affected by scope-crossing rename edges carry the existing partial
  lineage caveat when appropriate.
- Table, JSON, and Markdown reports disclose the effective project prefixes and
  bounded omitted path/change counts.
- Help, README, `--explain`, and fixtures stop saying project scope only
  excludes `.flow/`.
- Documentation states that project scope is a convenience default, not more
  correct than `--scope all`.
- No `.gitignore` import, glob/pathspec/regex support, config files, generated
  file classifiers, vendor/dependency taxonomy, provider work, cache, scoring
  redesign, CI, release packaging, network behaviour, or telemetry behaviour is
  added.

## Edge cases

- Near-miss paths such as `src/build_tool.zig`, `src/vendor_adapter.zig`, and
  `docs/coverage.md` are not excluded by root built-ins.
- A repository whose only changed paths are project-scope excluded paths
  produces an empty successful project-scope report with clear scope metadata,
  not an empty-repository error.
- Repeated explicit `--exclude-prefix` values that duplicate project built-ins
  do not duplicate report metadata.
- `--scope all --exclude-prefix target/` still behaves as an explicit user
  exclusion and remains disclosed as a user/effective prefix.
- `--include-prefix node_modules/` under project scope yields no kept evidence
  because excludes win over includes. `--scope all --include-prefix
  node_modules/` can analyse that subtree.
- Progress output remains stderr-only and stdout reports remain byte-stable.

## Validation

Implementation close-out must include:

- `zig build test`
- `zig build validate`
- `git diff --check`
- close-out validation with this repo and the approved sibling repo labelled
  `sibling-local-repo`

Fixture and golden coverage must prove:

- omitted scope is byte-for-byte equivalent to `--scope project` for table,
  JSON, Markdown, and progress stdout;
- `--scope all` preserves full-evidence behaviour and can show built-in-hidden
  paths when fixtures contain them;
- project scope equals `--scope all` plus the approved explicit exclude-prefix
  list for rows, scores, co-changes, evidence, confidence, caveats, omitted
  counts, and lineage metadata;
- excluded paths do not leak into project results, co-changes, inspect matches,
  lineage aliases, Markdown evidence, table output, JSON output, or validation
  summaries;
- near-miss paths remain included;
- cross-prefix rename cases cover included-to-included, excluded-to-included,
  included-to-excluded, excluded-to-excluded, and a chained rename crossing an
  excluded prefix;
- `--inspect` hidden-path failure under project scope and success under
  `--scope all` when evidence exists;
- help, README, and `--explain` list the approved prefixes and preserve
  investigation-prompt/non-judgemental framing;
- prohibited-claim and privacy scans pass with no hosted, pricing, sales,
  author, remote, absolute private path, raw sibling report, bug-prediction,
  quality-score, or developer-ranking leakage.

## Non-goals

- Do not add new scope modes beyond `all` and `project`.
- Do not add dynamic path classification, `.gitignore` import, config files,
  globs, regexes, pathspecs, or generated-file detection.
- Do not add broad `vendor/`, `third_party/`, `fixtures/`, `docs/`, lockfile,
  `.github/`, or source-tree generated-file exclusions.
- Do not change scoring, Git traversal, rename-lineage truth, report schemas
  beyond existing scope metadata values, provider architecture, cache, CI,
  release packaging, network behaviour, or telemetry behaviour.
