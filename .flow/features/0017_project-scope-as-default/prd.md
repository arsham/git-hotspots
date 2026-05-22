# Feature 0017: Project scope as default

## Summary

Change the default evidence universe for unflagged `git-hotspots` analysis from
`all` to `project` during the public alpha. The `project` preset currently
excludes only the literal `.flow/` prefix before aggregation, scoring, ranking,
co-change evidence, inspect selection, and report rendering. Explicit
`--scope all` remains the full local Git-history evidence escape hatch and must
preserve the old default behaviour.

This is an intentional alpha default change. It reverses the earlier Feature
0012 decision that kept `project` opt-in, based on later real-repo evidence and
public-demo experience showing that workflow/process metadata can dominate the
first-run report. The change must be plainly disclosed in help, README, explain
text, and report scope metadata. It must not imply that `project` is more
correct than full local Git evidence; it is a more useful default starting point.

## Goals

- Make an omitted `--scope` behave exactly like `--scope project`.
- Keep `--scope all` as the explicit way to analyse all tracked Git-history
  paths, including `.flow/`.
- Keep the current project preset narrow: it excludes only `.flow/`.
- Preserve all scoring, ranking, confidence, caveat, co-change, prefix, inspect,
  progress, history, and rendering semantics apart from the changed default
  scope.
- Keep table, JSON, and Markdown reports transparent about selected scope,
  effective include/exclude prefixes, omitted counts, and caveats.
- Update docs and validation so the alpha default is impossible to miss.

## Non-goals

- Do not add new project preset exclusions such as `zig-out/`, `target/`,
  `node_modules/`, `dist/`, `build/`, or `coverage/`.
- Do not add path classifiers, gitignore import, pathspec/glob/regex support,
  config files, stored preferences, migration warnings, telemetry, or usage
  analytics.
- Do not change scoring formulas, ranking, confidence thresholds, co-change
  calculation, history traversal, inspect matching, report schemas except for
  existing scope metadata values, or progress behaviour.
- Do not add cache, providers, network behaviour, CI, release packaging, hosted
  product content, commercial strategy, bug-prediction claims, code-quality
  claims, or developer-ranking claims.

## Requirements

### Default scope semantics

- Unflagged analysis must set `analysis.scope.selected_scope` to `project`.
- Unflagged analysis must apply the same effective exclude prefixes as explicit
  `--scope project`, currently exactly `.flow/`.
- Explicit `--scope project` must remain accepted and equivalent to unflagged
  analysis, including effective prefixes and report rows.
- Explicit `--scope all` must remain accepted and must have no built-in project
  excludes.
- Invalid, missing, repeated, and case-mismatched `--scope` values must keep the
  existing error behaviour.
- Existing `--include-prefix` and `--exclude-prefix` semantics remain literal,
  repo-relative, order-independent, and non-glob.
- Excludes continue to win over includes, including default/project `.flow/`
  exclusion versus `--include-prefix .flow/`.

### Output behaviour

- Table output must continue to include a scope line that makes the selected
  scope and effective prefixes visible.
- JSON output must keep the existing `analysis.scope` shape while reporting the
  new default selected scope and effective prefixes.
- Markdown output must keep the existing Scope section while reporting the new
  default selected scope and effective prefixes.
- Unflagged default reports must not include `.flow/` result paths or `.flow/`
  co-change paths.
- Explicit `--scope all` reports on fixtures with `.flow/` history must preserve
  the old full-evidence output, including `.flow/` paths when they rank.
- Reports must not emit raw omitted path lists; bounded omitted counts and
  effective prefixes are allowed.

### Inspect and option interactions

- Unflagged `--inspect .flow/...` must fail with the existing generic selected
  scope no-match error because `.flow/` is excluded by default.
- Explicit `--scope all --inspect .flow/...` must succeed when the path has Git
  history evidence.
- Unflagged inspect of in-scope paths must select from the same ranked evidence
  universe as `--scope project`.
- `--since` valid and invalid behaviour must remain unchanged under unflagged
  project scope and explicit `--scope all`.
- `--progress` must remain opt-in, stderr-only, privacy-safe, and must not
  change stdout for table, JSON, Markdown, or inspect.
- `--explain`, `--version`, and `--help` remain standalone surfaces and must not
  analyse a repository.

### Documentation and explain text

- Help text must say project scope is the default and that `--scope all` restores
  full local Git-history evidence.
- README usage and large-repo recipes must reflect the new default.
- Explain text must describe project scope as the default evidence universe and
  all scope as the explicit full-evidence mode.
- Docs must keep framing hotspots as investigation prompts, not bug predictions,
  quality scores, developer rankings, or maintainer judgement.

### Validation and evidence

- Unit tests must prove default project scope, explicit all scope, explicit
  project scope, invalid scope behaviour, and prefix interaction behaviour.
- Fixture/golden tests must prove unflagged output equals explicit
  `--scope project` for table, JSON, Markdown, inspect where applicable, and
  progress stdout.
- Fixture/golden tests must preserve an explicit `--scope all` old-default
  output for a fixture containing `.flow/` paths.
- Determinism checks must pass for table, JSON, Markdown, inspect, and progress
  stdout.
- Close-out validation must run the standard validation ladder and real-repo
  smoke on this repo plus the approved sibling local repo with the label
  `sibling-local-repo`.
- Real-repo smoke evidence must be privacy-safe: labels, bounded counts, command
  shapes, elapsed times, caveats, and pass/fail status only. Do not commit raw
  sibling reports, actual sibling path, private repo name, remotes, authors,
  commit messages, or source snippets.

## Edge cases

- `git-hotspots --scope all --include-prefix .flow/` should analyse only `.flow/`
  paths when they match and should not inherit project exclusions.
- `git-hotspots --include-prefix .flow/` under the new default should return no
  matching results when `.flow/` is excluded by project scope, with excludes
  winning over includes.
- Duplicate `.flow/` exclusions from default/project scope plus explicit
  `--exclude-prefix .flow/` must not duplicate metadata or change rows.
- Empty default/project scoped results remain successful explainable reports.
- Shallow/partial/dirty-worktree caveats remain unchanged.

## Packet plan

### P1 - Default contract switch

- Anchors: `src/model.zig`, `src/main.zig`.
- In scope: make unflagged analysis default to `project`; keep `--scope all` as
  explicit full evidence; update parser/unit tests and error/help text.
- Out of scope: new exclusions, config/default preference storage, scoring,
  providers, cache, CI, release packaging.
- Protected: literal prefix validation, excludes-win precedence, inspect timing,
  local-first/no-network behaviour, standalone `--explain` and `--version`.
- Dependencies: Feature 0012 scope preset semantics and Feature 0016 streaming
  semantics remain intact.
- Validation/evidence: unit tests for default project, explicit all, explicit
  project, invalid/missing/repeated/case-mismatched scope, duplicate excludes,
  include/exclude interactions.
- Review focus: the default change is intentional, minimal, disclosed, and
  limited to `.flow/` exclusion.
- Escalate if: the change requires broad project classifiers, gitignore import,
  generated/vendor taxonomies, scoring changes, schema changes, or hidden
  config.
- Done boundary: CLI parse/config state correctly represents new default and
  old full-evidence behaviour remains reachable with `--scope all`.

### P2 - Output parity and fixture update

- Anchors: `tests/integration.sh`, `tools/validate.sh`, `fixtures/expected/*`,
  `src/report.zig`, `src/model.zig` if metadata wording requires it.
- In scope: update goldens and assertions so unflagged output equals explicit
  `--scope project`; keep explicit `--scope all` parity with old unflagged
  evidence; prove inspect/progress/since/prefix interactions.
- Out of scope: report schema additions, raw omitted path lists, timing fields,
  new public benchmark claims.
- Protected: table/JSON/Markdown schema stability, deterministic ordering,
  scoring values except changed evidence universe, co-change filtering, privacy.
- Dependencies: P1 default contract switch.
- Validation/evidence: fixture diffs, repeated deterministic runs, progress
  stdout/stderr separation, explicit all fixture with `.flow/` evidence,
  default/project no `.flow/` result or co-change leakage.
- Review focus: compatibility escape hatch works; default/project equivalence is
  exact except intentional metadata where applicable.
- Escalate if: fixture parity cannot be proven, explicit all cannot preserve old
  evidence, or default/project leaks excluded paths.
- Done boundary: all existing validation paths agree with the new default
  contract.

### P3 - Docs and close-out validation

- Anchors: `README.md`, `src/explain.zig`, `tools/validate.sh`, validation
  output, real-repo smoke evidence.
- In scope: update public docs/help/explain references to the new default;
  update validation summaries and run standard plus close-out validation.
- Out of scope: new release, CI, screenshots, public third-party case study,
  provider/cache features.
- Protected: OSS/publicity boundary, investigation-prompt framing,
  no-commercial-content rule, no bug-prediction or developer-ranking language.
- Dependencies: P1 and P2 complete.
- Validation/evidence: `zig build test`, `zig build validate`, `git diff
  --check`, close-out validation with `sibling-local-repo`, privacy/prohibited
  scans over changed docs.
- Review focus: public docs plainly disclose default project scope and explicit
  all scope without overclaiming correctness.
- Escalate if: docs imply scoped reports are more correct than full Git history,
  expose private sibling evidence, or introduce unsupported roadmap/commercial
  claims.
- Done boundary: CLI, reports, docs, tests, and close-out evidence all agree on
  project scope as the alpha default.
