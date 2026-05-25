# TypeScript/TSX offline build proof

## Problem

Feature 0056 imported pinned TypeScript and TSX Tree-sitter sources with provenance, but the repository still has no proof that those vendored parser and scanner sources compile and link offline against the existing vendored Tree-sitter core. Runtime provider behaviour must remain deferred until the build boundary is proven.

## Outcome

The build graph can compile and link TypeScript and TSX parser/scanner sources offline in a local proof target, with deterministic evidence and no TypeScript/TSX runtime provider, inspect output, default report, scoring, cache, Node/package, tsconfig, LSP, network, telemetry, or remote-enrichment behaviour.

## Requirements

### R1 Build proof scope

1. Add a narrow build proof for the vendored TypeScript parser/scanner sources from `third_party/tree-sitter-typescript/v0.23.2/typescript/`.
2. Add a narrow build proof for the vendored TSX parser/scanner sources from `third_party/tree-sitter-typescript/v0.23.2/tsx/`.
3. Use the existing vendored Tree-sitter core compatibility boundary; do not update Tree-sitter core in this feature.
4. Keep the proof offline and repository-local.
5. Do not add TypeScript or TSX runtime provider registration, CLI behaviour, report schema fields, default output changes, scoring changes, cache changes, query fixtures, symbol extraction behaviour, Node/package/workspace/module/tsconfig analysis, LSP, CI, release, network, telemetry, upload, or remote enrichment.

### R2 Build-system shape

1. Prefer a proof target that mirrors the JavaScript build-proof precedent while keeping TypeScript and TSX independently identifiable.
2. The proof must compile parser and scanner objects for TypeScript and TSX using repository-local vendored C sources.
3. The proof must link far enough to catch ABI, missing symbol, scanner wrapper, include path, and C/C++ compilation incompatibilities.
4. The proof must remain deterministic across repeated local runs.
5. The proof must not require Node, npm, package managers, generated grammar regeneration, or network access.

### R3 Evidence

1. Add or update a public evidence document for the TypeScript/TSX build proof.
2. Evidence must identify the exact vendored source revision and source paths used.
3. Evidence must record TypeScript and TSX parser/scanner compile/link commands or validation targets.
4. Evidence must record before/after validation results, including `git diff --check`, `zig build validate`, `zig build test`, and `zig build` where applicable.
5. Evidence must record no-provider output stability for existing Zig, Go, Python, and JavaScript reports where applicable.
6. Evidence must include privacy-safe real-repository validation for this repository and one suitable local sibling repository when available, using labels such as `this-repo` and `sibling-local-repo` only.

## Acceptance criteria

1. The repository has a deterministic offline build proof for TypeScript parser/scanner sources.
2. The repository has a deterministic offline build proof for TSX parser/scanner sources.
3. The proof uses only vendored, repository-local inputs and does not require Node, npm, package managers, grammar regeneration, network, telemetry, upload, or remote enrichment.
4. The proof does not expose TypeScript/TSX runtime provider behaviour or change default reports, inspect output, report schemas, scoring, cache, CLI, CI, release, package, LSP, Node/package/workspace/module, or tsconfig behaviour.
5. Public evidence documents the build proof, source paths, validation ladder, no-provider stability, and privacy-safe smoke validation.
6. The feature stops as blocked rather than closing if either TypeScript or TSX compile/link proof cannot be completed against the existing vendored Tree-sitter core.

## Edge cases

1. If TypeScript and TSX need different scanner compilation flags or wrapper treatment, document the difference and keep both proofs explicit.
2. If either grammar requires a newer Tree-sitter core, stop for a separate core-update feature.
3. If the build proof needs generated files not imported by Feature 0056, stop and reshape instead of silently expanding the BOM.
4. If local sibling smoke has no safe TypeScript or TSX file, record a bounded privacy-safe no-safe-file finding instead of committing private paths or raw report dumps.
5. If build validation passes only through cached artefacts, clean or otherwise prove the build is not cache-dependent.

## Verification

Close-out must include evidence for:

```sh
git diff --check
zig build validate
zig build test
zig build
TypeScript parser/scanner compile/link proof
TSX parser/scanner compile/link proof
changed-path scan for build-proof-only scope
no-provider output stability check
privacy-safe this-repo smoke
privacy-safe sibling-local-repo smoke or bounded no-safe-file finding
```
