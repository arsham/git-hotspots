# Lua offline build proof

## Problem

Feature 0065 is expected to import pinned Lua Tree-sitter sources with
provenance, but the repository still needs proof that the selected parser and
scanner sources compile and link offline against the existing vendored
Tree-sitter core. Runtime provider behaviour must remain deferred until the
build boundary is proven.

## Outcome

The build graph can compile and link the vendored Lua parser and scanner
sources offline in a local proof target, with deterministic evidence and no Lua
runtime provider, inspect output, default report, scoring, cache, LuaRocks,
package-path, module-resolution, LSP, network, telemetry, upload, or
remote-enrichment behaviour.

## Requirements

### R1 Build proof scope

1. Add a narrow build proof for the vendored Lua parser and scanner sources
   imported by Feature 0065.
2. Use the existing vendored Tree-sitter core compatibility boundary; do not
   update Tree-sitter core in this feature.
3. Keep the proof offline and repository-local.
4. Do not add Lua runtime provider registration, CLI behaviour, report schema
   fields, default output changes, scoring changes, cache changes, query
   fixtures, symbol extraction behaviour, LuaRocks/package/module analysis,
   LSP, CI, release, network, telemetry, upload, or remote enrichment.

### R2 Build-system shape

1. Prefer a proof target that mirrors the JavaScript and TypeScript build-proof
   precedents while keeping Lua independently identifiable.
2. The proof must compile parser and scanner objects for Lua using
   repository-local vendored C sources.
3. The proof must link far enough to catch ABI, missing symbol, scanner wrapper,
   include path, and C/C++ compilation incompatibilities.
4. The proof must remain deterministic across repeated local runs.
5. The proof must not require Lua, LuaRocks, package managers, generated grammar
   regeneration, global Tree-sitter CLI, or network access.

### R3 Evidence

1. Add or update a public evidence document for the Lua build proof.
2. Evidence must identify the exact vendored source revision and source paths
   used.
3. Evidence must record Lua parser/scanner compile/link commands or validation
   targets.
4. Evidence must record before/after validation results, including
   `git diff --check`, `zig build validate`, `zig build test`, and `zig build`
   where applicable.
5. Evidence must record no-provider output stability for existing language
   providers where applicable.
6. Evidence must include privacy-safe real-repository validation for this
   repository and one suitable local sibling repository when available, using
   labels such as `this-repo` and `sibling-local-repo` only.

## Acceptance criteria

1. The repository has a deterministic offline build proof for the selected Lua
   parser and scanner sources.
2. The proof uses only vendored, repository-local inputs and does not require
   Lua, LuaRocks, package managers, grammar regeneration, network, telemetry,
   upload, or remote enrichment.
3. The proof does not expose Lua runtime provider behaviour or change default
   reports, inspect output, report schemas, scoring, cache, CLI, CI, release,
   package, LSP, package-path, module-resolution, or dependency behaviour.
4. Public evidence documents the build proof, source paths, validation ladder,
   no-provider stability, and privacy-safe smoke validation.
5. The feature stops as blocked rather than closing if the compile/link proof
   cannot be completed against the existing vendored Tree-sitter core.

## Edge cases

1. If Feature 0065 has not recorded an exact vendored Lua source path, stop and
   return to dispatch after that dependency closes.
2. If Lua scanner compilation needs a wrapper or C++ treatment, document the
   difference and keep the proof explicit.
3. If the grammar requires a newer Tree-sitter core, stop for a separate
   core-update feature.
4. If the build proof needs generated files not imported by Feature 0065, stop
   and reshape instead of silently expanding the BOM.
5. If local sibling smoke has no safe Lua file, record a bounded privacy-safe
   no-safe-file finding instead of committing private paths or raw report dumps.
6. If build validation passes only through cached artefacts, clean or otherwise
   prove the build is not cache-dependent.

## Verification

Close-out must include evidence for:

```sh
git diff --check
zig build validate
zig build test
zig build
Lua parser/scanner compile/link proof
changed-path scan for build-proof-only scope
no-provider output stability check
privacy-safe this-repo smoke
privacy-safe sibling-local-repo smoke or bounded no-safe-file finding
```
