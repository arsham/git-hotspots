# Provider and symbol evidence contract

`git-hotspots` is file-level Git-history evidence first. Providers are optional
enrichers that may add language, dependency, test, coverage, or other context to
existing file hotspot evidence. Provider output must never become hidden runtime
truth or a prerequisite for useful reports.

This document is a design guardrail for future provider work, especially a
future tree-sitter symbol spike. It does not define a runtime plugin framework
and does not add provider execution or current symbol evidence in the CLI.

## Goals

- Keep file-level Git evidence as the deterministic product truth.
- Define the minimum metadata any future provider evidence must carry.
- Define how symbol evidence attaches to existing file results.
- Define graceful degradation when a provider is unavailable, stale, partial, or
  uncertain.
- Prevent future provider work from implying bug prediction, code-quality
  scoring, developer ranking, or runtime AI authority.

## Non-goals

- No tree-sitter, LSP, ctags, dependency, test, coverage, or cache
  implementation.
- No runtime provider registry, plugin loading, provider lifecycle, or provider
  discovery.
- No CLI flags, configuration files, dependency additions, or report schema
  changes.
- No scoring formula changes and no replacement for file-level Git evidence.
- No network, telemetry, upload, remote enrichment, or background analysis.
- No symbol rename, move, split, or merge tracking.

## Provider evidence envelope

Future provider evidence should be carried in an explicit envelope. The exact
Zig types and report schema can be shaped when the first provider is
implemented, but the envelope should contain at least:

- provider name, for example `tree-sitter` or `lsp`;
- provider kind, for example `symbol`, `dependency`, `test`, or `coverage`;
- provider version and contract version;
- provider configuration fingerprint when configuration affects output;
- analysed repository `HEAD` or input digest;
- freshness state;
- confidence level;
- failure state;
- caveats;
- local-only provenance.

Provider evidence should use repo-relative paths and bounded metadata. It must
not require absolute local paths, remotes, author identities, source snippets,
raw private reports, or provider network calls.

## Provenance and caveats

Local-only provenance means the envelope records what local input the provider
analysed and which local provider produced the evidence. It should be enough to
explain the evidence source without exposing private machine state or implying
that a remote service validated the result.

Caveats are required when provider evidence is incomplete, ambiguous, stale,
generated from excluded paths, or affected by unsupported language constructs.
They should be visible beside the enriched result rather than buried in logs.
Caveats and confidence describe evidence quality only; they are not code-health,
bug-likelihood, or maintainer-performance judgements.

## Freshness

Provider evidence must be explicit about freshness. Future states may include:

- `fresh`: provider input matches the analysed file/revision context;
- `stale`: provider evidence was generated for a different input;
- `partial`: provider completed only part of the requested scope;
- `unknown`: provider cannot prove freshness.

Stale, partial, or unknown evidence may still be useful, but reports must say so
plainly and lower confidence where appropriate.

## Failure state

Provider failures should degrade reports, not fail the core file-level analysis.
Future states may include:

- `ok`: provider completed normally;
- `unavailable`: provider dependency is not installed or not configured;
- `unsupported`: provider does not support the file or language;
- `failed`: provider attempted analysis and errored;
- `timed_out`: provider exceeded a bounded runtime budget;
- `skipped`: user or config intentionally disabled the provider.

A provider failure must not hide file-level Git evidence. It should become a
caveat attached to the relevant report scope or result.

## Confidence

Provider confidence should be separate from file hotspot confidence. Future
symbol confidence may account for:

- parser support for the language;
- whether the symbol range is current and complete;
- whether the symbol span overlaps hotspot evidence;
- provider freshness;
- provider failure or partial state;
- ambiguity from generated, vendored, or excluded paths.

Confidence must be framed as evidence quality, not code quality or risk scoring.

## Symbol evidence shape

A future symbol provider should attach symbol evidence to an existing file
result. Symbol evidence should not replace the file result or create a separate
product truth.

Minimum future symbol fields should include:

- repo-relative file path;
- symbol name, if available;
- symbol kind, for example function, method, class, type, or module;
- current line range or byte range;
- provider envelope reference;
- confidence;
- caveats;
- optional rank or ordering inside the file result.

A first tree-sitter spike should limit itself to current working-tree symbol
spans for one language. Historical symbol lineage, symbol renames, function
moves, dependency propagation, and multi-language support should remain separate
features.

## Report behaviour

When provider evidence exists in a future feature, reports should make provider
state visible:

- which providers contributed evidence;
- which providers were unavailable, stale, partial, skipped, or failed;
- whether symbol evidence is current-only;
- that provider evidence enriched explanation without replacing file-level
  ranking or deterministic Git-history evidence;
- caveats and confidence for provider-derived fields.

Provider evidence should be additive. If no provider evidence exists, current
file-level table, JSON, and Markdown reports should remain useful and honest.

## Validation expectations for first provider

Before a future provider implementation ships, its feature should prove:

- default CLI output still works without the provider;
- provider output is deterministic for the same repo/ref/config/tool version;
- provider failures produce caveats rather than hiding file evidence;
- output remains local-only and privacy-safe;
- stale or partial provider evidence is disclosed;
- the existing `zig build validate` gate still passes;
- real-repository smoke evidence uses privacy-safe labels only.

## Future tree-sitter spike boundary

The next tree-sitter feature should be a spike, not a general provider
framework. A safe first slice would:

- support one language, preferably Zig;
- parse current working-tree files only;
- attach current symbol spans to existing file hotspot results;
- expose confidence and caveats;
- avoid historical symbol tracking;
- avoid provider registry or plugin loading;
- avoid changing file-level scoring.
