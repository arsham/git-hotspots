# Lua symbol extraction proof

## Problem

A Lua query contract proves captures and fixtures, but runtime inspect output
still needs an internal extraction proof that maps captures into the repository
symbol evidence model deterministically. That proof must happen before user
visible Lua symbols are exposed.

## Outcome

Lua query captures can be converted into internal symbol evidence in proof
targets with deterministic names, kinds, ranges, ordering, caveats, provider
metadata, and failure states. Lua runtime inspect output remains absent after
this feature.

## Requirements

### R1 Extraction scope

- Add internal Lua extraction proof code or proof fixtures that map approved Lua
  query captures into the existing symbol evidence model.
- Preserve current-only evidence semantics; do not claim true symbol history,
  ownership, runtime meaning, package/module resolution, or dependency
  inference.
- Preserve caveats for parse failures, unsupported paths, empty files, invalid
  files, dynamic table assignment, metatables, generated Lua, embedded DSLs,
  and ambiguous module-table patterns.
- Do not expose Lua symbols in user-facing CLI output yet.
- Do not add provider registry entries, default output changes, report schema
  changes, scoring, cache, LuaRocks/package/module analysis, LSP, network,
  telemetry, upload, or remote enrichment.

### R2 Mapping semantics

The proof must define and validate:

- stable symbol names for supported function and table patterns;
- symbol kinds using the existing public kind vocabulary unless a separate
  feature expands it;
- source ranges and display ranges;
- deterministic ordering for symbols with equal or nested ranges;
- provider identity, grammar revision, query revision, and confidence/caveat
  metadata;
- duplicate handling; and
- graceful failure or skip states.

### R3 Evidence document

Add or update a concise public evidence document for Lua extraction proof. It
must record supported mappings, skipped mappings, caveats, proof target names,
validation commands, and explicit statement that Lua runtime `--symbols` output
is still not implemented.

### R4 Existing behaviour preservation

Existing Zig, Go, Python, JavaScript, TypeScript, TSX, and no-provider inspect
outputs must remain byte-stable. Existing proof targets must continue to pass.

## Acceptance criteria

- Lua query captures map to internal symbol evidence deterministically in proof
  targets.
- Supported and skipped Lua constructs are explicit and covered by fixtures.
- Ranges, ordering, kinds, provider metadata, caveats, parse failures,
  unsupported paths, empty files, and invalid files are proven.
- No user-facing Lua runtime symbol output or default report behaviour is added.
- Existing provider and no-provider outputs remain stable.

## Edge cases

- If a symbol cannot be named without runtime or module interpretation, caveat
  or omit it.
- If a construct would require new public symbol kinds, stop for planning.
- If extraction requires parser files not admitted by prior features, stop and
  reshape.
- If fixture evidence is synthetic-only where the contract requires real output,
  add bounded real-repository evidence or stop.
- If dynamic Lua patterns look meaningful but are ambiguous, prefer visible
  caveats or deterministic skips over overclaiming.

## Verification

Close-out must include evidence for:

```sh
git diff --check
zig build validate
zig build tree-sitter-lua-build-proof
zig build tree-sitter-lua-query-proof
zig build tree-sitter-lua-symbol-proof
fixture and degraded-case proof
changed-path scan for extraction-proof-only scope
no-runtime-output scan
existing provider output stability check
privacy-safe this-repo smoke
privacy-safe sibling-local-repo smoke or bounded no-safe-file finding
```
