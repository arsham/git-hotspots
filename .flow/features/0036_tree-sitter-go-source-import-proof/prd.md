# PRD: Tree-sitter Go source import proof

## Summary

Import a pinned, narrow `tree-sitter-go` source set into the repository as a
source-import and provenance proof only. The feature resolves the admission
blockers from Feature 0035 that can be proven at source-import time: immutable
revision, checksum or checkout identity, license and notice handling, generated
parser provenance, bill of materials, Tree-sitter core compatibility, source-size
impact, offline validation, and no-provider output stability.

This feature must not add Go parser build integration, Go runtime provider
behaviour, provider registry entries, CLI flags, report schema fields, scoring
changes, cache changes, query fixtures, symbol extraction, CI changes, release
work, package publishing, network access, telemetry, upload, remote enrichment,
or background provider execution.

## Problem

Feature 0035 recorded `tree-sitter-go` as a plausible first non-Zig grammar but
left it in `conditionalgo` state. The remaining blockers include exact immutable
source identity, license and notice verification, generated parser provenance,
BOM selection, source-size evidence, core compatibility, offline validation, and
no-provider output stability. Go runtime support should not proceed until the
source import itself is reviewable and local-first.

## Outcome

A pinned `tree-sitter-go` source set is vendored under
`third_party/tree-sitter-go/<revision>/` with provenance, imported-file manifest,
license/notice handling, and source-import evidence. The repository still has no
Go runtime support after this feature; it only has reviewed local source inputs
for a later Go build/extraction proof.

## Requirements

### R1 Source import scope

- Select an immutable `tree-sitter-go` revision: tag plus full commit, or full
  commit when no suitable tag exists.
- Import a narrow source set under
  `third_party/tree-sitter-go/<revision>/`.
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
- imported feature id;
- import date.

If an archive checksum is not used because a pinned checkout is the source basis,
record that reason explicitly and include enough per-file identity for review.

### R3 License and notice

The import must:

- verify the upstream license at the selected revision;
- copy upstream license text unchanged into the vendored component path;
- preserve required copyright and notice text;
- update `THIRD_PARTY_NOTICES.md` with public upstream attribution;
- stop as blocked for missing, ambiguous, changed, or incompatible license or
  notice terms.

### R4 Generated parser and scanner provenance

The import must identify generated files, expected to include `src/parser.c` and
any scanner files if present. It must do one of:

1. reproduce generated files from pinned grammar inputs and an exact Tree-sitter
   generator using local inputs only; or
2. verify generated files against pinned upstream artefacts with hashes, Git blob
   ids, or equivalent immutable evidence, and record why accepting the upstream
   generated artefact is deterministic and reviewable.

The feature must not add a global Tree-sitter CLI dependency, package-manager
fetch, build-time generation dependency, or network generation step.

The feature must not close with unresolved generated parser or scanner
provenance.

### R5 Narrow bill of materials

The import should include only files needed for future local parser build and
symbol-query review:

- upstream license and notice files;
- grammar metadata such as `tree-sitter.json` when present;
- grammar source files needed to review parser generation;
- generated C parser files and required scanner files;
- required parser headers or binding metadata when needed by the generated C
  sources;
- node type metadata required for query design;
- provenance and imported-file manifest files.

The import must exclude package-manager lockfiles and install metadata, CI and
release files, prebuilt binaries, wasm artefacts, playgrounds, examples,
benchmarks, editor integrations, language bindings, runtime registry wiring,
custom user queries, and provider implementation unless a file is explicitly
justified in the BOM.

### R6 Tree-sitter core compatibility

The import must prove that the selected Go grammar language version is compatible
with the existing vendored Tree-sitter core ABI and language-version range from
`third_party/tree-sitter-core/v0.26.9`.

If the selected Go grammar requires a newer Tree-sitter core, this feature must
stop or record a blocker. A Tree-sitter core update is out of scope.

### R7 Local-first and offline boundary

The import must prove that validation uses only repository-local inputs. It must
not introduce:

- build-time network fetches;
- Git submodules;
- package-manager resolution;
- system Tree-sitter packages;
- global parser packages or CLI dependencies;
- remote parser services;
- telemetry;
- upload;
- remote enrichment;
- background provider execution.

Any source acquisition done during execution must be a runner-time import action
only; committed build/runtime paths must remain offline and local.

### R8 Source-size and build-impact evidence

The import evidence must record:

- bytes added under `third_party/tree-sitter-go/<revision>/`;
- largest ten imported files by byte size;
- parser and scanner sizes;
- repository working-tree size before and after import, excluding `.git`,
  `.zig-cache`, and `zig-out`;
- `zig build validate` before and after import;
- before/after validation timing summaries where practical;
- planner-review note if size or timing materially changes source-install
  experience.

### R9 No-provider output stability

The feature must prove that existing no-provider outputs remain stable. Required
coverage includes representative table, JSON, Markdown, and inspect outputs.

Go provider output is out of scope and must not be produced by this feature.

### R10 Future sequencing

The evidence document must state that Go runtime support is still not
implemented. It must identify the next likely follow-up as Go offline
build/extraction proof or record blockers if import gates failed.

It must explicitly defer:

- Go parser compile/link proof;
- Go extraction proof;
- Go symbol query fixtures;
- inspect-only Go symbol output;
- provider registry changes;
- CLI/report/schema/scoring/cache changes;
- LSP;
- custom user query execution.

## Acceptance criteria

- `third_party/tree-sitter-go/<revision>/` exists with a narrow imported source
  set.
- The vendored Go component includes unchanged upstream license/notice text.
- The vendored Go component includes `PROVENANCE.md` and `IMPORTED_FILES.tsv`.
- `THIRD_PARTY_NOTICES.md` is updated with public, repo-relative Go attribution.
- A source-import evidence document records immutable source identity,
  generated parser/scanner provenance, Tree-sitter core compatibility,
  source-size measurements, offline validation, and no-provider output
  stability.
- No Go build, runtime provider, provider registry, CLI, report schema, scoring,
  cache, test fixture, CI, release, or package behaviour is added.
- The feature stops as blocked rather than closing if immutable revision,
  license/notice, generated parser provenance, core compatibility, or
  no-provider stability cannot be proven.

## Edge cases

- If no suitable tag exists, pin a full commit and explain why no tag was used.
- If the selected source archive checksum cannot be recorded, use a pinned
  checkout basis and record per-file manifest evidence instead of guessing.
- If generated parser or scanner files cannot be reproduced or verified, stop as
  blocked.
- If the Go grammar uses an external scanner, include it only if it is required
  by the generated parser and provenance/license gates are satisfied.
- If the Go grammar requires a newer Tree-sitter core than the current vendored
  core, stop for a separate core-update feature.
- If the BOM cannot remain narrow, stop for planner review.
- If no-provider outputs change, treat it as a blocker unless a separate shaped
  feature explicitly changes those outputs.

## Verification

Close-out must run:

```sh
git diff --check
zig build validate
zig build tree-sitter-build-proof
zig build tree-sitter-symbol-proof
zig build validate -Dcloseout=true -Dsmoke-repo <local-sibling-path> -Dsmoke-label sibling-local-repo
```

Close-out must also prove source-import-specific checks:

- changed paths are limited to `third_party/tree-sitter-go/<revision>/`,
  source-import provenance/evidence docs, `THIRD_PARTY_NOTICES.md`, and Flow
  state;
- no changes to `src/`, `tests/`, `fixtures/`, `build.zig`, `build.zig.zon`,
  `.github/`, `tools/validate.sh`, CLI/report/schema/scoring/cache/provider
  runtime/provider registry;
- `PROVENANCE.md`, `IMPORTED_FILES.tsv`, copied license/notice, immutable
  upstream identity, and generated parser/scanner provenance are present;
- Go parser language version is compatible with Tree-sitter core language range
  `13..15`;
- source-size and repository-size measurements are recorded;
- no-provider table, JSON, Markdown, and inspect outputs are byte-stable;
- no `.gitmodules`, build-time fetch, package-manager fetch, global parser CLI,
  telemetry, upload, remote enrichment, or background provider path is added;
- docs and evidence use only repo-relative paths and public upstream identifiers;
- docs and evidence contain no private paths, raw private reports, raw parser
  stderr, private remotes, author identities, commercial strategy, bug
  prediction, quality scoring, developer ranking, or maintainer judgement.
