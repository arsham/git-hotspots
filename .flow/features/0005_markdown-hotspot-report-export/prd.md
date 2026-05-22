# Feature 0005 PRD: Markdown hotspot report export

## Summary

Add a deterministic Markdown output renderer for the existing file-level hotspot
analysis model. Markdown is a human-readable, shareable, agent-ready export of
the same evidence currently available through table and JSON output.

The feature is a renderer and CLI format extension only. It must not change Git
history collection, scoring, filtering, or the JSON schema except where tests or
docs intentionally cover the new format.

## Goals

- Support `--format markdown` alongside `table` and `json`.
- Render Markdown from the existing `model.Analysis` data model.
- Preserve deterministic, local-first, privacy-safe output.
- Make scope filters, caveats, provenance, ranked hotspots, and evidence visible
  in the Markdown report.
- Extend the canonical `zig build validate` ladder so Markdown is covered by
  golden fixtures, semantic assertions, privacy checks, and real-repo smoke.

## Non-goals

- No `--output` option; users can redirect stdout.
- No templates, themes, config files, YAML frontmatter, HTML, PDF, or report
  packaging.
- No prompt generation, agent-specific personas, LLM-authored narrative, or
  runtime model calls.
- No providers, tree-sitter, LSP, ctags, cache/database work, release/CI
  automation, or default ignore policy.
- No scoring redesign, Git collection changes, or scope-filter semantic changes.
- No author metrics, developer ranking, bug prediction, code-quality scoring,
  hosted-product, SaaS, pricing, sales, or monetisation content.

## Requirements

1. CLI format support
   - Extend the accepted `--format` values to `table|json|markdown`.
   - Keep the default format as `table`.
   - Keep invalid format handling clear and non-panicking.
   - Update help text to document Markdown without changing existing flag
     semantics.

2. Renderer contract
   - Add `report.renderMarkdown(writer, analysis)`.
   - Render from `model.Analysis`; do not recompute rankings, scores, co-change
     evidence, scope metadata, or caveats inside the renderer.
   - Preserve the existing result order from analysis.
   - Do not include absolute repo roots, remote URLs, author names/emails, raw
     source snippets, or private report dumps.

3. Markdown structure
   - Include `# git-hotspots report`.
   - Include a framing sentence: file-level Git-history investigation prompts,
     not bug predictions or code-quality ratings.
   - Include `## Run summary` with tool/version, head commit, range when present,
     commit count, shallow/partial/dirty flags, `auto_fetch=false`, and a note
     that paths are repo-relative.
   - Include `## Scope` with whether filters are active, exclude prefixes when
     present, excluded path count, and excluded change count.
   - Include `## Caveats` with global caveats or `None`.
   - Include `## Top hotspots` as a Markdown table with rank, path, score,
     changes, churn, confidence, and last commit.
   - Include `## Evidence` with one subsection per result containing score
     breakdown, additions/deletions/current size, top co-changes, bounded
     evidence commits, and row caveats.

4. Markdown safety
   - Escape or safely render Markdown table cells and headings for paths,
     caveats, co-change paths, and evidence text.
   - Handle filenames containing pipes, backticks, brackets, `#`, list markers,
     tabs, unicode, glob-like literals, and other Markdown-significant text.
   - Render control characters in a deterministic escaped form rather than raw
     control bytes.
   - Preserve project-relative path text without converting to absolute paths.

5. Scope honesty
   - Scoped Markdown must display active filters and exact excluded path/change
     counts.
   - Filtered paths must not appear in ranked rows or co-change lists.
   - Empty scoped result sets must still produce a complete report with run
     summary, scope, caveats, top-hotspots section, and evidence section.
   - Literal-prefix semantics from Feature 0004 must remain unchanged:
     `vendor/` must not exclude `src/vendor_adapter.zig`, and `glob/*` must not
     act as a glob.

6. Determinism and parity
   - Repeated Markdown output for the same fixture and options must be
     byte-identical.
   - Markdown must expose provenance, caveats, scope, ranked rows, confidence,
     score breakdown, co-changes, and evidence counts comparable to JSON.
   - Existing table and JSON outputs should remain unchanged except for
     intentional help/docs changes.

7. Validation integration
   - Add exact golden Markdown fixtures at minimum:
     - `fixtures/expected/basic.md`
     - `fixtures/expected/scope-filtered.md`
   - Diff Markdown golden output in `tests/integration.sh`.
   - Run Markdown twice for a fixture and diff byte-for-byte.
   - Add semantic assertions for required sections, disclaimer wording, scope
     visibility, caveat visibility, no filtered `.flow/` result/co-change leaks,
     and no private/absolute path leaks.
   - Extend `tools/validate.sh` so `zig build validate` covers Markdown fixture
     output and real-repo smoke.

8. Real-repository smoke
   - Default validation must smoke this repo with table, JSON, and Markdown.
   - Close-out validation must smoke one sibling/local repo via existing
     `-Dcloseout=true -Dsmoke-repo=... -Dsmoke-label=...`, or record an
     explicit privacy-safe skip reason.
   - Evidence summaries must use labels, counts, caveats, scope flags, and
     elapsed time only. Do not print or commit raw private Markdown reports.

## Edge cases

- Empty scoped result set.
- Shallow and partial history caveats.
- Dirty worktree caveat.
- Deleted files with `current_size: null`.
- Binary file caveats.
- Paths with spaces, tabs, unicode, pipes, backticks, brackets, list markers,
  headings, glob-like literals, and Markdown table separators.
- Scoped output with `.flow/` excluded.
- Literal prefix that resembles a glob but is not a glob.
- Invalid `--format` remains an error.

## Verification

Minimum close-out evidence:

- `zig fmt --check build.zig src tests` passes.
- `zig build test` passes.
- `zig build validate` passes and includes Markdown checks.
- `git diff --check` passes.
- Golden Markdown fixture diffs pass.
- Repeated Markdown fixture output is byte-identical.
- Privacy scan for Markdown outputs passes: no absolute local paths, `$HOME`,
  fixture author names/emails, email-like identities, remote URLs, `git@`,
  `ssh://`, `http://`, or `https://`.
- Scoped self-repo Markdown smoke with `--exclude-prefix .flow/` shows no
  `.flow/` ranked rows or co-change paths.
- Close-out real-repo smoke records table, JSON, and Markdown success for this
  repo and a sibling/local repo or records an explicit privacy-safe skip reason.
- `flow validate --target feature:0005 --format json` passes.

## Packets

### P1 - Markdown renderer contract

Goal: add deterministic Markdown rendering from existing `model.Analysis`.

Anchors: `src/report.zig`, renderer tests.

In scope:

- Add `renderMarkdown(writer, analysis)`.
- Add Markdown-safe escaping/formatting helpers.
- Include the required report sections and preserve result order.
- Use only existing `model.Analysis` fields.

Out of scope:

- CLI exposure, scoring changes, Git collection changes, provider/cache work,
  templates, prompts, or file output.

Validation/evidence:

- `zig fmt --check build.zig src tests`
- `zig build test`
- Unit tests for Markdown escaping and stable section snippets.

Review focus:

- Renderer is deterministic, privacy-safe, complete enough for humans and agents,
  and does not reach into Git/scoring logic.

Escalate if:

- Markdown requires data not present in `model.Analysis`.
- Renderer changes score, Git, or scope semantics.

Done boundary:

- Renderer compiles, tests pass, and is ready to be wired to CLI.

### P2 - CLI format plumbing

Goal: expose Markdown as `--format markdown`.

Anchors: `src/model.zig`, `src/main.zig`, `src/report.zig`, tests.

In scope:

- Extend `model.Format` with `markdown`.
- Update CLI parser, usage text, and render switch.
- Add targeted CLI smoke for Markdown.

Out of scope:

- Output files, templates, prompt flags, agent flags, config files, and behaviour
  changes to table/JSON.

Validation/evidence:

- `zig build`
- `zig build test`
- `zig build run -- --help`
- Targeted fixture Markdown commands for basic and scoped reports.

Review focus:

- Default remains `table`; invalid format still fails; table/JSON fixtures remain
  stable.

Escalate if:

- CLI scope expands beyond a single format value.

Done boundary:

- Users can run `--format markdown` and existing formats continue to work.

### P3 - Validation, fixtures, and public docs

Goal: cover Markdown in canonical validation and document it publicly.

Anchors: `fixtures/expected/*.md`, `tests/integration.sh`, `tools/validate.sh`,
`README.md`.

In scope:

- Add golden Markdown fixture files.
- Diff Markdown fixtures and repeated outputs.
- Add semantic Markdown assertions and privacy checks.
- Extend real-repo smoke to include Markdown.
- Update README with supported format and one Markdown example.

Out of scope:

- Flow/process clutter in README, raw private report dumps, release/CI work,
  commercial/hosted language, providers, cache, templates, or prompt generation.

Validation/evidence:

- `zig build validate`
- `zig build test`
- `git diff --check`
- Close-out mode with sibling/local repo or explicit skip reason.

Review focus:

- Markdown is deterministic and privacy-safe, scope filters are represented
  honestly, and public docs remain polished and OSS-safe.

Escalate if:

- Golden Markdown becomes too brittle and needs a reshaped semantic-only
  strategy.
- Validation requires new external tools beyond current shell/Python/jq fallback
  pattern.

Done boundary:

- `zig build validate` is sufficient for future runners to catch Markdown export
  regressions.
