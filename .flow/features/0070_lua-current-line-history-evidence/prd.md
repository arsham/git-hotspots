# Lua current-line history evidence

## Problem

Inspect-only Lua symbols can show current syntax, but users also need the same
current-line Git evidence available for other inspect-only providers. This must
remain current-line evidence, not true symbol history, ownership, blame,
dependency, module, or risk scoring.

## Outcome

Inspect-only Lua symbol output can attach deterministic current-line Git
evidence for supported symbols. The output remains local-first, privacy-safe,
current-only, caveated, and consistent with existing provider line-history
semantics.

## Requirements

### R1 Evidence scope

- Attach current-line Git evidence to Lua symbols using the existing
  line-history mechanism.
- Preserve current-only semantics; do not claim true symbol history, ownership,
  authorship judgement, maintainer judgement, bug prediction, code-quality
  scoring, dependency meaning, module meaning, or type meaning.
- Preserve deterministic caveats for missing Git history, shallow history,
  untracked files, unsupported paths, parse failures, empty files, generated
  Lua, dynamic patterns, metatables, and ambiguous module-table patterns.
- Do not change default file-level reports, scoring, cache, provider registry
  architecture, package/module/dependency analysis, LuaRocks, LSP, network,
  telemetry, upload, or remote enrichment.

### R2 Output stability

JSON, Markdown, and table inspect outputs must show Lua line-history evidence
using the same fields and caveat style as existing inspect-only providers.
Existing Zig, Go, Python, JavaScript, TypeScript, TSX, and no-provider outputs
must remain byte-stable unless this feature explicitly updates shared wording in
a compatible way.

### R3 Evidence and wording

Public wording must call the result current-line Git evidence. It must not call
it true symbol history, blame, ownership, author ranking, code-quality scoring,
risk prediction, module understanding, package understanding, or dependency
analysis.

## Acceptance criteria

- Lua inspect-only symbols can include current-line Git evidence.
- Supported, unsupported, empty, invalid, generated, dynamic, metatable-heavy,
  shallow-history, untracked, and no-history cases are deterministic and
  caveated.
- JSON, Markdown, and table outputs match existing line-history conventions.
- Existing provider and no-provider outputs remain stable.
- Public wording avoids true-history, ownership, scoring, prediction,
  maintainer-judgement, module, package, type, and dependency claims.

## Edge cases

- If line-history evidence is unavailable, output a scoped/incomplete caveat
  rather than fetching or guessing.
- If Git history is shallow or partial, report the scope rather than contacting
  remotes.
- If a symbol range is ambiguous, attach evidence only when the current-line
  mapping is deterministic.
- If real-repository smoke has no safe Lua file, record a bounded privacy-safe
  no-safe-file finding.

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
inspect JSON, Markdown, and table line-history golden checks
existing provider output byte-stability checks
no-provider output stability checks
prohibited-claim and privacy scans
privacy-safe this-repo smoke
privacy-safe sibling-local-repo smoke or bounded no-safe-file finding
```
