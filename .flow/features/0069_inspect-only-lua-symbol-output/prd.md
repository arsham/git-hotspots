# Inspect-only Lua symbol output

## Problem

Lua source, build, query, and extraction proofs can exist without exposing Lua
symbols to users. The next runtime step must be narrow: inspect-only Lua symbol
output for requested `.lua` paths, preserving default file-level reports and all
existing provider behaviour.

## Outcome

When a user explicitly requests inspect symbols for a `.lua` path, the CLI can
return current Lua symbol evidence with caveats and provider metadata. Default
reports remain file-level, no-provider outputs remain stable, and Lua support is
framed as optional inspect-only provider evidence.

## Requirements

### R1 Runtime scope

- Wire Lua into inspect-only symbol output for requested paths ending in `.lua`.
- Preserve default table, JSON, Markdown, and non-symbol inspect output.
- Preserve existing Zig, Go, Python, JavaScript, TypeScript, and TSX symbol
  output byte stability.
- Add no CLI flag unless an existing inspect-symbol path already covers the
  behaviour.
- Do not add report schema changes beyond existing symbol-provider fields,
  scoring changes, cache changes, package/module/dependency analysis, LuaRocks,
  LSP, runtime execution, network, telemetry, upload, remote enrichment, or
  background provider behaviour.

### R2 User-visible semantics

Lua symbol output must be:

- current working-tree evidence only;
- optional and inspect-oriented;
- additive to file-level Git evidence;
- deterministic for the same repository, ref, path, config, and provider
  version;
- caveated when parsing is unavailable, unsupported, partial, failed, timed
  out, empty, ambiguous, generated, or skipped; and
- sanitized so diagnostics do not expose absolute paths, private repository
  details, source snippets, remotes, authors, raw parser stderr, or raw private
  reports.

### R3 Path behaviour

Only explicitly requested `.lua` paths are Lua candidates. The feature must not
infer Lua support from `require`, package paths, rockspecs, module names,
LuaRocks metadata, monorepo layout, dependency graphs, LSP, runtime execution,
or repo-wide scanning.

### R4 Output formats

JSON, Markdown, and table inspect outputs must show Lua symbols consistently
with existing symbol providers. Markdown-sensitive names and paths must be
escaped. Empty, invalid, unsupported, or skipped cases must produce stable
caveats rather than product-truth claims.

### R5 Documentation and evidence

Update public docs or help only as needed to describe inspect-only Lua support
and its caveats. Do not claim Lua code quality, bug prediction, ownership,
maintainer judgement, module understanding, type understanding, or dependency
understanding.

## Acceptance criteria

- Explicit inspect-symbol requests for `.lua` paths produce deterministic Lua
  symbol evidence in supported output formats.
- Default file-level reports and no-provider outputs remain unchanged.
- Existing language symbol outputs remain byte-stable.
- Unsupported, invalid, empty, generated, dynamic, metatable-heavy, and
  ambiguous cases are caveated or skipped deterministically.
- Public wording describes Lua support as inspect-only current syntax evidence,
  not runtime/module/package/type/dependency understanding.

## Edge cases

- If `.lua` files contain generated or embedded DSL content, caveat or skip
  deterministically.
- If names require runtime or module interpretation, omit or caveat them.
- If Markdown or table output would expose unsafe text, escape or sanitize it.
- If output requires schema expansion, stop for planning.
- If a local sibling repository has no safe Lua file, record a bounded
  privacy-safe no-safe-file finding.

## Verification

Close-out must include evidence for:

```sh
git diff --check
zig build validate
zig build test
zig build
zig build tree-sitter-lua-build-proof
zig build tree-sitter-lua-query-proof
zig build tree-sitter-lua-symbol-proof
inspect JSON, Markdown, and table golden checks
existing provider output byte-stability checks
no-provider output stability checks
prohibited-claim and privacy scans
privacy-safe this-repo smoke
privacy-safe sibling-local-repo smoke or bounded no-safe-file finding
```
