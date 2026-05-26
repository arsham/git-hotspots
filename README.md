# git-hotspots

> Before you refactor, ask Git where the pain is.

`git-hotspots` is a planned local-first CLI for finding files that deserve
engineering attention because they change often. It turns Git history into
clear, reproducible hotspot evidence for maintainers, refactoring work, code
review, onboarding, and coding-agent context.

The project is intentionally early. The current public alpha is source-buildable
and proves that a small, transparent command-line tool can surface useful
file-level hotspots before adding deeper language-aware analysis. It is not a
packaged release yet.

## Why

Code that changes often is worth attention. It may be fragile, strategically
important, under-tested, or simply central to how a project evolves.

`git-hotspots` starts from a simple idea:

> The riskiest code is not always the ugliest code. It is often the code
> everyone keeps changing.

That does not mean a hotspot is bad code. A hotspot is an investigation prompt:
a place to inspect, understand, test, document, or refactor with better context.

## What it should help with

`git-hotspots` should help answer questions like:

- where should we inspect first?
- where might tests or documentation pay off?
- where should a refactor proposal start?
- which files deserve extra review attention?
- which files should a coding agent understand before suggesting changes?

The tool should be evidence-first and careful. It should not claim to predict
bugs, measure objective code quality, or rank developers.

## First useful layer

The first implementation target is file-level evidence from local Git history:

- change frequency;
- churn from additions and deletions;
- recency;
- co-change with other files;
- conservative file lineage from Git-detected renames;
- file size or similar scale signals;
- confidence and caveats;
- explainable evidence for each result.

The goal is to produce reports that humans can read and tools can consume,
without uploading source code or depending on runtime AI judgement.

## Local-first by default

The project should preserve trust by default:

- analyse local repositories;
- avoid network access by default;
- avoid telemetry by default;
- prefer project-relative paths in shareable output;
- treat author identity and ownership metrics as sensitive;
- report shallow or partial history honestly instead of silently fetching more.

## Provider direction

The alpha includes one narrow opt-in provider path: `--symbols` with
`--inspect PATH` can add inspect-only current working-tree Tree-sitter syntax
evidence for Zig, Go, Python, JavaScript, Lua, TypeScript, or TSX symbols in
the inspected file. File-level Git evidence remains the core product truth;
provider output is optional current-only enrichment.

Broader language and dependency insight should arrive through optional
providers rather than become the foundation of the project. Possible future
provider areas include:

- broader tree-sitter symbol spans;
- LSP data for richer language-aware relationships;
- ctags for broad symbol discovery;
- dependency graph data;
- line-attribution or history enrichers;
- test and coverage evidence.

Provider output should be enrichment, not hidden truth. Providers should expose
source, version, freshness, confidence, and failure state so reports can degrade
gracefully when a provider is unavailable or uncertain.

## Agent-ready, not agent-dependent

`git-hotspots` may produce Markdown, JSON, or other export formats that users
can pass to coding agents. Those exports should carry deterministic evidence,
provenance, and caveats.

The product truth remains local Git evidence. Agents are consumers of reports,
not the runtime authority for hotspot findings.

## Public alpha status

Current version: `0.1.0-alpha.1`.

This repository contains a narrow public alpha for local source builds. It does
not provide packaged binaries, package-manager installation, release tags, or a
hosted service. Runtime behaviour is local-first: the CLI reads local Git
history and does not fetch, push, upload source, contact remotes, or emit
telemetry.

## Install from source

Prerequisites:

- Git available on `PATH`;
- Zig `0.16.0`, which is the currently validated Zig version for this alpha.

Build and run from a local checkout:

```sh
git clone <repo-url>
cd git-hotspots
zig build
./zig-out/bin/git-hotspots --version
./zig-out/bin/git-hotspots --help
```

Replace `<repo-url>` with the repository URL you intend to use. Until a future
feature adds packaging, source checkout plus `zig build` is the supported
install path.

## CLI usage

Run the current local alpha with Zig:

```sh
zig build
./zig-out/bin/git-hotspots --repo . --limit 10 --format table
./zig-out/bin/git-hotspots --repo . --limit 10 --format json
./zig-out/bin/git-hotspots --repo . --limit 10 --format markdown
./zig-out/bin/git-hotspots --repo . --scope all --limit 10 --format markdown
./zig-out/bin/git-hotspots --repo . --scope project --limit 10 --format markdown
./zig-out/bin/git-hotspots --repo . --include-prefix src/ --limit 10 --format markdown
./zig-out/bin/git-hotspots --repo . --exclude-prefix .flow/ --limit 10 --format markdown
./zig-out/bin/git-hotspots --repo . --inspect src/main.zig --format markdown
./zig-out/bin/git-hotspots --repo . --inspect src/main.zig --symbols --format markdown
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.go --symbols --format markdown
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.py --symbols --format markdown
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.js --symbols --format markdown
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.lua --symbols --format markdown
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.ts --symbols --format markdown
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.tsx --symbols --format markdown
./zig-out/bin/git-hotspots --repo . --inspect src/main.zig --symbols --symbol-line-history --format markdown
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.ts --symbols --symbol-line-history --format markdown
./zig-out/bin/git-hotspots --repo . --progress --format json
./zig-out/bin/git-hotspots --explain
./zig-out/bin/git-hotspots --version
```

Supported options are `--repo`, `--limit`, `--format table|json|markdown`,
`--since`, `--scope all|project`, repeatable `--include-prefix`, repeatable
`--exclude-prefix`, `--inspect`, `--symbols`, `--symbol-line-history`,
`--progress`, `--explain`, `--version`, and `--help`.
During the alpha, omitted `--scope` defaults to `--scope project`, which
expands to the root literal exclude prefixes `.flow/`, `.zig-cache/`,
`zig-out/`, `target/`, `node_modules/`, `dist/`, `build/`, and `coverage/`, in
that order. Project scope is a convenience default, not a more correct view
than full local Git-history evidence. Use `--scope all` for the full local
Git-history evidence universe with no built-in project excludes. Include and
exclude prefixes are literal repo-relative Git path prefixes using `/`
separators; they are applied before hotspot scoring and co-change evidence,
with excludes winning over includes. They are not globs, pathspecs, gitignore
rules, regexes, or project configuration. `--inspect PATH` performs an exact
file drilldown within the selected scope, returning only that file's existing
hotspot row plus its rank in the full scoped evidence universe. If an old path
was accepted as an in-scope Git rename alias, `--inspect` may resolve that alias
to the canonical current path row. Use the Git-style `\t` escape to target a
path that contains a tab, for example `--inspect 'weird/tab\tname.txt'`;
literal control characters remain invalid. It does not rescore or bypass scope,
include, or exclude filters, and it cannot be combined with `--limit`. Reports
include scope metadata showing the selected scope, effective prefixes, and
bounded counts for paths and changes omitted by include or exclude filters.
Markdown output is a deterministic stdout report with run summary, scope,
caveats, ranked hotspots, and per-result evidence. `--version` is standalone
and prints the alpha version without requiring a Git repository.

`--symbols` is opt-in and works only with `--inspect PATH`. It adds
inspect-only current working-tree Tree-sitter syntax evidence for Zig, Go,
Python, JavaScript, Lua, TypeScript, or TSX symbols in the matched in-scope
`.zig`, `.go`, `.py`, `.js`, `.mjs`, `.cjs`, admitted `.jsx`, `.lua`, `.ts`,
`.mts`, `.cts`, or `.tsx` file, with provider freshness, failure, confidence,
caveats, and local provenance in the report.
Symbol evidence is current-only enrichment: it does not change file score,
rank, confidence, co-change evidence, Git rename lineage, scope, or
inclusion/exclusion decisions. Unsupported or unavailable current files
preserve the inspected file evidence and report provider caveats without parser
diagnostics, source snippets, absolute paths, remotes, author identities, or
commit messages. Go support is inspect-only for the matched file and does not
evaluate packages, build tags, cgo, dependency graphs, symbol lineage, scoring,
ranking, or true symbol history. Python support is inspect-only for the matched
file and does not evaluate imports, packages, virtual environments, dependency
graphs, generated-source policy, scoring, ownership, or semantic moves.
JavaScript support is inspect-only for `.js`, `.mjs`, `.cjs`, and admitted
`.jsx` files and does not evaluate Node, packages, workspaces, module
resolution, TypeScript, TSX, dependency graphs, scoring, ownership, repo-wide
scanning, or symbol history. Lua symbol output is inspect-only current syntax
evidence for `.lua` files and does not evaluate packages, `require`, runtime
modules, types, metatables, dynamic table keys, dependency graphs, runtime
execution, scoring, ownership, maintainer judgement, bug prediction, code
quality, or repo-wide scanning; symbol history is out of scope.
TypeScript/TSX support is inspect-only for `.ts`, `.mts`, `.cts`, and `.tsx`
files and does not evaluate packages, workspaces, tsconfig, module resolution,
type checking, dependency graphs, scoring, ownership, cache, repo-wide
scanning, or symbol history.

Provider capability matrix:

| Language lane | Inspected paths | `--symbols` provider | `--symbols` evidence | `--symbol-line-history` evidence | Explicit boundary |
| --- | --- | --- | --- | --- | --- |
| Zig | `.zig` | `tree-sitter-zig` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | no dependencies, semantic moves, true symbol history, scoring, or ownership claims |
| Go | `.go` | `tree-sitter-go` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | no packages, build tags, cgo, dependency graphs, true symbol history, scoring, or ownership claims |
| Python | `.py` | `tree-sitter-python` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | no imports, packages, virtual environments, dependency graphs, generated-source policy, true symbol history, scoring, or ownership claims |
| JavaScript | `.js`, `.mjs`, `.cjs`, admitted `.jsx` | `tree-sitter-javascript` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | no Node, packages, workspaces, module resolution, TypeScript, TSX, dependency graphs, true symbol history, scoring, or ownership claims |
| Lua | `.lua` | `tree-sitter-lua` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | no package, require, runtime module resolution, metatables, dynamic table keys, dependency graphs, runtime execution, true symbol history, scoring, or ownership claims |
| TypeScript | `.ts`, `.mts`, `.cts` | `tree-sitter-typescript` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | no packages, workspaces, tsconfig, module resolution, type checking, dependency graphs, cache, true symbol history, scoring, or ownership claims |
| TSX | `.tsx` | `tree-sitter-tsx` | current working-tree symbols for the matched file | current-line Git evidence for HEAD line ranges | no React, DOM, packages, type analysis, dependency graphs, cache, true symbol history, scoring, or ownership claims |
| Unsupported current files | all other paths | unsupported fallback | provider reports `unsupported` and keeps inspected file evidence | no current-line evidence | no parser diagnostics, source snippets, or parsed symbols |

`--symbol-line-history` is a second opt-in layer that works only with
`--inspect PATH --symbols`. It adds current-line Git evidence for current Zig,
Go, Python, JavaScript, Lua, TypeScript, or TSX symbol line ranges using one
local current-line Git evidence command only when symbol ranges are valid and
the inspected file is clean. Current-line evidence is for the lines occupied by
a symbol at HEAD.
it is not true symbol history, historical identity tracking, or `git log -L`.
Output is summary-only: commit counts, bounded sample commit ids, timestamps,
confidence, freshness, failure state, and caveats. It does not emit author
identities, commit messages, source snippets, remotes, private repo names, or
absolute paths, and it does not change file score, rank, confidence,
co-change evidence, scope, or lineage.

Git-detected file renames are folded conservatively when both the old and new
paths are in scope. This is file-path lineage from local Git history only, not
symbol or function lineage, semantic ownership, bug prediction, quality scoring,
or developer ranking.

Use `--progress` when a long local analysis would benefit from coarse runtime
feedback. It is opt-in, writes bounded phase and elapsed-time lines to stderr
only, and does not add timing or progress fields to table, JSON, or Markdown
reports.

## Large repository recipes

Large repositories can start with explicit exploratory scopes while preserving a
clear escape hatch to full local Git-history evidence. These recipes use only
supported local CLI options and do not change scoring, report schemas, or
local-first runtime behaviour.

For a project-focused recent run that keeps workflow metadata out of the first
pass, bound history by revision and enable progress feedback:

```sh
./zig-out/bin/git-hotspots --repo . --scope project --since HEAD~500 --progress --limit 20 --format markdown
```

For a source-focused pass, combine a literal repo-relative prefix with a bounded
revision range:

```sh
./zig-out/bin/git-hotspots --repo . --include-prefix src/ --since HEAD~1000 --limit 20 --format markdown
```

Bounded runs are exploratory scopes: they reduce the selected history or output
for a specific question, but they are not more correct than a full-history run
and are not hidden correctness claims. If you omit `--since`, `git-hotspots`
analyses the full reachable local history selected by the scope and prefix
options. Use `--scope all` when you want the full tracked-path evidence universe
instead of the alpha project preset.

## How to read scores

Run `git-hotspots --explain` to print the static scoring explanation without
requiring a Git repository. The current score is the sum of frequency, churn,
recency, and co-change evidence:

- frequency = `change_count * 10`;
- churn = `min((additions + deletions) / 25, 40)`;
- recency is `20` at the selected HEAD timestamp and otherwise decays by age in
  days to a floor of `0`;
- co-change = `min(cochange_total * 2, 20)`.

Confidence is `high` when a row has at least three changes and no caveats,
`medium` when it has at least two changes, and `low` otherwise. Caveats call
out shallow history, partial or promisor history, dirty worktrees, binary or
non-text churn, large commits, Git-detected rename lineage, scope-partial
lineage, and paths deleted or not present at HEAD.

Hotspots are local Git-history investigation prompts. They are not bug
predictions, objective code-quality ratings, maintainer judgement, developer
rankings, productivity analytics, AI/LLM judgement, or technical-debt scores.

Use the full local validation workflow before close-out:

```sh
zig build validate
```

`zig build test` remains the faster unit and fixture gate. `zig build validate`
runs the fuller local ladder and prints a privacy-safe evidence summary.

## Current limitations

- This alpha is source-buildable, not packaged.
- Report truth is deterministic file-level Git-history evidence.
- Broad provider, cache, dependency, test, and coverage enrichers are future
  work; the current provider path supports opt-in inspect-only current
  working-tree Tree-sitter syntax evidence for Zig, Go, Python, JavaScript,
  Lua, TypeScript, and TSX symbols.
- Runtime defaults remain local-only and do not perform network access.

## Contributing

Issues and small focused pull requests are welcome during alpha. Please see
[`CONTRIBUTING.md`](CONTRIBUTING.md) before proposing changes.

## License

`git-hotspots` is licensed under the Apache License, Version 2.0. See
[`LICENSE`](LICENSE).

## Status

This repository has an executable file-level public alpha. It is not a packaged
release yet.
