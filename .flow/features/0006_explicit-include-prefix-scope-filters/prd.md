# Feature 0006: Explicit include-prefix scope filters

## Purpose

Add an explicit include-prefix scope control so users can focus hotspot reports
on a chosen subtree without introducing hidden defaults, globs, config files, or
provider-based classification.

The current CLI supports explicit `--exclude-prefix` filters. That is useful for
removing known noisy workflow paths, but users also need the inverse operation:
only analyse a selected repo-relative area such as `src/` or `tests/`.

## Requirements

- The CLI must accept repeatable `--include-prefix PATH` flags.
- Include prefixes must use the same validation contract as exclude prefixes:
  repo-relative Git path prefixes, `/` separators, literal prefix matching, no
  empty value, no absolute path, no Windows drive absolute path, no leading
  backslash, no `..` segment, and no control characters.
- With no include prefixes and no exclude prefixes, default output must remain
  unfiltered and preserve existing all-tracked-path behaviour.
- Effective scope must be independent of flag order:
  - if no include prefixes are supplied, every repo-relative path is initially
    a candidate;
  - if include prefixes are supplied, a path must match at least one include
    prefix to be a candidate;
  - exclude prefixes remove matching paths from that candidate set;
  - exclude wins when a path matches both include and exclude prefixes.
- Filtering must happen before aggregation, scoring, co-change expansion,
  result limiting, table output, JSON output, and Markdown output.
- Paths outside the include scope must not appear in result rows, co-change
  rows, Markdown evidence sections, or validation summaries.
- Excluded paths must continue to be absent from result rows, co-change rows,
  Markdown evidence sections, and validation summaries.
- JSON `analysis.scope` must preserve existing fields and add deterministic
  include metadata, including `include_prefixes` and counts for paths/changes
  omitted by include scope.
- Table output must disclose active include and exclude prefixes with bounded
  scope counts when filters are active.
- Markdown `## Scope` must disclose active include and exclude prefixes with
  bounded scope counts when filters are active.
- Empty include-scoped reports must exit successfully and remain explainable in
  table, JSON, and Markdown.
- Repeated include prefixes are OR; repeated exclude prefixes are OR.
- Literal prefix semantics must be documented; `glob/*` must not act as a glob.
- Prefix matching must use normalized Git paths already handled by the current
  numstat parser, including braced renames and Git-quoted paths.
- Existing `--exclude-prefix` behaviour and existing exclude-only golden outputs
  must remain stable unless intentional additive scope metadata is required.
- Existing JSON/table/Markdown format contracts must remain deterministic.
- README and help text must describe include prefixes as explicit literal
  repo-relative filters and must say scoped reports change the evidence
  universe.
- The feature must not add default scopes, default include/exclude policy,
  globs, pathspecs, regex, `.gitignore` import, config files, provider/cache
  work, network access, telemetry, author metrics, release/CI automation,
  hosted/commercial content, bug prediction, quality scoring, or developer
  ranking.

## Acceptance

- `git-hotspots --include-prefix src/` analyses only `src/**` paths and only
  `src/**` co-change evidence.
- `git-hotspots --include-prefix src/ --include-prefix vendor/` analyses paths
  matching either prefix.
- `git-hotspots --include-prefix src/ --exclude-prefix src/vendor_adapter.zig`
  omits `src/vendor_adapter.zig`; exclude wins over include.
- `git-hotspots --include-prefix does-not-exist/` succeeds with an empty scoped
  report in table, JSON, and Markdown.
- `git-hotspots --include-prefix 'glob/*'` treats `*` literally and does not
  match `glob/[literal]*.txt`; `--include-prefix glob/` does match that path.
- Invalid include prefixes fail clearly on stderr without panic.
- Scope metadata in table, JSON, and Markdown includes include prefixes,
  exclude prefixes, active state, and bounded counts.
- Validation proves include filtering happens before co-change scoring by
  asserting that out-of-include paths are absent from result and co-change
  fields.
- `zig build validate` covers include-only, repeated include, include+exclude,
  empty include, literal-glob, rename normalization, quoted-tab normalization,
  and real-repo smoke.
- The README remains visitor-facing and OSS-safe.

## Edge cases

- Missing `--include-prefix` value.
- Empty prefix.
- POSIX absolute path.
- Windows drive absolute path.
- Leading backslash path.
- Prefix containing a `..` segment.
- Prefix containing control characters.
- Path containing spaces, unicode, tab escapes, brackets, and glob-like
  characters.
- Braced rename numstat paths.
- Git-quoted paths.
- Include prefix with no matching changes in the selected range.
- Include and exclude both matching the same path.
- `--since` range where only out-of-include paths changed.
- Dirty worktree caveat remains independent of include filters.

## Verification

Required validation commands:

```sh
zig fmt --check build.zig src tests
zig build test
zig build validate
git diff --check
flow validate --target feature:0006 --format json
```

Close-out validation must include either:

```sh
zig build validate -Dcloseout=true -Dsmoke-repo=<local-repo> -Dsmoke-label=<safe-label>
```

or a privacy-safe explicit skip reason.

Real-repo smoke must include this repo with `--include-prefix src/` in table,
JSON, and Markdown. Evidence summaries must use labels and bounded counts only;
no absolute paths, raw private reports, author identities, remotes, or private
repo names may be committed.

## Packet plan

### P1: End-to-end include-prefix runtime scope

Implement repeatable `--include-prefix PATH` across CLI parsing, config/model,
Git analysis filtering, and table/JSON/Markdown scope metadata.

Anchors:

- `src/main.zig`
- `src/model.zig`
- `src/git.zig`
- `src/report.zig`
- `tests/integration.sh`
- `tools/setup-fixtures.sh`
- `fixtures/expected/*`

Validation:

- `zig fmt --check build.zig src tests`
- `zig build test`
- targeted fixture commands for include-only, repeated include, include+exclude,
  invalid include prefixes, literal glob semantics, and empty scope

Review focus:

- include filtering happens before aggregation and co-change expansion;
- exclude wins over include;
- default unfiltered behaviour and exclude-only behaviour do not regress;
- scope metadata is deterministic and privacy-safe.

Escalate if implementation requires globs, pathspecs, config files, default
scopes, provider/cache work, or scoring formula changes.

### P2: Validation and public docs hardening

Extend canonical validation, real-repo smoke, and README/help documentation for
include-prefix scope controls.

Anchors:

- `README.md`
- `tools/validate.sh`
- `tests/integration.sh`
- `fixtures/expected/*`

Validation:

- `zig build validate`
- close-out validation mode with sibling repo or explicit privacy-safe skip
  reason
- `git diff --check`
- `flow validate --target feature:0006 --format json`

Review focus:

- docs explain literal repo-relative include/exclude prefixes without implying
  globs, defaults, generated-file detection, provider analysis, or hidden truth;
- validation summaries remain privacy-safe;
- public wording keeps hotspots as investigation prompts.

Escalate if validation needs private artefacts, network/fetch behaviour, raw
omitted path dumps, or new dependencies.
