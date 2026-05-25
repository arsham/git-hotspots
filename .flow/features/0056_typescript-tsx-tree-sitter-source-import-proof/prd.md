# PRD: TypeScript/TSX Tree-sitter source import proof

## Summary

Import a pinned, narrow `tree-sitter-typescript` source set into the repository
as a source-import and provenance proof only. The feature resolves the admission
blockers from Feature 0049 that can be proven at source-import time: immutable
revision, checkout or archive identity, license and notice handling, generated
parser and scanner provenance for TypeScript and TSX, bill of materials,
Tree-sitter core compatibility, source-size impact, offline validation,
extension admission evidence, and no-provider output stability.

This feature must not add TypeScript or TSX parser build integration, runtime
provider behaviour, provider registry entries, CLI flags, report schema fields,
scoring changes, cache changes, query fixtures, symbol extraction, CI changes,
release work, package publishing, network access, telemetry, upload, remote
enrichment, Node provider identity, package/workspace/module analysis, tsconfig
analysis, LSP, custom user queries, or background provider execution.

## Problem

Feature 0049 recorded `tree-sitter-typescript` as a plausible future grammar but
left implementation blocked on exact immutable source identity, license and
notice verification, generated TypeScript and TSX parser/scanner provenance,
BOM selection, extension admission proof, source-size evidence, core
compatibility, offline validation, and no-provider output stability.
TypeScript/TSX runtime support should not proceed until the source import itself
is reviewable and local-first.

## Outcome

A pinned `tree-sitter-typescript` source set is vendored under
`third_party/tree-sitter-typescript/<revision>/` with provenance, imported-file
manifest, license/notice handling, TypeScript and TSX extension admission
evidence, and source-import evidence. The repository still has no TypeScript or
TSX runtime support after this feature; it only has reviewed local source inputs
for later build, query, and extraction proofs.

## Requirements

### R1 Source import scope

- Select an immutable `tree-sitter-typescript` revision: tag plus full commit,
  or full commit when no suitable tag exists.
- Import a narrow source set under
  `third_party/tree-sitter-typescript/<revision>/`.
- Include TypeScript and TSX grammar inputs only when provenance, license, and
  BOM gates are satisfied for both.
- Add or update only source-import artefacts, provenance/evidence docs,
  notices, and Flow state.
- Do not change `src/`, `tests/`, `fixtures/`, `build.zig`, `build.zig.zon`,
  `.github/`, `tools/validate.sh`, CLI flags, report schemas, scoring, cache,
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

The import must identify generated parser and scanner files for both TypeScript
and TSX grammar inputs when present. Expected paths may include generated parser
files, scanner files, grammar metadata, node type metadata, and required parser
headers under the selected upstream layout.

For each imported generated parser or scanner artefact, the feature must do one
of:

1. reproduce generated files from pinned grammar inputs and an exact
   Tree-sitter generator using local inputs only; or
2. verify generated files against pinned upstream artefacts with hashes, Git
   blob ids, or equivalent immutable evidence, and record why accepting the
   upstream generated artefact is deterministic and reviewable.

The import must explicitly prove scanner presence or absence separately for the
selected TypeScript and TSX grammars. If a scanner is present, it must be
included in the BOM only when its license/provenance gates are satisfied.

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
custom user queries, Node wrappers, package/workspace metadata, tsconfig files,
LSP files, and provider implementation unless a file is explicitly justified in
the BOM.

### R6 Tree-sitter core compatibility

The import must prove that the selected TypeScript and TSX grammar language
versions are compatible with the existing vendored Tree-sitter core ABI and
language-version range from `third_party/tree-sitter-core/v0.26.9`.

If the selected grammar requires a newer Tree-sitter core, this feature must
stop or record a blocker. A Tree-sitter core update is out of scope.

### R7 Extension admission evidence

The import must inspect the selected revision and record whether `.ts`, `.mts`,
`.cts`, and `.tsx` can be supported by the selected grammar sources using
repository-local inputs.

If TSX support can be proven from the selected upstream source set, the
source-import evidence must record the proof basis and future fixture
expectation. If TSX cannot be proven locally for the selected revision, `.tsx`
must be explicitly deferred while `.ts`, `.mts`, and `.cts` remain eligible for
later TypeScript features.

The feature must not claim runtime support for any TypeScript or TSX extension.
Extension admission is a source-import planning fact only.

### R8 Local-first and offline boundary

The import must prove that validation uses only repository-local inputs. It
must not introduce:

- build-time network fetches;
- Git submodules;
- package-manager resolution;
- system Tree-sitter packages;
- global parser packages or CLI dependencies;
- remote parser services;
- telemetry;
- upload;
- remote enrichment;
- package/workspace/module analysis;
- tsconfig analysis; or
- background provider execution.

Any source acquisition done during execution must be a runner-time import action
only; committed build/runtime paths must remain offline and local.

### R9 Source-size and build-impact evidence

The import evidence must record:

- bytes added under `third_party/tree-sitter-typescript/<revision>/`;
- largest ten imported files by byte size;
- TypeScript parser and scanner sizes;
- TSX parser and scanner sizes, or explicit TSX deferral;
- repository working-tree size before and after import, excluding `.git`,
  `.zig-cache`, and `zig-out`;
- `zig build validate` before and after import;
- before/after validation timing summaries where practical; and
- planner-review note if size or timing materially changes source-install
  experience.

### R10 No-provider output stability

The feature must prove that existing no-provider outputs remain stable. Required
coverage includes representative table, JSON, Markdown, and inspect outputs.

TypeScript and TSX provider output is out of scope and must not be produced by
this feature.

### R11 Public evidence and future sequencing

The evidence document must state that TypeScript and TSX runtime support is
still not implemented. Expected path:

```text
docs/tree-sitter-typescript-source-import-evidence.md
```

It must identify the next likely follow-up as TypeScript/TSX offline build
proof, or record blockers if import gates failed.

It must explicitly defer:

- TypeScript/TSX parser compile/link proof;
- TypeScript/TSX extraction proof;
- TypeScript/TSX symbol query fixtures;
- inspect-only TypeScript/TSX symbol output;
- provider registry changes;
- CLI/report/schema/scoring/cache changes;
- LSP;
- custom user query execution;
- `package.json`, workspace, bundler, dependency graph, module resolution,
  tsconfig analysis, Node provider identity, and repo-wide scanning behaviour;
- true symbol history, authorship, ownership, ranking, risk scoring, telemetry,
  network, upload, and remote enrichment.

## Acceptance criteria

- `third_party/tree-sitter-typescript/<revision>/` exists with a narrow imported
  source set.
- The vendored TypeScript component includes unchanged upstream license/notice
  text.
- The vendored TypeScript component includes `PROVENANCE.md` and
  `IMPORTED_FILES.tsv`.
- `THIRD_PARTY_NOTICES.md` is updated with public, repo-relative TypeScript
  attribution.
- A source-import evidence document records immutable source identity,
  generated TypeScript and TSX parser/scanner provenance, Tree-sitter core
  compatibility, extension admission state, source-size measurements, offline
  validation, and no-provider output stability.
- No TypeScript/TSX build, runtime provider, provider registry, CLI, report
  schema, scoring, cache, test fixture, CI, release, package, Node,
  package/workspace/module, tsconfig, LSP, network, telemetry, or remote
  enrichment behaviour is added.
- The feature stops as blocked rather than closing if immutable revision,
  license/notice, generated parser/scanner provenance, core compatibility, BOM
  narrowness, extension decision, or no-provider stability cannot be proven.

## Edge cases

- If no suitable tag exists, pin a full commit and explain why no tag was used.
- If the selected source archive checksum cannot be recorded, use a pinned
  checkout basis and record per-file manifest evidence instead of guessing.
- If generated parser or scanner files cannot be reproduced or verified, stop as
  blocked.
- If TypeScript and TSX live in separate upstream subdirectories, import only
  the narrow files needed for each admitted grammar and record that layout in
  the BOM.
- If TSX cannot be proven locally for the selected revision, defer `.tsx`
  rather than blocking `.ts`, `.mts`, and `.cts` source import.
- If the grammar requires a newer Tree-sitter core than the current vendored
  core, stop for a separate core-update feature.
- If the BOM requires package manager, binding, Node, workspace, tsconfig, LSP,
  or module-analysis files to function, stop and reshape.

## Verification

Close-out must include evidence for:

```sh
git diff --check
zig build validate
changed-path scan for source-import-only scope
provenance/license/BOM scan
generated TypeScript parser/scanner provenance check
generated TSX parser/scanner provenance check or TSX deferral proof
Tree-sitter core compatibility check
extension admission or deferral check
no-provider output stability check
```

Close-out evidence must also include privacy-safe real-repository validation:
this repository and one suitable local sibling repository when available, using
repo-relative paths or privacy-safe labels only. No committed evidence may
include absolute local paths, private raw report dumps, emails, telemetry, or
remote enrichment.
