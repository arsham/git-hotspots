# Changelog

## Unreleased draft

Version alignment, release tagging, package publication, and release uploads are
intentionally out of scope for this draft.

### Release notes draft

This draft describes the current public alpha work for later release
preparation. `git-hotspots` remains a deterministic, local-first CLI that turns
local Git history into evidence for investigation. Reports are prompts for human
review, not bug predictions, objective code-quality ratings, ownership analysis,
dependency-truth claims, or complete call-graph semantics.

Implemented work covered by this draft includes:

- File-level hotspot evidence from local Git history, including churn, change
  frequency, recency, co-change context, Git-detected rename lineage, file scale
  signals, confidence, caveats, and explainable per-result evidence.
- Public table, JSON, Markdown, inspect, scope, include-prefix, exclude-prefix,
  explain, and progress workflows documented for source-build users.
- Optional current working-tree symbol evidence through Tree-sitter lanes for
  Zig, Go, Python, JavaScript, Lua, Rust, TypeScript, and TSX. Symbol evidence is
  enrichment only and does not change score, rank, scope, Git history evidence,
  or inclusion decisions.
- Optional current-line history and bounded historical-symbol attribution for
  supported files, with caveats for shallow, partial, dirty, missing,
  unsupported, symlinked, generated, or too-large inputs.
- Optional public symbol-relationship evidence for supported language lanes.
  Relationship output is syntax evidence from supported providers, not package,
  module, dependency graph, type-analysis, runtime, or complete call-graph truth.
- Local validation coverage for integration fixtures, provider output, public
  documentation guardrails, prohibited-claim checks, privacy scans, and
  performance-budget smoke checks.
- Unpublished Linux archive and Arch dogfood packaging paths for local
  validation. These paths do not publish packages, create releases, create or
  push tags, upload artefacts, contact remotes, or require credentials by
  default.

### Usage notes

- Build from source with Zig 0.16.0, then run `zig build validate` before
  sharing changes.
- Use `--repo`, `--scope`, `--include-prefix`, and `--exclude-prefix` to choose
  the local evidence universe before scoring.
- Use `--symbols`, `--symbol-line-history`, `--historical-symbols`, and
  `--symbol-relationships` only when optional provider evidence is useful for
  the investigation.
- Treat provider and relationship sections as evidence with provenance and
  caveats. Do not treat them as runtime AI judgement, dependency analysis, or
  semantic ownership.

### Release preparation notes

- Align this draft with the chosen version before tagging.
- Do not create or push tags, publish packages, upload release artefacts, or
  create a hosted release from this draft alone.
