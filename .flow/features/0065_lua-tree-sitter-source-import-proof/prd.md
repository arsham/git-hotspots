# Lua Tree-sitter source import proof

## Summary

Import a pinned, narrow `tree-sitter-lua` source set into the repository as a
source-import and provenance proof only. The feature resolves the admission
blockers from Feature 0064 that can be proven at source-import time: immutable
revision, checkout or archive identity, license and notice handling, generated
parser and scanner provenance, bill of materials, Tree-sitter core
compatibility, source-size impact, offline validation, `.lua` admission
evidence, and no-provider output stability.

This feature must not add Lua parser build integration, runtime provider
behaviour, provider registry entries, CLI flags, report schema fields, scoring
changes, cache changes, query fixtures, symbol extraction, CI changes, release
work, package publishing, network access at build or runtime, telemetry, upload,
remote enrichment, LuaRocks or package-path analysis, module resolution, LSP,
custom user queries, or background provider execution.

## Problem

Feature 0064 recorded `tree-sitter-lua` as a plausible future grammar but left
implementation blocked on exact immutable source identity, license and notice
verification, generated parser and scanner provenance, BOM selection, `.lua`
extension admission proof, source-size evidence, core compatibility, offline
validation, and no-provider output stability. Lua runtime support should not
proceed until the source import itself is reviewable and local-first.

## Outcome

A pinned `tree-sitter-lua` source set is vendored under
`third_party/tree-sitter-lua/<revision>/` with provenance, imported-file
manifest, license and notice handling, `.lua` extension admission evidence, and
source-import evidence. The repository still has no Lua runtime support after
this feature; it only has reviewed local source inputs for later build, query,
and extraction proofs.

## Requirements

### R1 Source import scope

- Select an immutable `tree-sitter-lua` revision: tag plus full commit, or full
  commit when no suitable tag exists.
- Import a narrow source set under `third_party/tree-sitter-lua/<revision>/`.
- Add or update only source-import artefacts, provenance and evidence docs,
  notices, and Flow state.
- Do not change `src/`, `tests/`, fixtures, `build.zig`, `build.zig.zon`,
  `.github/`, validation scripts, CLI flags, report schemas, scoring, cache,
  provider runtime, provider registry, CI, release, or package behaviour.

### R2 Exact source identity

The import must record:

- upstream URL;
- selected immutable tag and full commit, or selected full commit with reason;
- canonical source basis, such as pinned checkout or named archive;
- SHA-256 checksum for any archive used;
- per-file imported manifest;
- vendored path;
- imported feature id; and
- import date.

If an archive checksum is not used because a pinned checkout is the source
basis, record that reason explicitly and include enough per-file identity for
review.

### R3 License and notice

The import must:

- verify the upstream license at the selected revision;
- copy upstream license text unchanged into the vendored component path;
- preserve required copyright and notice text;
- update `THIRD_PARTY_NOTICES.md` with public upstream attribution; and
- stop as blocked for missing, ambiguous, changed, or incompatible license or
  notice terms.

### R4 Generated parser and scanner provenance

The import must identify generated parser and scanner files for the selected
Lua grammar. Expected paths may include generated parser files, scanner files,
grammar metadata, node type metadata, and required parser headers under the
selected upstream layout.

For each imported generated parser or scanner artefact, the feature must do one
of:

1. reproduce generated files from pinned grammar inputs and an exact Tree-sitter
   generator using local inputs only; or
2. verify generated files against pinned upstream artefacts with hashes, Git
   blob ids, or equivalent immutable evidence, and record why accepting the
   upstream generated artefact is deterministic and reviewable.

The import must explicitly prove scanner presence or absence for the selected
Lua grammar. If a scanner is present, it must be included in the BOM only when
its license and provenance gates are satisfied.

The feature must not add a global Tree-sitter CLI dependency, package-manager
fetch, build-time generation dependency, or network generation step. The feature
must not close with unresolved generated parser or scanner provenance.

### R5 Narrow bill of materials

The import should include only files needed for future local parser build and
symbol-query review:

- upstream license and notice files;
- grammar metadata such as `tree-sitter.json` when present;
- grammar source files needed to review parser generation;
- generated C parser files and required scanner files;
- required parser headers or binding metadata when needed by generated C
  sources;
- helper headers required by a scanner when the selected revision requires
  them;
- node type metadata required for query design;
- provenance and imported-file manifest files.

The import must exclude package-manager lockfiles and install metadata, CI and
release files, prebuilt binaries, wasm artefacts, playgrounds, examples,
benchmarks, editor integrations, language bindings, runtime registry wiring,
custom user queries, LuaRocks metadata, rockspec files, package-path metadata,
module-resolution artefacts, and provider implementation unless a file is
explicitly justified in the BOM.

### R6 Tree-sitter core compatibility

The import must prove that the selected Lua grammar language version is
compatible with the existing vendored Tree-sitter core ABI and language-version
range from `third_party/tree-sitter-core/v0.26.9`.

If the selected grammar requires a newer Tree-sitter core, this feature must
stop or record a blocker. A Tree-sitter core update is out of scope.

### R7 Lua path admission evidence

The import must record that future Lua runtime work is limited to requested
inspect paths ending in `.lua`. It must not imply `require` resolution, module
resolution, LuaRocks package discovery, package-path analysis, dependency graph
inference, runtime execution, LSP integration, or repo-wide scanning.

### R8 Source-size and build-impact evidence

The import must record:

- bytes added under the vendored Lua grammar path;
- largest imported files and their byte sizes;
- repository working-tree size before and after import, excluding transient
  build and Git directories;
- validation before and after import; and
- no-provider output stability for table, JSON, Markdown, and inspect outputs.

### R9 Evidence document

Add a concise public evidence document, expected path:

```text
docs/tree-sitter-lua-source-import.md
```

It must record source identity, selected revision, vendored path, BOM, excluded
file classes, license and notice handling, parser and scanner provenance, core
compatibility, `.lua` extension admission, source-size evidence, validation
commands, local/offline boundary, and explicit statement that Lua runtime
support is not implemented yet.

### R10 Existing behaviour preservation

Existing proof targets and product validation must continue to pass. Existing
Zig, Go, Python, JavaScript, TypeScript, and TSX symbol outputs and no-provider
table, JSON, Markdown, and inspect outputs must remain byte-stable unless a
separate feature explicitly changes them.

## Acceptance criteria

- A narrow, pinned `tree-sitter-lua` source set exists under a revisioned
  vendored path.
- The import has deterministic provenance, BOM, license, notice, parser,
  scanner, core-compatibility, source-size, and `.lua` path evidence.
- Public evidence exists at `docs/tree-sitter-lua-source-import.md`.
- No Lua build proof, query fixtures, extraction, runtime provider, inspect
  output, default report change, schema change, scoring change, cache change,
  CI change, package/release change, or network/runtime behaviour is added.
- The feature stops as blocked rather than importing unreviewed, incompatible,
  or overbroad source.

## Edge cases

- If the upstream identity differs from Feature 0064, record the reason and do
  not import without refreshing admission evidence.
- If the source archive or checkout cannot be pinned immutably, stop as blocked.
- If scanner presence or absence is unclear, stop as blocked.
- If the grammar requires a newer Tree-sitter core, stop for a separate
  core-update feature.
- If source-size or validation impact is unexpectedly high, escalate before
  closing.
- If no safe local sibling repository has Lua files, record a bounded
  privacy-safe no-safe-file finding instead of committing private paths or raw
  report dumps.

## Verification

Close-out must include evidence for:

```sh
git diff --check
zig build validate
changed-path scan for source-import-only scope
vendored-path scan proving no runtime/build/query/extraction/provider changes
license and notice verification
BOM and excluded-file-class review
parser and scanner provenance proof
Tree-sitter core compatibility proof
source-size and largest-file measurements
no-provider output stability check
privacy-safe this-repo smoke
privacy-safe sibling-local-repo smoke or bounded no-safe-file finding
```
