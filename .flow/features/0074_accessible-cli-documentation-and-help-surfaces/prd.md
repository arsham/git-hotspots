# Accessible CLI documentation and help surfaces

## Problem

`git-hotspots` has a useful alpha CLI, but its learning path is too dense for
new users and future contributors. The repository already has `--help`, README
usage examples, and CONTRIBUTING architecture notes, yet there is no checked-in
man page, no task-oriented user guide, no concise developer guide, and no
feature-specific validation contract that keeps help, docs, and manual claims in
sync as options grow.

This creates three risks:

- first-time users must read a long README to learn common workflows;
- contributors may not know which files own CLI help, reports, providers, and
  validation; and
- public docs, terminal help, and future man-page text may drift or accidentally
  overclaim beyond deterministic local Git-history evidence.

## Outcome

Create a bounded documentation and help surface that makes the existing alpha
CLI easier to learn from the terminal and repository:

- concise terminal help for common first-run understanding;
- a checked-in man page;
- a task-oriented user guide;
- a contributor-oriented developer guide; and
- deterministic validation that protects key help/docs/man claims.

The feature must not add packaging, release automation, hosted service strategy,
commercial strategy, telemetry, upload, remote enrichment, provider behaviour,
cache behaviour, scoring changes, report schema changes, or new runtime analysis
semantics.

## Requirements

### REQ-001 Existing help remains standalone

`git-hotspots --help` and `git-hotspots -h` must remain standalone help surfaces
that do not require a Git repository and do not emit progress or analysis
stderr.

The help text should be concise enough for terminal use and should include:

- synopsis or common invocation shape;
- supported option names;
- local-first and no-telemetry boundary;
- hotspot-as-investigation-prompt framing; and
- the inspect-only provider boundary for `--symbols` and
  `--symbol-line-history`.

### REQ-002 Help changes do not alter CLI semantics

Any help-text change must preserve existing parser and analysis behaviour unless
a separate accepted feature explicitly changes runtime semantics.

This feature must not add flags, subcommands, shell completions, config files,
interactive help, output schema fields, scoring changes, provider behaviour,
network access, telemetry, upload, or remote enrichment.

### REQ-003 Checked-in man page

The repository must contain a checked-in man page at `man/git-hotspots.1`.

The man page must document at least:

- name;
- synopsis;
- description;
- options;
- examples;
- output/report semantics;
- privacy and local-first caveats;
- provider boundaries;
- exit-status expectations where supported by current behaviour; and
- related repository docs.

The man page is a source-controlled documentation artefact only. This feature
must not add package-manager installation, system man-db integration, release
packaging, generated-doc tooling, or install destinations.

### REQ-004 User guide

The repository must contain `docs/user-guide.md` with a task-oriented learning
path for users building from source.

The guide must cover:

- source-build prerequisites and first run;
- common table, JSON, and Markdown report workflows;
- `--scope`, `--include-prefix`, and `--exclude-prefix` guidance;
- `--inspect` file drilldown;
- opt-in `--symbols` and `--symbol-line-history` examples;
- `--explain`, `--version`, and `--help` discovery paths;
- shallow, partial, dirty-worktree, unsupported-provider, and alpha caveats; and
- privacy-safe, project-relative example style.

### REQ-005 Developer guide

The repository must contain `docs/developer-guide.md` with concise contributor
implementation guidance.

The guide must cover:

- source tree and module ownership;
- `src/cli.zig` ownership of argument parsing and usage text;
- report, scoring, Git evidence, provider, and validation boundaries;
- when to run `zig build test`, `zig build validate`, and
  `zig build validate-all`;
- documentation drift rules for README, help, man page, user guide, and
  developer guide; and
- public-claim guardrails for local-first and evidence-first documentation.

The guide must not become an architecture rewrite, plugin roadmap, cache design,
commercial plan, hosted-product plan, or internal planning dump.

### REQ-006 README and CONTRIBUTING remain entry points

README and CONTRIBUTING should remain polished entry points. They may link to
the new user and developer guides, but they should not become longer catch-all
manuals for every option and implementation detail.

### REQ-007 Validation protects docs and manual surfaces

Local validation must include deterministic checks that cover the new
documentation surfaces.

At minimum, validation should prove:

- `--help` still includes key flags and caveats;
- `man/git-hotspots.1`, `docs/user-guide.md`, and `docs/developer-guide.md`
  exist;
- those docs mention key user-facing discovery paths such as `--help`,
  `--explain`, and source-build validation where appropriate;
- docs/man surfaces are included in prohibited-claim or privacy scans; and
- validation remains local and deterministic without adding network or global
  documentation-tool dependencies.

### REQ-008 Public claims stay evidence-first

All new or changed public documentation must keep hotspots framed as
investigation prompts from deterministic local Git-history evidence.

Docs must not claim that the tool predicts bugs, measures objective code
quality, scores technical debt as product truth, ranks developers, judges
maintainers, measures productivity, uploads source, contacts remotes, uses
telemetry, or relies on runtime AI judgement for hotspot truth.

### REQ-009 Project-relative and privacy-safe examples

Examples should use project-relative paths, placeholders, or local fixture-style
paths. Public docs and validation output must not include private absolute local
paths, raw private reports, personal email addresses, author identities, remote
URLs, access tokens, or private repository names.

## Edge cases and non-goals

- Do not add packaging, package-manager metadata, release automation, installed
  man-page integration, shell completions, or docs hosting.
- Do not add new CLI flags or subcommands as part of this feature.
- Do not change runtime analysis semantics, ranking, confidence, co-change,
  provider extraction, symbol evidence, current-line evidence, report schemas,
  cache behaviour, or default local-first execution.
- Do not add benchmarks, case studies, remote repository examples, hosted
  dashboards, commercial strategy, pricing, or sales language.
- If a documentation claim requires runtime behaviour that does not currently
  exist, stop and reshape instead of implementing the behaviour inside this
  docs/help feature.
- If accessibility is interpreted as terminal accessibility standards,
  screen-reader testing, interactive tutorials, completions, or UX research,
  shape that as a later feature with explicit acceptance.

## Verification notes

Close-out evidence should include:

1. `git diff --check`.
2. `zig fmt --check build.zig src tests` when Zig or test files change.
3. `sh -n tools/*.sh tests/*.sh` when shell scripts change.
4. `zig build test`.
5. `zig build validate`.
6. Targeted help checks for `--help`, `-h`, and `--progress --help`.
7. Man-page presence and required-section checks.
8. User-guide and developer-guide presence and key-anchor checks.
9. Proof that docs/man surfaces are included in prohibited-claim and privacy
   scans.
10. Privacy-safe real-repository smoke only when executable behaviour changes
    beyond help/docs validation, otherwise record why existing validation is
    sufficient.

Review should prove that the feature improves learnability without changing
runtime product truth, adding new operational dependencies, or expanding public
claims beyond deterministic local Git-history evidence.
