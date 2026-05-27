# git-hotspots developer guide

This guide records the small repo-local boundaries contributors should preserve
while changing documentation, help text, validation, or implementation code.
Keep `README.md` and `CONTRIBUTING.md` concise entry points, and put deeper
usage or contributor detail here or in `docs/user-guide.md`.

## Repository structure

- `src/cli.zig` owns argument parsing, user-facing validation errors, and the
  terminal `--help` text.
- `src/app.zig` owns orchestration from parsed config to analysis, optional
  provider enrichment, and report rendering.
- `src/git.zig` is the public local Git-analysis facade.
- `src/git_history.zig`, `src/git_log.zig`, `src/git_path.zig`, and related
  modules own deterministic Git-history collection and path handling.
- `src/scoring.zig` owns deterministic ranking and confidence rules.
- `src/provider.zig` owns provider evidence contracts and current-only
  semantics.
- `src/provider_selection.zig` chooses the bounded inspect-only symbol provider
  for a matched path; it is not a runtime plugin framework.
- `src/tree_sitter_*.zig` modules own language-specific current-symbol
  extraction.
- `src/report*.zig` owns deterministic table, JSON, Markdown, and symbol report
  rendering.
- `tests/integration.sh` protects executable behaviour and public output
  contracts with fixtures.
- `tools/validate.sh` owns the broader local validation ladder and privacy-safe
  evidence summary.
- `docs/user-guide.md`, `docs/developer-guide.md`, and `man/git-hotspots.1`
  are public documentation surfaces and must stay aligned with `--help`.

## Argument and help ownership

When changing CLI wording or parser behaviour:

1. Update `src/cli.zig` first.
2. Keep `--help` and `-h` standalone and repository-independent.
3. Preserve existing invalid-combination contracts unless the active feature
   explicitly changes them.
4. Update `tests/integration.sh` and `tools/validate.sh` greps for new required
   help anchors.
5. Align `README.md`, `docs/user-guide.md`, and `man/git-hotspots.1` when public
   option wording changes.

Do not add flags, subcommands, shell completions, interactive help, install
hooks, or packaging work as part of a docs/help-only change.

## Report and provider boundaries

File-level local Git-history evidence is the product truth. Provider output is
optional current-file enrichment for `--inspect PATH --symbols` and must not
change score, rank, confidence, co-change evidence, Git rename lineage, scope,
or inclusion and exclusion decisions.

Provider changes should expose source, freshness, confidence, failure state, and
caveats. They should not emit parser diagnostics, source snippets, author
identities, remotes, absolute local paths, package graphs, semantic moves, true
symbol history, ownership claims, or repo-wide scans unless a later feature
explicitly shapes that scope.

## Validation ladder

Use the narrowest useful gate while iterating, then run the broader gate before
hand-off:

```sh
zig fmt --check build.zig src tests
zig build test
zig build validate
```

Run shell syntax checks when shell files change:

```sh
for file in tools/*.sh tests/*.sh; do sh -n "$file" || exit 1; done
```

Run `zig build validate-all` when touching provider lanes, vendored
Tree-sitter proof wiring, language query contracts, or proof aggregate logic.
For docs/help-only changes, `zig build validate` is the expected full local
validation gate.

## Documentation drift rules

Keep public docs accurate and source-controlled:

- Update `--help`, `README.md`, `docs/user-guide.md`, and `man/git-hotspots.1`
  together when user-facing option text changes.
- Keep `docs/developer-guide.md` aligned with module ownership and validation
  commands.
- Prefer project-relative paths or placeholders in examples.
- Do not paste raw private report output, absolute local paths, remotes, author
  identities, or commit messages into public docs.
- Keep examples local and deterministic; do not require network access or global
  documentation generators.

`tools/validate.sh` should protect new docs and manual paths with presence,
anchor, prohibited-claim, and privacy checks.

## Public-claim guardrails

Public documentation and help text must frame hotspots as investigation prompts
from deterministic local Git-history evidence. Avoid claims that the tool:

- predicts bugs;
- measures objective code quality;
- scores technical debt as product truth;
- ranks developers or judges maintainers;
- measures productivity or ownership;
- uploads source, contacts remotes, or uses telemetry;
- relies on runtime model judgement for hotspot truth.

Also avoid commercial, hosted-service, pricing, sales, release automation, or
package-manager promises in this public repository unless a future feature
explicitly changes the public boundary.

## Local-first implementation guardrails

Runtime defaults must remain deterministic and local. Do not add network access,
remote enrichment, background upload, telemetry, cache requirements, package
publishing, release automation, global CLI dependencies, or provider runtime
requirements inside unrelated implementation work. If a documentation claim
needs behaviour that does not exist, reshape the claim instead of implementing
new runtime scope inside docs work.
