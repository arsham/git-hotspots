# git-hotspots user guide

This guide shows how to learn `git-hotspots` from a source checkout. The
current alpha is local-first and source-buildable. Local Linux binary and Arch
packaged dogfood files exist for unpublished use; source builds remain the
public default until packages are published.

## Source-build setup

Prerequisites:

- Git on `PATH`.
- Zig `0.16.0`.
- A local Git worktree to analyse.

Build from a checkout:

```sh
zig build
./zig-out/bin/git-hotspots --version
./zig-out/bin/git-hotspots --help
```

Before sharing changes to this repository, run the local validation workflow:

```sh
zig build validate
```

## Local Linux dogfood package path

The local packaging path is for Linux dogfood validation only. It is not a
published GitHub Release, AUR package, package-manager install promise, or
multi-platform distribution.

Build and smoke-test the native Linux release archive:

```sh
./tools/release-linux.sh
mkdir -p /tmp/git-hotspots-release-smoke
tar -xzf dist/git-hotspots-0.1.0-alpha.3-linux-$(uname -m).tar.gz -C /tmp/git-hotspots-release-smoke
/tmp/git-hotspots-release-smoke/git-hotspots-0.1.0-alpha.3-linux-$(uname -m)/git-hotspots --version
/tmp/git-hotspots-release-smoke/git-hotspots-0.1.0-alpha.3-linux-$(uname -m)/git-hotspots --help
```

Build the unpublished Arch dogfood package when standard Arch tooling is
available:

```sh
cp dist/git-hotspots-0.1.0-alpha.3-linux-$(uname -m).tar.gz packaging/aur/git-hotspots-bin/
cd packaging/aur/git-hotspots-bin
makepkg --printsrcinfo
makepkg -f
pacman -Qp git-hotspots-bin-0.1.0_alpha.3-1-$(uname -m).pkg.tar*
```

To avoid overwriting an existing user-managed `git-hotspots`, smoke-test the
package by extracting it into a temporary directory instead of installing it
system-wide:

```sh
mkdir -p /tmp/git-hotspots-package-smoke
bsdtar -xf git-hotspots-bin-0.1.0_alpha.3-1-$(uname -m).pkg.tar* -C /tmp/git-hotspots-package-smoke
/tmp/git-hotspots-package-smoke/usr/bin/git-hotspots --version
/tmp/git-hotspots-package-smoke/usr/bin/git-hotspots --help
```

If `makepkg`, `pacman`, or `bsdtar` is unavailable, record that explicit
unavailable-tool finding and keep the release archive smoke evidence. The
default release and package commands do not contact remotes, fetch release
metadata, upload files, publish to AUR, create tags, emit telemetry, or require
credentials.

## First run

Start with the default project scope, table output, and the current checkout:

```sh
./zig-out/bin/git-hotspots --repo . --limit 10 --format table
```

Use `--explain` when you want the scoring semantics without analysing a
repository:

```sh
./zig-out/bin/git-hotspots --explain
```

Hotspots are investigation prompts from deterministic local Git-history
evidence. Treat a row as a place to inspect, test, document, or refactor with
more context, not as a bug prediction or a code-quality rating.

## Common workflows

### Table output for quick terminal review

```sh
./zig-out/bin/git-hotspots --repo . --limit 20 --format table
```

Table output is a compact human view for a first pass. Use it to choose a small
set of files for follow-up.

### JSON output for tools

```sh
./zig-out/bin/git-hotspots --repo . --limit 20 --format json
```

JSON output is deterministic and includes report metadata, caveats, scope
metadata, ranked rows, and evidence fields suitable for downstream tools.

### Markdown output for review notes

```sh
./zig-out/bin/git-hotspots --repo . --limit 20 --format markdown
```

Markdown output is useful when you want a shareable report with run summary,
scope, caveats, ranked hotspots, and per-result evidence.

### Progress for longer local runs

```sh
./zig-out/bin/git-hotspots --repo . --scope project --since HEAD~500 --progress --format markdown
```

`--progress` writes coarse phase lines to stderr only. It does not add progress
or timing fields to table, JSON, or Markdown reports.

## Scope, include, and exclude filters

Omitted `--scope` is the same as `--scope project` during the alpha. Project
scope excludes these literal repo-root prefixes before scoring:

```text
.flow/ .zig-cache/ zig-out/ target/ node_modules/ dist/ build/ coverage/
```

Use `--scope all` when you want the full tracked-path evidence universe:

```sh
./zig-out/bin/git-hotspots --repo . --scope all --limit 20 --format markdown
```

Use literal repo-relative prefixes to narrow or exclude evidence before
scoring. Prefixes are not globs, regexes, pathspecs, or gitignore rules.
Excludes win over includes.

```sh
./zig-out/bin/git-hotspots --repo . --include-prefix src/ --limit 20 --format markdown
./zig-out/bin/git-hotspots --repo . --exclude-prefix docs/ --limit 20 --format markdown
```

Bounded scopes are exploratory views for a question. They are not more correct
than a full-history run.

## Inspect and symbols

Use `--inspect PATH` for one exact repo-relative file within the selected scope:

```sh
./zig-out/bin/git-hotspots --repo . --inspect src/main.zig --format markdown
```

Inspect keeps the file-level Git-history row and records the row rank in the
full scoped evidence universe. It does not rescore, bypass scope filters, or
combine with `--limit`.

Use `--symbols` when you want current working-tree symbol evidence for supported
file types. Without `--inspect`, provider output is attached to supported files
among the retained ranked hotspots. With `--inspect PATH`, provider output stays
focused on the matched inspected file:

```sh
./zig-out/bin/git-hotspots --repo . --symbols --format markdown
./zig-out/bin/git-hotspots --repo . --inspect src/main.zig --symbols --format markdown
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.py --symbols --format json
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.rs --symbols --format json
```

Supported symbol lanes are Zig, Go, Python, JavaScript, Lua, Rust, TypeScript,
and TSX. Provider evidence is current-only enrichment. It does not change score,
rank, confidence, co-change evidence, Git rename lineage, scope, or inclusion
and exclusion decisions.

Provider capability summary:

| Language lane | Current symbols | Current-line history | Historical symbols | Public relationships |
| --- | --- | --- | --- | --- |
| Zig `.zig` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-zig-relations` |
| Go `.go` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-go-relations` |
| Python `.py` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-python-relations` |
| JavaScript `.js`, `.mjs`, `.cjs`, `.jsx` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-javascript-relations` |
| Lua `.lua` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-lua-relations` |
| Rust `.rs` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-rust-relations` |
| TypeScript `.ts`, `.mts`, `.cts` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-typescript-relations` |
| TSX `.tsx` | supported | supported | supported with revision-local provider fallback | supported by `tree-sitter-tsx-relations` |
| Other current files | unsupported fallback | unsupported | file-level fallback only when retained | unsupported |

Rust support is syntax-only for the inspected `.rs` file. It does not evaluate
Cargo metadata, crates, module resolution, macro expansion output, cfg or
feature selection, type checking, dependency graphs, or semantic Rust meaning.

Use `--symbol-line-history` when you also want current-line Git evidence for
symbol line ranges at HEAD:

```sh
./zig-out/bin/git-hotspots --repo . --symbols --symbol-line-history --format markdown
./zig-out/bin/git-hotspots --repo . --inspect src/main.zig --symbols --symbol-line-history --format markdown
```

Current-line evidence is not true symbol history, historical identity tracking,
or semantic ownership. Shallow, partial, dirty, unsupported, symlinked, missing,
or too-large files report caveats instead of silently expanding scope.

Use `--historical-symbols` when you want bounded true historical hunk
attribution for retained ranked-file candidates:

```sh
./zig-out/bin/git-hotspots --repo . --symbols --historical-symbols --format markdown
./zig-out/bin/git-hotspots --repo . --inspect src/main.zig --symbols --historical-symbols --format json
```

Historical symbol evidence reports revision-local symbols when the provider can
parse the historical blob, and file-level fallbacks when it cannot. It is not
semantic symbol lineage, reference/use analysis, ownership, bug prediction,
scoring replacement, or a ranking input.

Use `--symbol-relationships` when you want bounded local relationship evidence
for retained ranked-file candidates:

```sh
./zig-out/bin/git-hotspots --repo . --symbols --symbol-relationships --format markdown
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.zig --symbols --symbol-relationships --format json
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.go --symbols --symbol-relationships --format json
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.py --symbols --symbol-relationships --format json
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.js --symbols --symbol-relationships --format json
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.lua --symbols --symbol-relationships --format json
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.rs --symbols --symbol-relationships --format json
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.ts --symbols --symbol-relationships --format json
./zig-out/bin/git-hotspots --repo . --inspect path/to/file.tsx --symbols --symbol-relationships --format json
```

Relationship evidence currently comes from local Zig, Go, Python, JavaScript,
Lua, Rust, TypeScript, and TSX Tree-sitter lanes. It reports source and target
endpoints, unresolved targets, provider identity, freshness, failure,
confidence, caveats, record bounds, and omitted counts. Human table and
Markdown output add a compact relationship evidence summary with non-zero
relation-kind counts, uncertainty counts for unresolved or unknown evidence,
`human_display_sample_omitted` for rows hidden only by the human display limit,
and `provider_partial_evidence_omitted` for provider-cap partial evidence;
record bound omissions remain separate. They also compact repeated row caveats
into stable `C1`-style references plus one caveat summary; JSON keeps per-record
caveat arrays. It is caveated investigation context only, not call-graph truth,
dependency proof, ownership, developer metrics, bug prediction, scoring
replacement, or a ranking input.

### Combining evidence layers

Use the layers together as a local investigation workflow:

1. Start with file hotspots to choose a small set of files that changed often,
   recently, with churn, or with repeated co-change evidence.
2. Add `--symbols` to see current working-tree structure for supported files.
3. Add `--symbol-line-history` when the current symbol line ranges need local
   Git context at HEAD.
4. Add `--historical-symbols` when changed hunks need revision-local symbol or
   file-level fallback attribution.
5. Add `--symbol-relationships` when bounded syntax relationships can suggest
   nearby code to inspect.

The layers are complementary evidence prompts. They keep repo-relative output
and local provenance, report unsupported provider states as normal caveats, and
do not change ranking, scoring, report schema, or file-level evidence. Treat
relationship rows as bounded syntax context, not dependency proof or a complete
call graph.

## Reading reports

Reports include:

- run metadata and caveats;
- selected scope and effective prefixes;
- ranked file-level hotspot rows;
- frequency, churn, recency, co-change, size, confidence, and evidence fields;
- conservative Git-detected file rename lineage when both paths are in scope;
- optional current provider evidence for ranked files or one inspected file;
- optional historical hunk attribution for retained ranked-file candidates;
- optional relationship evidence for retained ranked-file candidates.

Confidence is a caveated evidence summary, not a correctness score. Co-change
means files changed in the same commits; it is not dependency analysis.

## Privacy and local-first caveats

Runtime behaviour stays local-first by default. The alpha reads local Git
history and does not fetch, pull, push, upload source, contact remotes, emit
telemetry, or rely on runtime AI judgement for hotspot truth.

Public reports use repo-relative paths. They avoid author identities, raw
private report dumps, remotes, source snippets from provider failures, and
absolute local paths. Shallow or partial history is reported as a caveat because
the tool does not silently fetch more history.

## Troubleshooting

- `error: --symbol-line-history requires --symbols`: add `--symbols` before
  requesting current-line Git evidence.
- `error: --historical-symbols requires --symbols`: add `--symbols` before
  requesting historical hunk attribution.
- `error: --symbol-relationships requires --symbols`: add `--symbols` before
  requesting relationship evidence.
- `error: --format accepts one value`: use `--format table`, `--format json`,
  or `--format markdown`.
- Missing values such as `--repo`, `--limit`, `--since`, `--include-prefix`,
  `--exclude-prefix`, or `--inspect` produce flag-specific diagnostics with a
  valid command shape. Run `git-hotspots --help` for the full option reference.
- When running through `zig build run --`, the application diagnostic is emitted
  before any Zig build wrapper failure text for invalid CLI usage.
- `error: --repo must point to a local non-bare Git worktree`: choose a local
  worktree, not a bare repository or non-Git directory.
- `error: repository has no commits to analyse`: create at least one commit
  before running analysis.
- `error: --since must name an existing revision`: pass a revision that Git can
  resolve in the selected repository.
- `error: --inspect target has no matching Git-history evidence in the selected
  scope`: check the exact repo-relative path and active scope filters.
- Empty reports usually mean the selected include or exclude prefixes removed
  all tracked evidence for the chosen history range.
- Provider caveats on unsupported files are expected; file-level evidence is
  preserved when the provider cannot add symbols.

## Related documents

- `README.md` for the project overview and alpha status.
- `man/git-hotspots.1` for a source-controlled manual page.
- `docs/developer-guide.md` for contributor-facing boundaries and validation.
- `CONTRIBUTING.md` for the expected pre-PR workflow.
