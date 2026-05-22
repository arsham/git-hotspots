# Feature 0012: Default project scope presets

## Summary

Add conservative, explicit scope presets for the file-level hotspot CLI.
The default evidence universe remains all tracked Git-history paths. Users may
opt into a project-oriented preset when they want to suppress known
repo-process noise without typing the equivalent prefix filter.

Chosen CLI surface:

```sh
git-hotspots --scope all
git-hotspots --scope project
```

`--scope all` is the explicit spelling of the current default. `--scope project`
is opt-in and currently expands only to the literal exclude prefix `.flow/`.
The preset is a convenience filter, not hidden quality intelligence.

## Requirements

1. Add an optional `--scope VALUE` analysis flag.
2. The only valid `--scope` values for this feature are lowercase `all` and
   `project`.
3. Unflagged analysis defaults to `all` and preserves the current unfiltered
   evidence universe.
4. `--scope all` must be equivalent to unflagged analysis when no include or
   exclude prefixes are supplied.
5. `--scope project` must be opt-in and must currently expand only to the
   built-in literal exclude prefix `.flow/`.
6. Missing, unknown, repeated, or case-mismatched `--scope` values must fail
   with clear stderr and non-zero exit status.
7. Scope presets must combine with existing repeatable `--include-prefix` and
   `--exclude-prefix` flags.
8. Includes narrow the candidate universe. Preset excludes and explicit excludes
   remove paths. Excludes win over includes regardless of flag order.
9. If a preset exclude and an explicit exclude name the same prefix, results
   must remain deterministic and equivalent to applying that prefix once.
10. Prefix semantics remain literal repo-relative Git path prefixes using `/`
    separators. Presets do not add globs, pathspecs, gitignore rules, regexes,
    generated-file detection, vendor detection, or project configuration.
11. Scope filtering must happen before aggregation, scoring, co-change evidence,
    ranking, limiting, and inspect selection.
12. The selected scope and effective prefixes must be disclosed in table, JSON,
    and Markdown output.
13. JSON scope metadata must include the selected scope, effective include
    prefixes, effective exclude prefixes, `filters_active`, outside-include
    path and change counts, and excluded path and change counts.
14. Table output must include a compact scope line when the selected scope is
    not `all` or any include or exclude filters are active.
15. Markdown output must include selected scope and effective prefixes in the
    `Scope` section.
16. Reports must not emit raw omitted path lists. They may emit effective
    prefixes and bounded omitted counts.
17. `--scope project` output must not leak `.flow/` paths into result paths,
    co-change paths, Markdown hotspot rows, Markdown evidence or co-change
    lines, table rows, or inspect matches.
18. `--scope project` must be equivalent to `--exclude-prefix .flow/` for result
    rows, co-change evidence, score breakdown, confidence, caveats, and bounded
    evidence commits.
19. `--scope all --inspect PATH` must be able to inspect a `.flow/` path when
    that path has Git-history evidence.
20. `--scope project --inspect PATH` for the same `.flow/` path must fail
    generically as having no matching Git-history evidence in the selected
    scope.
21. `--limit` remains incompatible with `--inspect`.
22. Existing no-scope table, JSON, Markdown, prefix-filter, inspect, `--explain`,
    `--version`, and help behaviours must remain stable except intentional
    additive scope metadata, help, docs, and golden fixture updates.
23. No scoring formula, tie-break, confidence threshold, Git traversal, network,
    telemetry, provider, cache, author metric, source-content, CI, release, or
    packaging behaviour may change.
24. Help, README, and `--explain` must describe scope presets as deterministic
    convenience filters that change the evidence universe.
25. Public docs must not imply bug prediction, objective code-quality scoring,
    developer ranking, generated-code detection, hidden project intelligence,
    hosted services, or commercial plans.

## Acceptance

- `git-hotspots --help` documents `--scope all|project`.
- Unflagged output and `--scope all` output are equivalent for the same repo,
  range, explicit filters, and format.
- `--scope project` currently discloses `.flow/` as an effective exclude prefix.
- `--scope project` excludes `.flow/` before aggregation, scoring, co-change
  evidence, limiting, and inspect selection.
- Fixture tests prove `--scope project` is equivalent to explicit
  `--exclude-prefix .flow/` for JSON result rows and co-change evidence.
- Table, JSON, and Markdown reports disclose the selected scope and effective
  prefixes without listing raw omitted paths.
- Inspect tests prove included targets remain inspectable, project-excluded
  targets fail generically, and `--scope all` can inspect the same target when
  evidence exists.
- Unknown, missing, repeated, and case-mismatched scope values fail clearly.
- Explicit include and exclude prefixes combine with scope presets, with
  excludes winning regardless of flag order.
- Existing prefix semantics remain literal and do not behave like globs,
  pathspecs, gitignore rules, regexes, or generated-file detection.
- `zig build validate` covers scope preset parsing, fixture goldens,
  determinism, JSON validity, Markdown semantic checks, privacy scans, inspect
  interactions, this-repo smoke, and close-out sibling smoke.

## Edge cases

- `--scope` is missing a value.
- `--scope` is repeated.
- `--scope Project`, `--scope PROJECT`, and other case variants are rejected.
- `--scope unknown` is rejected.
- `--scope project --exclude-prefix .flow/` does not double-count or otherwise
  change results compared with a single effective `.flow/` exclusion.
- `--scope project --include-prefix .flow/` yields no `.flow/` results because
  excludes win over includes.
- `--scope project --include-prefix src/` narrows to source paths and still
  records `.flow/` as an effective project exclusion.
- `--scope all --exclude-prefix .flow/` remains equivalent to explicit
  exclusion without a preset.
- `.flowish/` or `src/.flow_adapter.zig` must not be excluded by the `.flow/`
  literal prefix.
- Git rename normalization, quoted tab paths, unicode paths, spaces, deleted
  paths, binary churn, large commits, shallow history, partial history, dirty
  worktrees, detached heads, and linked worktrees continue to behave as before.
- Empty scoped results remain successful reports with clear scope metadata.

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
./zig-out/bin/git-hotspots --repo fixtures/scope --scope all --format json
./zig-out/bin/git-hotspots --repo fixtures/scope --scope project --format json
./zig-out/bin/git-hotspots --repo fixtures/scope --scope project --format markdown
./zig-out/bin/git-hotspots --repo fixtures/scope --scope project --format table
./zig-out/bin/git-hotspots --repo fixtures/scope --scope project --inspect src/vendor_adapter.zig --format json
./zig-out/bin/git-hotspots --repo fixtures/scope --scope all --inspect .flow/config.yml --format json
```

Validation must compare `--scope project` with explicit
`--exclude-prefix .flow/` for result and co-change parity.

Close-out validation must use the existing privacy-safe real-repo workflow:

```sh
zig build validate -Dcloseout=true -Dsmoke-repo=<operator-provided-local-repo> -Dsmoke-label=sibling-local-repo
```

If the sibling repo is unavailable, use only an explicit approved safe skip
reason. Do not commit private repo paths, private repo names, raw private
reports, remotes, author identities, commit messages, or source snippets.

## Non-goals

- No hidden default filtering in this feature.
- No broad generated, vendor, build, coverage, dependency, or ecosystem preset
  taxonomy.
- No `.gitignore` import.
- No globs, pathspecs, regexes, or query language.
- No config files or persisted project preferences.
- No scoring, confidence, ranking, Git traversal, co-change, or recency changes.
- No tree-sitter, LSP, ctags, dependency, blame, test, or coverage providers.
- No cache or database work.
- No source snippets, diffs, commit messages, author identities, ownership,
  developer metrics, or productivity analytics.
- No network, fetch, upload, telemetry, remote enrichment, CI, release,
  package, hosted-product, or commercial planning work.
